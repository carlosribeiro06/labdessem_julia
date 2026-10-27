using Test
using LabDessem
using LabDessem.IO

const FIXTURE_DIR = joinpath(@__DIR__, "..", "fixtures")

@testset "Horizon Reader" begin

    @testset "basic reading" begin
        mkpath(FIXTURE_DIR)
        csv_path = joinpath(FIXTURE_DIR, "oper_duracao_basic.csv")
        open(csv_path, "w") do io
            write(io, "Periodo;Duracao.h\n")
            write(io, "1;0.5\n")
            write(io, "2;0.5\n")
            write(io, "3;1.0\n")
        end
        
        horizon = read_horizon(csv_path)
        
        @test horizon.periods == 4
        @test horizon.period_duration_hours == 0.5
        @test horizon.original_periods == 3
        @test horizon.original_period_durations_hours == [0.5, 0.5, 1.0]
        @test horizon.internal_to_original_period == [1, 2, 3, 3]
        @test horizon.internal_subperiod_index == [1, 1, 1, 2]
        
        rm(csv_path)
    end

    @testset "non-sequential periods" begin
        csv_path = joinpath(FIXTURE_DIR, "oper_duracao_nonseq.csv")
        open(csv_path, "w") do io
            write(io, "Periodo;Duracao.h\n")
            write(io, "3;0.5\n")
            write(io, "1;0.5\n")
            write(io, "2;0.5\n")
        end
        
        horizon = read_horizon(csv_path)
        @test horizon.internal_to_original_period == [1, 2, 3]
        
        rm(csv_path)
    end

    @testset "internal_periods_for_original" begin
        csv_path = joinpath(FIXTURE_DIR, "oper_duracao_lookup.csv")
        open(csv_path, "w") do io
            write(io, "Periodo;Duracao.h\n")
            write(io, "1;0.5\n")
            write(io, "2;1.0\n")
            write(io, "3;0.5\n")
        end
        
        horizon = read_horizon(csv_path)
        
        @test internal_periods_for_original(horizon, 1) == [0]
        @test internal_periods_for_original(horizon, 2) == [1, 2]
        @test internal_periods_for_original(horizon, 3) == [3]
        @test internal_periods_for_original(horizon, 99) == Int[]
        
        rm(csv_path)
    end

    @testset "missing column" begin
        csv_path = joinpath(FIXTURE_DIR, "oper_duracao_missing_col.csv")
        open(csv_path, "w") do io
            write(io, "Periodo;Duration\n")
            write(io, "1;0.5\n")
        end
        
        @test_throws ArgumentError read_horizon(csv_path)
        err = try read_horizon(csv_path) catch e e end
        @test occursin("Duracao.h", err.msg)
        
        rm(csv_path)
    end

    @testset "duplicate period" begin
        csv_path = joinpath(FIXTURE_DIR, "oper_duracao_dup.csv")
        open(csv_path, "w") do io
            write(io, "Periodo;Duracao.h\n")
            write(io, "1;0.5\n")
            write(io, "2;0.5\n")
            write(io, "2;0.5\n")
        end
        
        @test_throws ArgumentError read_horizon(csv_path)
        err = try read_horizon(csv_path) catch e e end
        @test occursin("Duplicate", err.msg)
        @test occursin("2", err.msg)
        
        rm(csv_path)
    end

    @testset "invalid duration" begin
        csv_path = joinpath(FIXTURE_DIR, "oper_duracao_invalid.csv")
        open(csv_path, "w") do io
            write(io, "Periodo;Duracao.h\n")
            write(io, "1;0.75\n")
        end
        
        @test_throws ArgumentError read_horizon(csv_path)
        err = try read_horizon(csv_path) catch e e end
        @test occursin("multiple", err.msg)
        
        rm(csv_path)
    end

    @testset "type inference" begin
        csv_path = joinpath(FIXTURE_DIR, "oper_duracao_infer.csv")
        open(csv_path, "w") do io
            write(io, "Periodo;Duracao.h\n")
            write(io, "1;0.5\n")
        end
        
        @test @inferred(read_horizon(csv_path)) isa LabDessem.Core.StudyHorizon
        
        rm(csv_path)
    end

    @testset "integration with Rust example" begin
        rust_path = joinpath(@__DIR__, "..", "..", "..", "..", "labdessem_rust", "examples", "24Barras", "OPER", "OPER_DURACAO.csv")
        if isfile(rust_path)
            horizon = read_horizon(rust_path)
            @test horizon.periods == 48
            @test horizon.original_periods == 48
            @test all(d -> d == 0.5, horizon.original_period_durations_hours)
            @test horizon.internal_to_original_period == collect(1:48)
        else
            @warn "Skipping integration test: $rust_path not found"
        end
    end
end
