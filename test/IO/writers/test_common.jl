using Test
using LabDessem
using LabDessem.IO
using DataFrames

const FIXTURE_DIR = joinpath(@__DIR__, "..", "fixtures")

@testset "Writer Common Utilities" begin
    mkpath(FIXTURE_DIR)

    @testset "write_csv" begin
        df = DataFrame(a=[1,2,3], b=[4.0,5.0,6.0])
        path = joinpath(FIXTURE_DIR, "test_write.csv")
        
        write_csv(path, df)
        
        @test isfile(path)
        content = read(path, String)
        @test occursin("a;b", content)
        @test occursin("1;4.0", content)
        
        rm(path)
    end

    @testset "write_csv creates directory" begin
        df = DataFrame(x=[1])
        path = joinpath(FIXTURE_DIR, "subdir", "test.csv")
        
        write_csv(path, df)
        
        @test isfile(path)
        rm(dirname(path), recursive=true)
    end

    @testset "operational_limit_variable_label" begin
        @test operational_limit_variable_label(LabDessem.Core.Generation) == "GER"
        @test operational_limit_variable_label(LabDessem.Core.Spillage) == "VERT"
        @test operational_limit_variable_label(LabDessem.Core.Volume) == "VOL"
        @test operational_limit_variable_label(LabDessem.Core.Pumping) == "QBOM"
    end

    @testset "sum_internal_values" begin
        periods = [1, 2, 3]
        values = p -> Float64(p * 10)
        @test sum_internal_values(periods, values) ≈ 60.0
    end

    @testset "thermal_residence_times" begin
        statuses = [true, true, false, false, true]
        times_on, times_off = thermal_residence_times(false, 2, statuses)
        
        @test times_on == [1, 2, 0, 0, 1]
        @test times_off == [0, 0, 1, 2, 0]
    end

    @testset "thermal_residence_times starting on" begin
        statuses = [true, true, true]
        times_on, times_off = thermal_residence_times(true, 5, statuses)
        
        @test times_on == [6, 7, 8]
        @test times_off == [0, 0, 0]
    end
end
