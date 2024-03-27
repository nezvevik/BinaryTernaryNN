using BinaryNeuralNetwork: RegularizedLayer, activation_regulizer, weight_regulizer
using BinaryNeuralNetwork: convert2binary_weights, convert2binary_activation, convert2binary
using Flux: Chain, AdaBelief, mse

using Statistics: mean


include("utils.jl")

# get data
train_data, test_data = createloader(batchsize=256)

# init model
# insert identity as weight regulizer
model = Chain(
    RegularizedLayer(28^2, 256, tanh, tanh),
    RegularizedLayer(256, 256, tanh, tanh),
    RegularizedLayer(256, 10, tanh, tanh)
)


# default accuracy ≈ 0.1
accuracy(train_data, model)
accuracy(test_data, model)

# check default binary model accuracy
binact_model = convert2binary_activation(model)
accuracy(train_data, binact_model)

binweight_model = convert2binary(model)
accuracy(train_data, binweight_model)



function objective(m, x, y, λ1::Float64, λ2::Float64)
    logitcrossentropy(m(x), y) + λ1 * weight_regulizer(m) + λ2 * activation_regulizer(m, x)
end


function train_reg(model, opt, train, loss; history = [],
    epochs::Int=30, λ1=0.0000001, λ2=0.0000001,
    lower_bound=0.85, upper_bound=0.92, factor=1.5)
    
    p = Progress(epochs, 1)
    ps = params(model)
    # println(model)
    bin_model = convert2binary(model)
    
    ar = activation_regulizer(model, train)

    
    increasing_status = "Neutral"
    
    
    if length(history) == 0
        history = (
            smooth_acc=[accuracy(train, model)],
            bin_acc=[accuracy(train, bin_model)],
            λ1=[λ1],
            λ2=[λ2],
            λreg=[ar*λ2],
            slope=[0.0],
            ub=[upper_bound],
            lb=[lower_bound],
            )
    end
        
    for _ in 1:epochs
        for (x, y) in train
            # new train
            # gs = gradient(() -> loss(model, x, y, λ2), ps)
            gs = gradient(() -> loss(model, x, y, λ1, λ2), ps)
            Flux.update!(opt, ps, gs)
        end
        
        acc = accuracy(train, model)
        
        
        increasing_status = "Monotone"
        if length(history.bin_acc) < 5
            # pass
        elseif acc > upper_bound
            λ1 *= factor
            λ2 *= factor
            increasing_status = "Increasing"
        elseif acc < lower_bound
            λ1 /= factor
            λ2 /= factor
            increasing_status = "Decreasing"
        end

        bin_acc = accuracy(train, binary_model)
        if length(history.bin_acc) < 2
            slope = 1
        else
            v1 = history.bin_acc[end - 1] + history.bin_acc[end]
            v2 = history.bin_acc[end] + bin_acc
            slope = (v2 - v1) / 2
        end
        
        push!(history.slope, slope)

        slope_avg = length(history.slope) >= 5 ? mean(history.slope[end-4:end]) : mean(history.slope)

        slope_status = "Increasing"
        if slope_avg < -0.02
            slope_status = "Decreasing"
            lower_bound = acc
        elseif abs(slope_avg) < 0.0002
            slope_status = "Monotone"
            upper_bound = acc
        end 

        
        # ar = activation_regulizer(model, train)
        binact_model = convert2binary_activation(model)
        
        push!(history.smooth_acc, acc)
        push!(history.bin_acc, bin_acc)
        push!(history.λ1, λ1)
        push!(history.λ2, λ2)
        push!(history.λreg, ar * λ2)
        push!(history.ub, upper_bound)
        push!(history.lb, lower_bound)

        # print progress
        showvalues = [
            (:acc_train, round(100 * history.smooth_acc[end]; digits=2)),
            (:acc_binary_activation, round(100 * history.bin_acc[end]; digits=2)),
            (:λ1, λ1),
            (:λ2, λ2),
            (:λreg, ar * λ2),
            (:increasing_status, increasing_status),
            (:slope, slope_avg),
            (:ub, upper_bound),
            (:lb, lower_bound),
            (:slope_status, slope_status)
        ]
        ProgressMeter.next!(p; showvalues)
    end
    return history, λ1, λ2
end

λ1 = 10^(-6)
λ2 = 10^(-6)
upper_bound = 0.92
lower_bound = 0.87
epochs = 20
factor = 2.0
history = []

λ2 *= 2
λ2 /= 2

history, λ1, λ2 = train_reg(model, AdaBelief(), train_data, objective, epochs=epochs, history=history, λ1=λ1, λ2=λ2, upper_bound=upper_bound, lower_bound=lower_bound, factor=factor)

f = show_fig(history)
f = show_slope(history)

save("70%-dlouhy trenink- jeste delsi.png", f)


using CairoMakie: Figure, lines, lines!, hidespines!, hidexdecorations!, Axis, save
function show_fig(history)
    f = Figure()
    ax1 = Axis(f[1, 1])
    ax2 = Axis(f[1, 1], yaxisposition = :right)
    hidespines!(ax2)
    hidexdecorations!(ax2)

    len = length(history.smooth_acc)

    lines!(ax1, history.smooth_acc, color = :blue)
    lines!(ax1, history.bin_acc, color = :blue)
    lines!(ax1, history.ub, color = :black)
    lines!(ax1, history.lb, color = :black)
    lines!(ax2, history.λreg, color = :aqua)

    f
end

function show_slope(history)
    f = Figure()
    ax1 = Axis(f[1, 1])
    ax2 = Axis(f[1, 1], yaxisposition = :right)
    hidespines!(ax2)
    hidexdecorations!(ax2)

    lines!(ax1, history.smooth_acc, color = :black)
    lines!(ax1, history.bin_acc, color = :black)
    lines!(ax2, history.slope, color = :black)

    f
end

