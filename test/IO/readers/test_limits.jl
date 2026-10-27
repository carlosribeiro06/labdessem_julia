using Test
using LabDessem
using LabDessem.IO

const FIXTURE_DIR = joinpath(@__DIR__, "..", "fixtures")

@testset "Limits Reader" begin
    mkpath(FIXTURE_DIR)

    @testset "read_interchange_limits" begin
        oper_path = joinpath(FIXTURE_DIR, "oper_limite_intercambio.csv")
        open(oper_path, "w") do io
            write(io, "SbmDe;SbmPara;Limite.mw;Penalidade.R\$/MWh\n")
            write(io, "1;2;1000;500\n")
            write(io, "2;1;800;600\n")
        end
        
        limits = read_interchange_limits(oper_path)
        
        @test length(limits) == 2
        @test limits[1].from_submarket_id == 1
        @test limits[1].to_submarket_id == 2
        @test limits[1].max_flow_mw == 1000.0
        @test limits[1].penalty_cost_per_mwh == 500.0
        
        rm(oper_path)
    end

    @testset "read_interchange_limits missing file" begin
        limits = read_interchange_limits("/nonexistent/path.csv")
        @test isempty(limits)
    end

    @testset "read_residual_costs" begin
        oper_path = joinpath(FIXTURE_DIR, "oper_custo_residual.csv")
        open(oper_path, "w") do io
            write(io, "Submercado;CMO.R\$/MWh\n")
            write(io, "1;150.5\n")
            write(io, "2;200.0\n")
        end
        
        costs = read_residual_costs(oper_path, true)
        
        @test length(costs) == 2
        @test costs[1].submarket_id == 1
        @test costs[1].cmo_per_mwh == 150.5
        
        rm(oper_path)
    end

    @testset "read_residual_costs disabled" begin
        oper_path = joinpath(FIXTURE_DIR, "oper_custo_residual_disabled.csv")
        open(oper_path, "w") do io
            write(io, "Submercado;CMO.R\$/MWh\n")
            write(io, "1;150.5\n")
        end
        
        costs = read_residual_costs(oper_path, false)
        @test isempty(costs)
        
        rm(oper_path)
    end

    @testset "read_operational_limits" begin
        function make_horizon()
            csv_path = joinpath(FIXTURE_DIR, "oper_duracao_lim.csv")
            open(csv_path, "w") do io
                write(io, "Periodo;Duracao.h\n")
                for i in 1:10
                    write(io, "$i;0.5\n")
                end
            end
            h = read_horizon(csv_path)
            rm(csv_path)
            h
        end
        
        horizon = make_horizon()
        
        thermal_plants = [
            LabDessem.Core.ThermalPlant(
                id=0, name="UTE-1", submarket_id=1, bus_id=1,
                units=[LabDessem.Core.ThermalUnit(
                    id=1, name="UTE-1-1", min_generation_mw=0.0, max_generation_mw=100.0,
                    startup_trajectory_mw=Float64[], shutdown_trajectory_mw=Float64[],
                    min_up_time=0, min_down_time=0, startup_cost=0.0, shutdown_cost=0.0,
                    variable_cost_per_mwh=50.0,
                    initial_condition=LabDessem.Core.ThermalInitialCondition(
                        is_on=false, generation_mw=0.0, time_in_state=0, time_in_ramp=0,
                        is_ramping_up=false, is_ramping_down=false
                    )
                )]
            )
        ]
        
        hydro_plants = [
            LabDessem.Core.HydroPlant(
                id=1, name="UHE-1", submarket_id=1, bus_id=2,
                upstream_plant_ids=Int[], downstream_plant_id=nothing,
                diversion_upstream_plant_ids=Int[], diversion_plant_id=nothing,
                reservoir=LabDessem.Core.Reservoir(100.0, 200.0, 150.0),
                natural_inflow_hm3=zeros(10), water_withdrawal_hm3=zeros(10),
                spillage_cost_per_hm3=0.1, turbining_cost_per_hm3=0.1,
                specific_productivity_mw_per_m3s=1.0, hydraulic_loss_m=nothing,
                efficiency=nothing, fpha_segments=LabDessem.Core.HydroFphaSegment[],
                groups=LabDessem.Core.HydroGroup[], turbine_type=LabDessem.Core.Francis,
                volume_level_table=nothing, tailrace_coefficients=nothing
            )
        ]
        
        pumping_plants = LabDessem.Core.PumpingPlant[]
        
        oper_path = joinpath(FIXTURE_DIR, "oper_rest_lim.csv")
        open(oper_path, "w") do io
            write(io, "PeriodoInicial;PeriodoFinal;CodigoUsina;NomeUsina;Variavel;Linf;Lsup\n")
            write(io, "1;5;0;UTE-1;GER;10;90\n")
            write(io, "I;F;1;UHE-1;VOL;100;-\n")
        end
        
        limits = read_operational_limits(oper_path, thermal_plants, hydro_plants, pumping_plants, horizon)
        
        @test length(limits) == 2
        
        @test limits[1].plant_name == "UTE-1"
        @test limits[1].variable == LabDessem.Core.Generation
        @test limits[1].start_period == 1
        @test limits[1].end_period == 5
        @test limits[1].lower_bound == 10.0
        @test limits[1].upper_bound == 90.0
        @test limits[1].target isa LabDessem.Core.ThermalPlantTarget
        
        @test limits[2].plant_name == "UHE-1"
        @test limits[2].variable == LabDessem.Core.Volume
        @test limits[2].start_period == 1
        @test limits[2].end_period == 10
        @test limits[2].lower_bound == 100.0
        @test limits[2].upper_bound === nothing
        @test limits[2].target isa LabDessem.Core.HydroPlantTarget
        
        rm(oper_path)
    end

    @testset "type inference" begin
        @test @inferred(read_interchange_limits("/nonexistent.csv")) isa Vector{LabDessem.Core.InterchangeLimit}
        @test @inferred(read_residual_costs("/nonexistent.csv", false)) isa Vector{LabDessem.Core.ResidualCost}
    end
end
