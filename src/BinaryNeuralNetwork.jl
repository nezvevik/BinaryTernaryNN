module BinaryNeuralNetwork

using Flux
using Flux: Params, create_bias, BatchNorm
using Flux: ChainRulesCore, NoTangent, Chain, params
using Flux.Data: DataLoader


include("regulizers/binary_regulizer.jl")
include("regulizers/ternary_regulizer.jl")

include("quantizers/ternary_quantizer.jl")
include("quantizers/binary_quantizer.jl")

include("layers/normal_layer.jl")
include("layers/binary_layer.jl")
include("layers/regularized_layer.jl")

end # module BinaryNeuralNetwork
