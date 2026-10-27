using Test
using LabDessem
using LabDessem.IO

@testset "Future Cost Reader" begin
    @testset "missing file returns empty" begin
        cuts = read_future_cost_cuts("/nonexistent/path.bin")
        @test isempty(cuts)
    end

    @testset "type inference" begin
        @test @inferred(read_future_cost_cuts("/nonexistent.bin")) isa Vector{LabDessem.Core.FutureCostCut}
    end

    # NOTE: Full FlatBuffers parsing test will be added when implemented
end
