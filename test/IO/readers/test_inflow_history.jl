using Test
using LabDessem
using LabDessem.IO

@testset "Inflow History Reader" begin
    @testset "missing file returns empty" begin
        rows = read_inflow_history("/nonexistent/path.parquet")
        @test isempty(rows)
    end

    @testset "type inference" begin
        @test @inferred(read_inflow_history("/nonexistent.parquet")) isa Vector{LabDessem.Core.InflowHistoryRow}
    end

    # NOTE: Parquet file integration test would require a test fixture
end
