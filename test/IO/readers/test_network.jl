using Test
using LabDessem
using LabDessem.IO

const FIXTURE_DIR = joinpath(@__DIR__, "..", "fixtures")

@testset "Network Reader" begin
    mkpath(FIXTURE_DIR)

    function make_horizon(periods::Int)
        csv_path = joinpath(FIXTURE_DIR, "oper_duracao_net.csv")
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

    function make_submarkets(horizon)
        cad_path = joinpath(FIXTURE_DIR, "cad_sbm_net.csv")
        oper_path = joinpath(FIXTURE_DIR, "oper_sbm_net.csv")
        open(cad_path, "w") do io
            write(io, "Codigo;Nome\n1;Fic1\n2;Fic2\n")
        end
        open(oper_path, "w") do io
            write(io, "CodigoSubmercado;Periodo;Demanda.mw\n")
            for p in 1:horizon.original_periods
                write(io, "1;$p;100.0\n2;$p;100.0\n")
            end
        end
        sbms = read_submarkets(cad_path, oper_path, horizon)
        rm(cad_path); rm(oper_path)
        sbms
    end

    @testset "read_buses" begin
        horizon = make_horizon(2)
        
        oper_path = joinpath(FIXTURE_DIR, "oper_carga_barra.csv")
        open(oper_path, "w") do io
            write(io, "CodigoBarra;NomeBarra;Periodo;Carga.mw;CodigoSubmercado;Swing\n")
            write(io, "1;BARRA 1;1;100.0;1;True\n")
            write(io, "1;BARRA 1;2;110.0;1;True\n")
            write(io, "2;BARRA 2;1;50.0;1;False\n")
            write(io, "2;BARRA 2;2;55.0;1;False\n")
        end
        
        buses = read_buses(oper_path, horizon)
        
        @test length(buses) == 2
        @test buses[1].id == 1
        @test buses[1].name == "BARRA 1"
        @test buses[1].angle_reference == true
        @test buses[1].demand_mw == [100.0, 110.0]
        
        @test buses[2].id == 2
        @test buses[2].name == "BARRA 2"
        @test buses[2].angle_reference == false
        @test buses[2].demand_mw == [50.0, 55.0]
        
        rm(oper_path)
    end

    @testset "read_buses inconsistent data" begin
        horizon = make_horizon(2)
        
        oper_path = joinpath(FIXTURE_DIR, "oper_carga_bad.csv")
        open(oper_path, "w") do io
            write(io, "CodigoBarra;NomeBarra;Periodo;Carga.mw;CodigoSubmercado;Swing\n")
            write(io, "1;BARRA 1;1;100.0;1;True\n")
            write(io, "1;BARRA X;2;110.0;1;True\n")
        end
        
        @test_throws ArgumentError read_buses(oper_path, horizon)
        
        rm(oper_path)
    end

    @testset "read_branches" begin
        oper_path = joinpath(FIXTURE_DIR, "oper_linha.csv")
        open(oper_path, "w") do io
            write(io, "De;Para;Capacidade.mw;Reatancia.pu;CodigoLinha\n")
            write(io, "1;2;600;0.0139;1\n")
            write(io, "1;3;600;0.2112;2\n")
        end
        
        branches = read_branches(oper_path)
        
        @test length(branches) == 2
        @test branches[1].id == 1
        @test branches[1].from_bus_id == 1
        @test branches[1].to_bus_id == 2
        @test branches[1].thermal_limit_mw == 600.0
        @test branches[1].reactance_pu ≈ 0.0139
        
        rm(oper_path)
    end

    @testset "build_dummy_buses" begin
        horizon = make_horizon(2)
        sbms = make_submarkets(horizon)
        
        buses = build_dummy_buses(sbms, horizon)
        
        @test length(buses) == 2
        @test buses[1].name == "DUMMY-BUS-Fic1"
        @test buses[1].angle_reference == true
        @test length(buses[1].demand_mw) == 2
        @test all(d -> d == 0.0, buses[1].demand_mw)
        
        @test buses[2].name == "DUMMY-BUS-Fic2"
        @test buses[2].angle_reference == false
    end

    @testset "type inference" begin
        horizon = make_horizon(1)
        
        oper_path = joinpath(FIXTURE_DIR, "oper_carga_infer.csv")
        open(oper_path, "w") do io
            write(io, "CodigoBarra;NomeBarra;Periodo;Carga.mw;CodigoSubmercado;Swing\n")
            write(io, "1;BARRA 1;1;100.0;1;True\n")
        end
        
        @test @inferred(read_buses(oper_path, horizon)) isa Vector{LabDessem.Core.Bus}
        rm(oper_path)
        
        branch_path = joinpath(FIXTURE_DIR, "oper_linha_infer.csv")
        open(branch_path, "w") do io
            write(io, "De;Para;Capacidade.mw;Reatancia.pu;CodigoLinha\n")
            write(io, "1;2;600;0.01;1\n")
        end
        
        @test @inferred(read_branches(branch_path)) isa Vector{LabDessem.Core.Branch}
        rm(branch_path)
    end

    @testset "integration with 24Barras" begin
        base = joinpath(@__DIR__, "..", "..", "..", "..", "labdessem_rust", "examples", "24Barras")
        bus_path = joinpath(base, "OPER", "OPER_CARGA_BARRA.csv")
        branch_path = joinpath(base, "OPER", "OPER_LINHA.csv")
        horizon_path = joinpath(base, "OPER", "OPER_DURACAO.csv")
        
        if all(isfile, [bus_path, branch_path, horizon_path])
            horizon = read_horizon(horizon_path)
            buses = read_buses(bus_path, horizon)
            branches = read_branches(branch_path)
            
            @test length(buses) == 24
            @test length(branches) > 0
            @test any(b -> b.angle_reference, buses)
        else
            @warn "Skipping integration test: 24Barras network data not found"
        end
    end
end
