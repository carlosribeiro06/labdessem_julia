# Main module
module LabDessem

include("Core/Core.jl")
include("IO/IO.jl")
include("Model/Model.jl")
include("Simulation/Simulation.jl")
include("Network/Network.jl")
include("FPHA/FPHA.jl")

using .Core
using .IO
using .Model
using .Simulation
using .Network
using .FPHA

export Core, IO, Model, Simulation, Network, FPHA

end
