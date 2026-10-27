using Test
using LabDessem
using LabDessem.IO

const FIXTURE_DIR = joinpath(@__DIR__, "..", "fixtures")

@testset "Renewable Reader" begin
    mkpath(FIXTURE_DIR)

    function make_horizon(periods::Int)
        csv_path = joinpath(FIXTURE_DIR, "oper_duracao_ren.csv")
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

    function make_submarkets()
        [
            LabDessem.Core.Submarket(id=1, name="Fic1", demand_mw=[0.0]),
            LabDessem.Core.Submarket(id=2, name="Fic2", demand_mw=[0.0])
        ]
    end

    @testset "basic reading" begin
        horizon = make_horizon(3)
        sbms = make_submarkets()
        
        cad_path = joinpath(FIXTURE_DIR, "cad_ren_basic.csv")
        open(cad_path, "w") do io
            write(io, "Codigo;Nome;Barra;Submercado\n")
            write(io, "0;EOL-1;1;Fic1\n")
            write(io, "1;UFV-1;2;Fic2\n")
        end
        
        oper_path = joinpath(FIXTURE_DIR, "oper_ren_basic.csv")
        open(oper_path, "w") do io
            write(io, "Periodo;Codigo;Nome;GerProg.mw\n")
            write(io, "1;0;EOL-1;100.0\n")
            write(io, "2;0;EOL-1;120.0\n")
            write(io, "3;0;EOL-1;80.0\n")
            write(io, "1;1;UFV-1;50.0\n")
            write(io, "2;1;UFV-1;200.0\n")
            write(io, "3;1;UFV-1;150.0\n")
        end
        
        plants = read_renewable_plants(cad_path, oper_path, sbms, horizon, false)
        
        @test length(plants) == 2
        @test plants[1].id == 0
        @test plants[1].name == "EOL-1"
        @test plants[1].available_generation_mw == [100.0, 120.0, 80.0]
        
        @test plants[2].id == 1
        @test plants[2].name == "UFV-1"
        @test plants[2].available_generation_mw == [50.0, 200.0, 150.0]
        
        rm(cad_path); rm(oper_path)
    end

    @testset "missing operation data" begin
        horizon = make_horizon(2)
        sbms = make_submarkets()
        
        cad_path = joinpath(FIXTURE_DIR, "cad_ren_nooper.csv")
        open(cad_path, "w") do io
            write(io, "Codigo;Nome;Barra;Submercado\n")
            write(io, "0;EOL-1;1;Fic1\n")
        end
        
        oper_path = joinpath(FIXTURE_DIR, "oper_ren_nooper.csv")
        open(oper_path, "w") do io
            write(io, "Periodo;Codigo;Nome;GerProg.mw\n")
        end
        
        plants = read_renewable_plants(cad_path, oper_path, sbms, horizon, false)
        
        @test length(plants) == 1
        @test plants[1].available_generation_mw == [0.0, 0.0]
        
        rm(cad_path); rm(oper_path)
    end

    @testset "empty catalog" begin
        horizon = make_horizon(1)
        sbms = make_submarkets()
        
        cad_path = joinpath(FIXTURE_DIR, "cad_ren_empty.csv")
        open(cad_path, "w") do io
            write(io, "Codigo;Nome;Barra;Submercado\n")
        end
        
        oper_path = joinpath(FIXTURE_DIR, "oper_ren_empty.csv")
        open(oper_path, "w") do io
            write(io, "Periodo;Codigo;Nome;GerProg.mw\n")
        end
        
        plants = read_renewable_plants(cad_path, oper_path, sbms, horizon, false)
        @test isempty(plants)
        
        rm(cad_path); rm(oper_path)
    end

    @testset "type inference" begin
        horizon = make_horizon(1)
        sbms = make_submarkets()
        
        cad_path = joinpath(FIXTURE_DIR, "cad_ren_infer.csv")
        open(cad_path, "w") do io
            write(io, "Codigo;Nome;Barra;Submercado\n")
            write(io, "0;EOL-1;1;Fic1\n")
        end
        
        oper_path = joinpath(FIXTURE_DIR, "oper_ren_infer.csv")
        open(oper_path, "w") do io
            write(io, "Periodo;Codigo;Nome;GerProg.mw\n")
            write(io, "1;0;EOL-1;100.0\n")
        end
        
        @test @inferred(read_renewable_plants(cad_path, oper_path, sbms, horizon, false)) isa Vector{LabDessem.Core.RenewablePlant}
        
        rm(cad_path); rm(oper_path)
    end
end
