using Test

@testset "Harness" begin
    include("test_golden.jl")
    include("test_ledger.jl")
end
