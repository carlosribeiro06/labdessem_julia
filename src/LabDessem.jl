# Main module
module LabDessem

include("Domain/Domain.jl")
include("FPHA/FPHA.jl")
include("Network/Network.jl")
include("Input/Input.jl")
include("Model/Model.jl")
include("Simulation/Simulation.jl")
include("Output/Output.jl")

using .Domain
using .FPHA
using .Network
using .Input
using .Model
using .Simulation
using .Output

export Domain, FPHA, Network, Input, Model, Simulation, Output

end
