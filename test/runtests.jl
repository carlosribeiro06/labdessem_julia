using Test

@testset "LabDessem.jl" begin
    include("support/TestHelpers.jl"); using .TestHelpers
    include("Domain/domain_tests.jl")
    include("Input/input_tests.jl")
    include("Model/model_tests.jl")
    include("Network/network_tests.jl")
    include("FPHA/fpha_tests.jl")
    include("Output/output_tests.jl")
end

include("Harness/harness_tests.jl")
