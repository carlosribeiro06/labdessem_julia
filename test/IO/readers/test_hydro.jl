using Test
using LabDessem
using LabDessem.IO

const FIXTURE_DIR = joinpath(@__DIR__, "..", "fixtures")

@testset "Hydro Reader" begin
    mkpath(FIXTURE_DIR)

    function make_horizon(periods::Int)
        csv_path = joinpath(FIXTURE_DIR, "oper_duracao_hydro.csv")
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
        cad_path = joinpath(FIXTURE_DIR, "cad_sbm_hydro.csv")
        oper_path = joinpath(FIXTURE_DIR, "oper_sbm_hydro.csv")
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

    @testset "basic reading" begin
        horizon = make_horizon(2)
        sbms = make_submarkets(horizon)
        
        cad_path = joinpath(FIXTURE_DIR, "cad_uhe_basic.csv")
        open(cad_path, "w") do io
            write(io, "Codigo;Nome;VolInic.hm3;Vmin.hm3;Vmax.hm3;Tipo;Jusante;Desvio;Submercado;PenalVert.R\$/hm3;PenalTurb.R\$/hm3;Prod.mw/m3s;Turbina\n")
            write(io, "0;UHE-A;100;50;200;RV;1;-;Fic2;0.2;0.8;1.0;1\n")
            write(io, "1;UHE-B;50;50;50;FD;-;-;Fic2;0.2;0.8;1.0;2\n")
        end
        
        conj_path = joinpath(FIXTURE_DIR, "cad_conj_basic.csv")
        open(conj_path, "w") do io
            write(io, "Codigo;Nome;Conjunto;Unidades;Pmin.mw;Pmax.mw;StatusInic;Tinic.h;Barra;MaxTurb.m3/s;Hef.m\n")
            write(io, "0;UHE-A;1;2;10;100;0;0;1;50;30\n")
            write(io, "1;UHE-B;1;1;5;50;1;5;2;25;20\n")
        end
        
        vazao_path = joinpath(FIXTURE_DIR, "oper_vazao_basic.csv")
        open(vazao_path, "w") do io
            write(io, "Codigo;Periodo;Nome;Afluencia.m3/s;Retirada.m3/s\n")
            write(io, "0;1;UHE-A;100;1.0\n")
            write(io, "0;2;UHE-A;120;1.5\n")
            write(io, "1;1;UHE-B;50;0.5\n")
            write(io, "1;2;UHE-B;60;0.6\n")
        end
        
        plants = read_hydro_plants(cad_path, conj_path, vazao_path, nothing, horizon, sbms, false, false)
        
        @test length(plants) == 2
        @test plants[1].id == 0
        @test plants[1].name == "UHE-A"
        @test length(plants[1].groups) == 1
        @test length(plants[1].groups[1].units) == 2
        
        @test plants[2].id == 1
        @test plants[2].name == "UHE-B"
        @test length(plants[2].groups) == 1
        @test length(plants[2].groups[1].units) == 1
        
        @test plants[1].downstream_plant_id == 1
        @test 0 in plants[2].upstream_plant_ids
        
        @test plants[1].natural_inflow_hm3[1] ≈ flow_m3s_to_hm3(100.0, 0.5)
        
        rm(cad_path); rm(conj_path); rm(vazao_path)
    end

    @testset "cascade references" begin
        horizon = make_horizon(1)
        sbms = make_submarkets(horizon)
        
        cad_path = joinpath(FIXTURE_DIR, "cad_uhe_cascade.csv")
        open(cad_path, "w") do io
            write(io, "Codigo;Nome;VolInic.hm3;Vmin.hm3;Vmax.hm3;Tipo;Jusante;Desvio;Submercado;PenalVert.R\$/hm3;PenalTurb.R\$/hm3;Prod.mw/m3s;Turbina\n")
            write(io, "0;UHE-A;100;50;200;RV;1;-;Fic2;0.2;0.8;1.0;1\n")
            write(io, "1;UHE-B;50;50;50;FD;2;-;Fic2;0.2;0.8;1.0;2\n")
            write(io, "2;UHE-C;50;50;50;FD;-;-;Fic2;0.2;0.8;1.0;2\n")
        end
        
        conj_path = joinpath(FIXTURE_DIR, "cad_conj_cascade.csv")
        open(conj_path, "w") do io
            write(io, "Codigo;Nome;Conjunto;Unidades;Pmin.mw;Pmax.mw;StatusInic;Tinic.h;Barra;MaxTurb.m3/s;Hef.m\n")
            write(io, "0;UHE-A;1;1;10;100;0;0;1;50;30\n")
            write(io, "1;UHE-B;1;1;10;100;0;0;2;50;30\n")
            write(io, "2;UHE-C;1;1;10;100;0;0;3;50;30\n")
        end
        
        vazao_path = joinpath(FIXTURE_DIR, "oper_vazao_cascade.csv")
        open(vazao_path, "w") do io
            write(io, "Codigo;Periodo;Nome;Afluencia.m3/s;Retirada.m3/s\n")
            write(io, "0;1;UHE-A;100;0\n")
            write(io, "1;1;UHE-B;100;0\n")
            write(io, "2;1;UHE-C;100;0\n")
        end
        
        plants = read_hydro_plants(cad_path, conj_path, vazao_path, nothing, horizon, sbms, false, false)
        
        @test plants[1].downstream_plant_id == 1
        @test plants[2].downstream_plant_id == 2
        @test plants[3].downstream_plant_id === nothing
        
        @test isempty(plants[1].upstream_plant_ids)
        @test 0 in plants[2].upstream_plant_ids
        @test 1 in plants[3].upstream_plant_ids
        
        rm(cad_path); rm(conj_path); rm(vazao_path)
    end

    @testset "turbine types" begin
        horizon = make_horizon(1)
        sbms = make_submarkets(horizon)
        
        cad_path = joinpath(FIXTURE_DIR, "cad_uhe_turb.csv")
        open(cad_path, "w") do io
            write(io, "Codigo;Nome;VolInic.hm3;Vmin.hm3;Vmax.hm3;Tipo;Jusante;Desvio;Submercado;PenalVert.R\$/hm3;PenalTurb.R\$/hm3;Prod.mw/m3s;Turbina\n")
            write(io, "0;UHE-F;100;50;200;RV;-;-;Fic2;0.2;0.8;1.0;1\n")
            write(io, "1;UHE-K;50;50;50;FD;-;-;Fic2;0.2;0.8;1.0;2\n")
        end
        
        conj_path = joinpath(FIXTURE_DIR, "cad_conj_turb.csv")
        open(conj_path, "w") do io
            write(io, "Codigo;Nome;Conjunto;Unidades;Pmin.mw;Pmax.mw;StatusInic;Tinic.h;Barra;MaxTurb.m3/s;Hef.m\n")
            write(io, "0;UHE-F;1;1;10;100;0;0;1;50;30\n")
            write(io, "1;UHE-K;1;1;10;100;0;0;2;50;30\n")
        end
        
        vazao_path = joinpath(FIXTURE_DIR, "oper_vazao_turb.csv")
        open(vazao_path, "w") do io
            write(io, "Codigo;Periodo;Nome;Afluencia.m3/s;Retirada.m3/s\n")
            write(io, "0;1;UHE-F;100;0\n")
            write(io, "1;1;UHE-K;100;0\n")
        end
        
        plants = read_hydro_plants(cad_path, conj_path, vazao_path, nothing, horizon, sbms, false, false)
        
        @test plants[1].turbine_type == LabDessem.Core.Francis
        @test plants[2].turbine_type == LabDessem.Core.Kaplan
        
        rm(cad_path); rm(conj_path); rm(vazao_path)
    end

    @testset "type inference" begin
        horizon = make_horizon(1)
        sbms = make_submarkets(horizon)
        
        cad_path = joinpath(FIXTURE_DIR, "cad_uhe_infer.csv")
        open(cad_path, "w") do io
            write(io, "Codigo;Nome;VolInic.hm3;Vmin.hm3;Vmax.hm3;Tipo;Jusante;Desvio;Submercado;PenalVert.R\$/hm3;PenalTurb.R\$/hm3;Prod.mw/m3s;Turbina\n")
            write(io, "0;UHE-A;100;50;200;RV;-;-;Fic2;0.2;0.8;1.0;1\n")
        end
        
        conj_path = joinpath(FIXTURE_DIR, "cad_conj_infer.csv")
        open(conj_path, "w") do io
            write(io, "Codigo;Nome;Conjunto;Unidades;Pmin.mw;Pmax.mw;StatusInic;Tinic.h;Barra;MaxTurb.m3/s;Hef.m\n")
            write(io, "0;UHE-A;1;1;10;100;0;0;1;50;30\n")
        end
        
        vazao_path = joinpath(FIXTURE_DIR, "oper_vazao_infer.csv")
        open(vazao_path, "w") do io
            write(io, "Codigo;Periodo;Nome;Afluencia.m3/s;Retirada.m3/s\n")
            write(io, "0;1;UHE-A;100;0\n")
        end
        
        @test @inferred(read_hydro_plants(cad_path, conj_path, vazao_path, nothing, horizon, sbms, false, false)) isa Vector{LabDessem.Core.HydroPlant}
        
        rm(cad_path); rm(conj_path); rm(vazao_path)
    end

    @testset "integration with 24Barras" begin
        base = joinpath(@__DIR__, "..", "..", "..", "..", "labdessem_rust", "examples", "24Barras")
        cad_path = joinpath(base, "CAD", "CAD_UHE.csv")
        conj_path = joinpath(base, "CAD", "CAD_CONJ_UHE.csv")
        vazao_path = joinpath(base, "OPER", "OPER_VAZAO.csv")
        horizon_path = joinpath(base, "OPER", "OPER_DURACAO.csv")
        cad_sbm = joinpath(base, "CAD", "CAD_SBM.csv")
        oper_sbm = joinpath(base, "OPER", "OPER_SBM.csv")
        
        if all(isfile, [cad_path, conj_path, vazao_path, horizon_path, cad_sbm, oper_sbm])
            horizon = read_horizon(horizon_path)
            sbms = read_submarkets(cad_sbm, oper_sbm, horizon)
            plants = read_hydro_plants(cad_path, conj_path, vazao_path, nothing, horizon, sbms, false, false)
            
            @test length(plants) > 0
            @test !isempty(plants[1].name)
            
            total_groups = sum(length(p.groups) for p in plants)
            total_units = sum(sum(length(g.units) for g in p.groups) for p in plants)
            @test total_groups > 0
            @test total_units > 0
        else
            @warn "Skipping integration test: 24Barras data not found"
        end
    end
end
