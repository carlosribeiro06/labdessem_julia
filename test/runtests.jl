using Test

@testset "LabDessem.jl" begin
    include("Core/core_tests.jl")
    include("IO/io_tests.jl")
end
