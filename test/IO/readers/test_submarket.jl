using Test
using LabDessem
using LabDessem.IO

const FIXTURE_DIR = joinpath(@__DIR__, "..", "fixtures")

@testset "Submarket Reader" begin
    mkpath(FIXTURE_DIR)

    function make_horizon(periods::Int)
        csv_path = joinpath(FIXTURE_DIR, "oper_duracao_sbm.csv")
        open(csv_path, "w") do io
            write(io, "Periodo;Duracao.h\n")
            for i in 1:periods
                write(io, "$i;0.5\n")
            end
        end
        h = read_horizon(csv_path)
        rm(csv_path)
        h
    end

    @testset "basic reading" begin
        horizon = make_horizon(3)
        
        cad_path = joinpath(FIXTURE_DIR, "cad_sbm_basic.csv")
        open(cad_path, "w") do io
            write(io, "Codigo;Nome\n")
            write(io, "1;SE\n")
            write(io, "2;S\n")
        end
        
        oper_path = joinpath(FIXTURE_DIR, "oper_sbm_basic.csv")
        open(oper_path, "w") do io
            write(io, "CodigoSubmercado;Periodo;Demanda.mw\n")
            write(io, "1;1;100.0\n")
            write(io, "1;2;110.0\n")
            write(io, "1;3;120.0\n")
            write(io, "2;1;200.0\n")
            write(io, "2;2;210.0\n")
            write(io, "2;3;220.0\n")
        end
        
        sbms = read_submarkets(cad_path, oper_path, horizon)
        
        @test length(sbms) == 2
        @test sbms[1].id == 1
        @test sbms[1].name == "SE"
        @test sbms[1].demand_mw == [100.0, 110.0, 120.0]
        @test sbms[2].id == 2
        @test sbms[2].name == "S"
        @test sbms[2].demand_mw == [200.0, 210.0, 220.0]
        
        rm(cad_path)
        rm(oper_path)
    end

    @testset "unknown submarket in OPER" begin
        horizon = make_horizon(1)
        
        cad_path = joinpath(FIXTURE_DIR, "cad_sbm_unknown.csv")
        open(cad_path, "w") do io
            write(io, "Codigo;Nome\n")
            write(io, "1;SE\n")
        end
        
        oper_path = joinpath(FIXTURE_DIR, "oper_sbm_unknown.csv")
        open(oper_path, "w") do io
            write(io, "CodigoSubmercado;Periodo;Demanda.mw\n")
            write(io, "99;1;100.0\n")
        end
        
        @test_throws ArgumentError read_submarkets(cad_path, oper_path, horizon)
        err = try read_submarkets(cad_path, oper_path, horizon) catch e e end
        @test occursin("99", err.msg)
        
        rm(cad_path)
        rm(oper_path)
    end

    @testset "period out of range" begin
        horizon = make_horizon(2)
        
        cad_path = joinpath(FIXTURE_DIR, "cad_sbm_oor.csv")
        open(cad_path, "w") do io
            write(io, "Codigo;Nome\n")
            write(io, "1;SE\n")
        end
        
        oper_path = joinpath(FIXTURE_DIR, "oper_sbm_oor.csv")
        open(oper_path, "w") do io
            write(io, "CodigoSubmercado;Periodo;Demanda.mw\n")
            write(io, "1;1;100.0\n")
            write(io, "1;100;999.0\n")
        end
        
        @test_throws ArgumentError read_submarkets(cad_path, oper_path, horizon)
        
        rm(cad_path)
        rm(oper_path)
    end

    @testset "type inference" begin
        horizon = make_horizon(1)
        
        cad_path = joinpath(FIXTURE_DIR, "cad_sbm_infer.csv")
        open(cad_path, "w") do io
            write(io, "Codigo;Nome\n")
            write(io, "1;SE\n")
        end
        
        oper_path = joinpath(FIXTURE_DIR, "oper_sbm_infer.csv")
        open(oper_path, "w") do io
            write(io, "CodigoSubmercado;Periodo;Demanda.mw\n")
            write(io, "1;1;100.0\n")
        end
        
        @test @inferred(read_submarkets(cad_path, oper_path, horizon)) isa Vector{LabDessem.Core.Submarket}
        
        rm(cad_path)
        rm(oper_path)
    end

    @testset "integration with 24Barras" begin
        cad_path = joinpath(@__DIR__, "..", "..", "..", "..", "labdessem_rust", "examples", "24Barras", "CAD", "CAD_SBM.csv")
        oper_path = joinpath(@__DIR__, "..", "..", "..", "..", "labdessem_rust", "examples", "24Barras", "OPER", "OPER_SBM.csv")
        horizon_path = joinpath(@__DIR__, "..", "..", "..", "..", "labdessem_rust", "examples", "24Barras", "OPER", "OPER_DURACAO.csv")
        
        if isfile(cad_path) && isfile(oper_path) && isfile(horizon_path)
            horizon = read_horizon(horizon_path)
            sbms = read_submarkets(cad_path, oper_path, horizon)
            
            @test length(sbms) == 2
            @test sbms[1].name == "Fic1"
            @test sbms[2].name == "Fic2"
            @test length(sbms[1].demand_mw) == 48
        else
            @warn "Skipping integration test: 24Barras data not found"
        end
    end
end
