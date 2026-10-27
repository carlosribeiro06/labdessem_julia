using Test
using LabDessem
using LabDessem.Core
using LabDessem.IO

const TEST_DATA_DIR = joinpath(@__DIR__, "fixtures")

@testset "Common Utilities" begin

    @testset "read_csv" begin
        @testset "valid file" begin
            mkpath(TEST_DATA_DIR)
            test_csv = joinpath(TEST_DATA_DIR, "test_semicolon.csv")
            open(test_csv, "w") do io
                write(io, "col1;col2;col3\n")
                write(io, "1;2.5;text\n")
                write(io, "2;-;value\n")
            end
            df = read_csv(test_csv)
            @test size(df) == (2, 3)
            @test df.col1 == [1, 2]
            @test df.col2[1] == 2.5
            @test ismissing(df.col2[2])
            @test df.col3 == ["text", "value"]
            rm(test_csv)
        end

        @testset "missing file" begin
            @test_throws ArgumentError read_csv("/nonexistent/path.csv")
            err = try read_csv("/nonexistent.csv") catch e e end
            @test occursin("not found", err.msg)
        end
    end

    @testset "flow_m3s_to_hm3" begin
        @test flow_m3s_to_hm3(100.0, 0.5) ≈ 0.18 atol=1e-10
        @test flow_m3s_to_hm3(1000.0, 1.0) ≈ 3.6 atol=1e-10
        @test flow_m3s_to_hm3(100.0, 0.0) == 0.0
        @test flow_m3s_to_hm3(0.0, 1.0) == 0.0
        @test @inferred(flow_m3s_to_hm3(1.0, 1.0)) isa Float64
    end

    @testset "hm3_to_flow_m3s" begin
        @test hm3_to_flow_m3s(0.18, 0.5) ≈ 100.0 atol=1e-10
        @test hm3_to_flow_m3s(3.6, 1.0) ≈ 1000.0 atol=1e-10
        @test_throws ArgumentError hm3_to_flow_m3s(1.0, 0.0)
        err = try hm3_to_flow_m3s(1.0, 0.0) catch e e end
        @test occursin("zero duration", err.msg)
        @test @inferred(hm3_to_flow_m3s(1.0, 1.0)) isa Float64
    end

    @testset "submarket_id_by_name" begin
        submarkets = LabDessem.Core.Submarket[
            LabDessem.Core.Submarket(id=1, name="SE", demand_mw=Float64[]),
            LabDessem.Core.Submarket(id=2, name="S", demand_mw=Float64[]),
            LabDessem.Core.Submarket(id=3, name="NE", demand_mw=Float64[]),
        ]
        @test submarket_id_by_name(submarkets, "SE") == 1
        @test submarket_id_by_name(submarkets, "S") == 2
        @test submarket_id_by_name(submarkets, " S ") == 2
        @test_throws KeyError submarket_id_by_name(submarkets, "N")
        err = try submarket_id_by_name(submarkets, "N") catch e e end
        @test occursin("N", string(err.key))
    end

    @testset "hours_to_periods" begin
        @test hours_to_periods(1.0, 0.5) == 2
        @test hours_to_periods(1.5, 0.5) == 3
        @test hours_to_periods(0.0, 0.5) == 0
        @test hours_to_periods(0.1, 0.5) == 1
        @test_throws ArgumentError hours_to_periods(-1.0, 0.5)
        @test_throws ArgumentError hours_to_periods(1.0, 0.0)
        @test @inferred(hours_to_periods(1.0, 0.5)) isa Int
    end

    @testset "normalize_max_bound" begin
        @test normalize_max_bound(10.0, 100.0, "pmax", "UHE1") == 100.0
        @test normalize_max_bound(10.0, 10.0, "pmax", "UHE1") == 10.0
        @test normalize_max_bound(10.0, 9.995, "pmax", "UHE1") == 10.0
        @test_throws ArgumentError normalize_max_bound(10.0, 5.0, "pmax", "UHE1")
        @test @inferred(normalize_max_bound(1.0, 2.0, "f", "n")) isa Float64
    end
end
