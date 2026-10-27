using Test

@testset "LabDessem.jl" begin
    include("Core/core_tests.jl")
    include("IO/io_tests.jl")
    include("Model/model_tests.jl")
end
