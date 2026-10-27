using Test
using LabDessem
using LabDessem.IO

const FIXTURE_DIR = joinpath(@__DIR__, "..", "fixtures")

@testset "Thermal Reader" begin
    mkpath(FIXTURE_DIR)

    function make_horizon(periods::Int)
        csv_path = joinpath(FIXTURE_DIR, "oper_duracao_thermal.csv")
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
        cad_path = joinpath(FIXTURE_DIR, "cad_sbm_thermal.csv")
        oper_path = joinpath(FIXTURE_DIR, "oper_sbm_thermal.csv")
        open(cad_path, "w") do io
            write(io, "Codigo;Nome\n1;SE\n2;S\n")
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
        
        cad_path = joinpath(FIXTURE_DIR, "cad_unid_ute_basic.csv")
        open(cad_path, "w") do io
            write(io, "CodigoUTE;NomeUTE;Unidade;Pmin.mw;Pmax.mw;Ton.h;Toff.h;GerInic.mw;StatusInic;Tinic.h;RupInic;RdownInic;TRampaInic.h;CVU.R\$/MWh;CustoPartida.R\$;CustoDesliga.R\$;Barra;Submercado\n")
            write(io, "0;Termica-1;1;100;200;1;1;0;0;10;0;0;0;50.0;100;50;1;SE\n")
            write(io, "1;Termica-2;1;50;150;0.5;0.5;0;0;5;0;0;0;60.0;0;0;2;S\n")
        end
        
        ramp_path = joinpath(FIXTURE_DIR, "empty_ramps.csv")
        open(ramp_path, "w") do io
            write(io, "CodigoUTE;NomeUTE;Unidade;Traj;Passo.mw;Ipasso\n")
        end
        
        plants = read_thermal_plants(cad_path, ramp_path, horizon, sbms, false, false)
        
        @test length(plants) == 2
        @test plants[1].id == 0
        @test plants[1].name == "Termica-1"
        @test plants[1].submarket_id == 1
        @test length(plants[1].units) == 1
        @test plants[1].units[1].min_generation_mw == 100.0
        @test plants[1].units[1].max_generation_mw == 200.0
        @test plants[1].units[1].variable_cost_per_mwh == 50.0
        
        @test plants[2].id == 1
        @test plants[2].name == "Termica-2"
        
        rm(cad_path); rm(ramp_path)
    end

    @testset "with trajectories (uct_enabled)" begin
        horizon = make_horizon(2)
        sbms = make_submarkets(horizon)
        
        cad_path = joinpath(FIXTURE_DIR, "cad_unid_ute_traj.csv")
        open(cad_path, "w") do io
            write(io, "CodigoUTE;NomeUTE;Unidade;Pmin.mw;Pmax.mw;Ton.h;Toff.h;GerInic.mw;StatusInic;Tinic.h;RupInic;RdownInic;TRampaInic.h;CVU.R\$/MWh;CustoPartida.R\$;CustoDesliga.R\$;Barra;Submercado\n")
            write(io, "0;Termica-1;1;100;200;1;1;150;1;5;0;0;0;50.0;100;50;1;SE\n")
        end
        
        ramp_path = joinpath(FIXTURE_DIR, "ramps_traj.csv")
        open(ramp_path, "w") do io
            write(io, "CodigoUTE;NomeUTE;Unidade;Traj;Passo.mw; Ipasso\n")
            write(io, "0;Termica-1;1; A ;0;1\n")
            write(io, "0;Termica-1;1; A ;50;2\n")
            write(io, "0;Termica-1;1; A ;100;3\n")
            write(io, "0;Termica-1;1; D ;80;1\n")
            write(io, "0;Termica-1;1; D ;40;2\n")
        end
        
        plants = read_thermal_plants(cad_path, ramp_path, horizon, sbms, true, false)
        
        @test length(plants) == 1
        unit = plants[1].units[1]
        @test unit.startup_trajectory_mw == [0.0, 50.0, 100.0]
        @test unit.shutdown_trajectory_mw == [80.0, 40.0]
        @test unit.initial_condition.is_on == true
        @test unit.initial_condition.generation_mw == 150.0
        @test unit.initial_condition.time_in_state == 10
        
        rm(cad_path); rm(ramp_path)
    end

    @testset "unknown submarket" begin
        horizon = make_horizon(1)
        sbms = make_submarkets(horizon)
        
        cad_path = joinpath(FIXTURE_DIR, "cad_unid_ute_bad_sbm.csv")
        open(cad_path, "w") do io
            write(io, "CodigoUTE;NomeUTE;Unidade;Pmin.mw;Pmax.mw;Ton.h;Toff.h;GerInic.mw;StatusInic;Tinic.h;RupInic;RdownInic;TRampaInic.h;CVU.R\$/MWh;CustoPartida.R\$;CustoDesliga.R\$;Barra;Submercado\n")
            write(io, "0;Termica-1;1;100;200;1;1;0;0;10;0;0;0;50.0;100;50;1;XYZ\n")
        end
        
        ramp_path = joinpath(FIXTURE_DIR, "empty_ramps2.csv")
        open(ramp_path, "w") do io
            write(io, "CodigoUTE;NomeUTE;Unidade;Traj;Passo.mw;Ipasso\n")
        end
        
        @test_throws KeyError read_thermal_plants(cad_path, ramp_path, horizon, sbms, false, false)
        
        rm(cad_path); rm(ramp_path)
    end

    @testset "normalize max bound" begin
        horizon = make_horizon(1)
        sbms = make_submarkets(horizon)
        
        cad_path = joinpath(FIXTURE_DIR, "cad_unid_ute_bounds.csv")
        open(cad_path, "w") do io
            write(io, "CodigoUTE;NomeUTE;Unidade;Pmin.mw;Pmax.mw;Ton.h;Toff.h;GerInic.mw;StatusInic;Tinic.h;RupInic;RdownInic;TRampaInic.h;CVU.R\$/MWh;CustoPartida.R\$;CustoDesliga.R\$;Barra;Submercado\n")
            write(io, "0;Termica-1;1;100;99.995;1;1;0;0;10;0;0;0;50.0;100;50;1;SE\n")
        end
        
        ramp_path = joinpath(FIXTURE_DIR, "empty_ramps3.csv")
        open(ramp_path, "w") do io
            write(io, "CodigoUTE;NomeUTE;Unidade;Traj;Passo.mw;Ipasso\n")
        end
        
        plants = read_thermal_plants(cad_path, ramp_path, horizon, sbms, false, false)
        @test plants[1].units[1].max_generation_mw == 100.0
        
        rm(cad_path); rm(ramp_path)
    end

    @testset "network_enabled=false uses submarket as bus" begin
        horizon = make_horizon(1)
        sbms = make_submarkets(horizon)
        
        cad_path = joinpath(FIXTURE_DIR, "cad_unid_ute_bus.csv")
        open(cad_path, "w") do io
            write(io, "CodigoUTE;NomeUTE;Unidade;Pmin.mw;Pmax.mw;Ton.h;Toff.h;GerInic.mw;StatusInic;Tinic.h;RupInic;RdownInic;TRampaInic.h;CVU.R\$/MWh;CustoPartida.R\$;CustoDesliga.R\$;Barra;Submercado\n")
            write(io, "0;Termica-1;1;100;200;1;1;0;0;10;0;0;0;50.0;100;50;999;SE\n")
        end
        
        ramp_path = joinpath(FIXTURE_DIR, "empty_ramps4.csv")
        open(ramp_path, "w") do io
            write(io, "CodigoUTE;NomeUTE;Unidade;Traj;Passo.mw;Ipasso\n")
        end
        
        plants = read_thermal_plants(cad_path, ramp_path, horizon, sbms, false, false)
        @test plants[1].bus_id == 1
        
        rm(cad_path); rm(ramp_path)
    end

    @testset "type inference" begin
        horizon = make_horizon(1)
        sbms = make_submarkets(horizon)
        
        cad_path = joinpath(FIXTURE_DIR, "cad_unid_ute_infer.csv")
        open(cad_path, "w") do io
            write(io, "CodigoUTE;NomeUTE;Unidade;Pmin.mw;Pmax.mw;Ton.h;Toff.h;GerInic.mw;StatusInic;Tinic.h;RupInic;RdownInic;TRampaInic.h;CVU.R\$/MWh;CustoPartida.R\$;CustoDesliga.R\$;Barra;Submercado\n")
            write(io, "0;Termica-1;1;100;200;1;1;0;0;10;0;0;0;50.0;100;50;1;SE\n")
        end
        
        ramp_path = joinpath(FIXTURE_DIR, "empty_ramps5.csv")
        open(ramp_path, "w") do io
            write(io, "CodigoUTE;NomeUTE;Unidade;Traj;Passo.mw;Ipasso\n")
        end
        
        @test @inferred(read_thermal_plants(cad_path, ramp_path, horizon, sbms, false, false)) isa Vector{LabDessem.Core.ThermalPlant}
        
        rm(cad_path); rm(ramp_path)
    end

    @testset "integration with 24Barras" begin
        base = joinpath(@__DIR__, "..", "..", "..", "..", "labdessem_rust", "examples", "24Barras")
        cad_path = joinpath(base, "CAD", "CAD_UNID_UTE.csv")
        ramp_path = joinpath(base, "CAD", "CAD_RAMPAS_TERMICAS.csv")
        horizon_path = joinpath(base, "OPER", "OPER_DURACAO.csv")
        cad_sbm = joinpath(base, "CAD", "CAD_SBM.csv")
        oper_sbm = joinpath(base, "OPER", "OPER_SBM.csv")
        
        if all(isfile, [cad_path, ramp_path, horizon_path, cad_sbm, oper_sbm])
            horizon = read_horizon(horizon_path)
            sbms = read_submarkets(cad_sbm, oper_sbm, horizon)
            plants = read_thermal_plants(cad_path, ramp_path, horizon, sbms, true, false)
            
            @test length(plants) == 3
            @test plants[1].name == "Termica-1"
            @test plants[2].name == "Termica-2"
            @test plants[3].name == "Termica-3"
            @test length(plants[1].units[1].startup_trajectory_mw) > 0
        else
            @warn "Skipping integration test: 24Barras data not found"
        end
    end
end
