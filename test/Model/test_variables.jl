using Test
using JuMP
using HiGHS
using LabDessem
using LabDessem.Model
import LabDessem.Core as LDCore

function make_test_system_vars(;
    num_periods=4,
    thermal_plants=nothing,
    hydro_plants=nothing,
    renewable_plants=nothing,
    pumping_plants=nothing,
    submarkets=nothing,
    interchange_limits=nothing,
    future_cost_enabled=false
)
    horizon = LDCore.StudyHorizon(
        periods=num_periods,
        period_duration_hours=0.5,
        original_periods=num_periods,
        original_period_durations_hours=fill(0.5, num_periods),
        internal_to_original_period=collect(1:num_periods),
        internal_subperiod_index=ones(Int, num_periods)
    )
    
    thermal_plants = something(thermal_plants, LDCore.ThermalPlant[])
    hydro_plants = something(hydro_plants, LDCore.HydroPlant[])
    renewable_plants = something(renewable_plants, LDCore.RenewablePlant[])
    pumping_plants = something(pumping_plants, LDCore.PumpingPlant[])
    submarkets = something(submarkets, LDCore.Submarket[])
    interchange_limits = something(interchange_limits, LDCore.InterchangeLimit[])
    
    return LDCore.System(
        horizon=horizon,
        thermal_unit_commitment_enabled=true,
        hydro_unit_commitment_enabled=false,
        ton_residual_enabled=false,
        fpha_enabled=false,
        future_cost_enabled=future_cost_enabled,
        residual_costs=LDCore.ResidualCost[],
        future_cost_cuts=LDCore.FutureCostCut[],
        submarkets=submarkets,
        interchange_limits=interchange_limits,
        operational_limits=LDCore.OperationalLimit[],
        buses=LDCore.Bus[],
        branches=LDCore.Branch[],
        thermal_plants=thermal_plants,
        hydro_plants=hydro_plants,
        pumping_plants=pumping_plants,
        renewable_plants=renewable_plants,
        inflow_history=LDCore.InflowHistoryRow[]
    )
end

function make_thermal_unit_vars(id; pmin=10.0, pmax=100.0)
    LDCore.ThermalUnit(
        id=id,
        name="Unit$id",
        min_generation_mw=pmin,
        max_generation_mw=pmax,
        startup_trajectory_mw=Float64[],
        shutdown_trajectory_mw=Float64[],
        min_up_time=1,
        min_down_time=1,
        startup_cost=0.0,
        shutdown_cost=0.0,
        variable_cost_per_mwh=50.0,
        initial_condition=LDCore.ThermalInitialCondition(
            is_on=true, generation_mw=50.0, time_in_state=10,
            time_in_ramp=0, is_ramping_up=false, is_ramping_down=false
        )
    )
end

function make_thermal_plant_vars(id, num_units; pmax=100.0)
    LDCore.ThermalPlant(
        id=id,
        name="ThermalPlant$id",
        submarket_id=1,
        bus_id=1,
        units=[make_thermal_unit_vars(u, pmax=pmax) for u in 1:num_units]
    )
end

function make_hydro_unit_vars(id; pmax=100.0, qmax=10.0)
    LDCore.HydroUnit(
        id=id,
        name="HydroUnit$id",
        min_generation_mw=0.0,
        max_generation_mw=pmax,
        max_turbining_hm3=qmax,
        effective_head_m=50.0,
        initial_condition=LDCore.HydroInitialCondition(is_on=true, generation_mw=50.0, time_in_state=10)
    )
end

function make_hydro_group_vars(id, num_units)
    LDCore.HydroGroup(
        id=id,
        name="Group$id",
        units=[make_hydro_unit_vars(u) for u in 1:num_units]
    )
end

function make_hydro_plant_vars(id, groups_config; vmin=10.0, vmax=100.0, num_periods=4, diversion=false)
    LDCore.HydroPlant(
        id=id,
        name="HydroPlant$id",
        submarket_id=1,
        bus_id=1,
        upstream_plant_ids=Int[],
        downstream_plant_id=nothing,
        diversion_upstream_plant_ids=Int[],
        diversion_plant_id=diversion ? 99 : nothing,
        reservoir=LDCore.Reservoir(min_volume_hm3=vmin, max_volume_hm3=vmax, initial_volume_hm3=50.0),
        natural_inflow_hm3=fill(10.0, num_periods),
        water_withdrawal_hm3=fill(0.0, num_periods),
        spillage_cost_per_hm3=0.1,
        turbining_cost_per_hm3=0.05,
        specific_productivity_mw_per_m3s=0.1,
        hydraulic_loss_m=nothing,
        efficiency=nothing,
        fpha_segments=LDCore.HydroFphaSegment[],
        groups=[make_hydro_group_vars(g, n) for (g, n) in groups_config],
        turbine_type=LDCore.Francis,
        volume_level_table=nothing,
        tailrace_coefficients=nothing
    )
end

@testset "Variables" begin
    @testset "create_thermal_variables! with UC enabled" begin
        plants = [make_thermal_plant_vars(1, 2, pmax=150.0)]
        system = make_test_system_vars(num_periods=4, thermal_plants=plants)
        
        config = ModelConfig(thermal_uc_enabled=true)
        container = ModelContainer(config)
        sets = build_index_sets(system)
        attach_index_sets!(container, sets)
        
        create_thermal_variables!(container, system)
        
        model = container.model
        @test haskey(model, :thermal_gen)
        @test haskey(model, :thermal_commit)
        @test haskey(model, :thermal_startup)
        @test haskey(model, :thermal_shutdown)
        
        @test upper_bound(model[:thermal_gen][(1, 1, 1)]) == 150.0
        @test is_binary(model[:thermal_commit][(1, 1, 1)])
    end
    
    @testset "create_thermal_variables! with UC disabled" begin
        plants = [make_thermal_plant_vars(1, 2)]
        system = make_test_system_vars(num_periods=4, thermal_plants=plants)
        
        config = ModelConfig(thermal_uc_enabled=false)
        container = ModelContainer(config)
        sets = build_index_sets(system)
        attach_index_sets!(container, sets)
        
        create_thermal_variables!(container, system)
        
        model = container.model
        @test is_fixed(model[:thermal_commit][(1, 1, 1)])
        @test fix_value(model[:thermal_commit][(1, 1, 1)]) == 1.0
    end
    
    @testset "create_thermal_variables! empty indices" begin
        system = make_test_system_vars(num_periods=4)
        
        container = ModelContainer()
        sets = build_index_sets(system)
        attach_index_sets!(container, sets)
        
        @test create_thermal_variables!(container, system) === nothing
    end
    
    @testset "create_thermal_variables! requires index_sets" begin
        plants = [make_thermal_plant_vars(1, 2)]
        system = make_test_system_vars(num_periods=4, thermal_plants=plants)
        container = ModelContainer()
        
        @test_throws ErrorException create_thermal_variables!(container, system)
    end
    
    @testset "create_hydro_variables!" begin
        plants = [make_hydro_plant_vars(1, [(1, 2)], vmin=50.0, vmax=200.0)]
        system = make_test_system_vars(num_periods=4, hydro_plants=plants)
        
        container = ModelContainer()
        sets = build_index_sets(system)
        attach_index_sets!(container, sets)
        
        create_hydro_variables!(container, system)
        
        model = container.model
        @test haskey(model, :hydro_gen)
        @test haskey(model, :hydro_turb)
        @test haskey(model, :hydro_spill)
        @test haskey(model, :hydro_volume)
        @test haskey(model, :hydro_commit)
        
        @test lower_bound(model[:hydro_volume][(1, 1)]) == 50.0
        @test upper_bound(model[:hydro_volume][(1, 1)]) == 200.0
        @test is_fixed(model[:hydro_commit][(1, 1, 1, 1)])
    end
    
    @testset "create_hydro_variables! diversion fixed when no diversion" begin
        plants = [make_hydro_plant_vars(1, [(1, 1)], diversion=false)]
        system = make_test_system_vars(num_periods=4, hydro_plants=plants)
        
        container = ModelContainer()
        sets = build_index_sets(system)
        attach_index_sets!(container, sets)
        
        create_hydro_variables!(container, system)
        
        model = container.model
        @test is_fixed(model[:hydro_diversion][(1, 1)])
        @test fix_value(model[:hydro_diversion][(1, 1)]) == 0.0
    end
    
    @testset "create_renewable_variables!" begin
        plants = [LDCore.RenewablePlant(
            id=1, name="Solar1", submarket_id=1, bus_id=1,
            available_generation_mw=[50.0, 60.0, 70.0, 80.0]
        )]
        system = make_test_system_vars(num_periods=4, renewable_plants=plants)
        
        container = ModelContainer()
        sets = build_index_sets(system)
        attach_index_sets!(container, sets)
        
        create_renewable_variables!(container, system)
        
        model = container.model
        @test haskey(model, :renewable_gen)
        @test upper_bound(model[:renewable_gen][(1, 2)]) == 60.0
    end
    
    @testset "create_interchange_variables!" begin
        limits = [
            LDCore.InterchangeLimit(from_submarket_id=1, to_submarket_id=2, max_flow_mw=500.0, penalty_cost_per_mwh=0.0)
        ]
        system = make_test_system_vars(num_periods=4, interchange_limits=limits)
        
        container = ModelContainer()
        sets = build_index_sets(system)
        attach_index_sets!(container, sets)
        
        create_interchange_variables!(container, system)
        
        model = container.model
        @test haskey(model, :interchange)
        @test upper_bound(model[:interchange][(1, 2, 1)]) == 500.0
    end
    
    @testset "create_system_variables! with future cost enabled" begin
        submarkets = [LDCore.Submarket(id=1, name="SE", demand_mw=fill(1000.0, 4))]
        system = make_test_system_vars(num_periods=4, submarkets=submarkets, future_cost_enabled=true)
        
        container = ModelContainer()
        sets = build_index_sets(system)
        attach_index_sets!(container, sets)
        
        create_system_variables!(container, system)
        
        model = container.model
        @test haskey(model, :future_cost)
        @test haskey(model, :deficit)
    end
    
    @testset "create_system_variables! without future cost" begin
        submarkets = [LDCore.Submarket(id=1, name="SE", demand_mw=fill(1000.0, 4))]
        system = make_test_system_vars(num_periods=4, submarkets=submarkets, future_cost_enabled=false)
        
        container = ModelContainer()
        sets = build_index_sets(system)
        attach_index_sets!(container, sets)
        
        create_system_variables!(container, system)
        
        model = container.model
        @test !haskey(model, :future_cost)
        @test haskey(model, :deficit)
    end
end
