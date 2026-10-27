using Test
using LabDessem
using LabDessem.Model
import LabDessem.Core as LDCore

function make_test_system(;
    num_periods=4,
    thermal_plants=nothing,
    hydro_plants=nothing,
    renewable_plants=nothing,
    pumping_plants=nothing,
    submarkets=nothing,
    interchange_limits=nothing
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
        future_cost_enabled=false,
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

function make_thermal_unit(id; pmin=10.0, pmax=100.0)
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

function make_thermal_plant(id, num_units; submarket_id=1, bus_id=1)
    LDCore.ThermalPlant(
        id=id,
        name="ThermalPlant$id",
        submarket_id=submarket_id,
        bus_id=bus_id,
        units=[make_thermal_unit(u) for u in 1:num_units]
    )
end

function make_hydro_unit(id)
    LDCore.HydroUnit(
        id=id,
        name="HydroUnit$id",
        min_generation_mw=0.0,
        max_generation_mw=100.0,
        max_turbining_hm3=10.0,
        effective_head_m=50.0,
        initial_condition=LDCore.HydroInitialCondition(is_on=true, generation_mw=50.0, time_in_state=10)
    )
end

function make_hydro_group(id, num_units)
    LDCore.HydroGroup(
        id=id,
        name="Group$id",
        units=[make_hydro_unit(u) for u in 1:num_units]
    )
end

function make_hydro_plant(id, groups_config; submarket_id=1, bus_id=1, num_periods=4)
    LDCore.HydroPlant(
        id=id,
        name="HydroPlant$id",
        submarket_id=submarket_id,
        bus_id=bus_id,
        upstream_plant_ids=Int[],
        downstream_plant_id=nothing,
        diversion_upstream_plant_ids=Int[],
        diversion_plant_id=nothing,
        reservoir=LDCore.Reservoir(min_volume_hm3=10.0, max_volume_hm3=100.0, initial_volume_hm3=50.0),
        natural_inflow_hm3=fill(10.0, num_periods),
        water_withdrawal_hm3=fill(0.0, num_periods),
        spillage_cost_per_hm3=0.1,
        turbining_cost_per_hm3=0.05,
        specific_productivity_mw_per_m3s=0.1,
        hydraulic_loss_m=nothing,
        efficiency=nothing,
        fpha_segments=LDCore.HydroFphaSegment[],
        groups=[make_hydro_group(g, n) for (g, n) in groups_config],
        turbine_type=LDCore.Francis,
        volume_level_table=nothing,
        tailrace_coefficients=nothing
    )
end

@testset "IndexSets" begin
    @testset "build_index_sets with thermal plants" begin
        plants = [
            make_thermal_plant(1, 3),
            make_thermal_plant(2, 2)
        ]
        system = make_test_system(num_periods=4, thermal_plants=plants)
        
        sets = build_index_sets(system)
        
        @test length(sets.periods) == 4
        @test sets.periods == [1, 2, 3, 4]
        @test length(sets.thermal_indices) == 20  # 5 units × 4 periods
        
        plant1_indices = filter(idx -> idx[1] == 1, sets.thermal_indices)
        @test length(plant1_indices) == 12  # 3 units × 4 periods
    end
    
    @testset "build_index_sets with hydro plants" begin
        plants = [make_hydro_plant(1, [(1, 1), (2, 1)])]  # 2 groups, 1 unit each
        system = make_test_system(num_periods=4, hydro_plants=plants)
        
        sets = build_index_sets(system)
        
        @test length(sets.hydro_indices) == 8  # 2 groups × 1 unit × 4 periods
        @test length(sets.hydro_plant_periods) == 4  # 1 plant × 4 periods
    end
    
    @testset "build_index_sets with empty collections" begin
        system = make_test_system(num_periods=4)
        
        sets = build_index_sets(system)
        
        @test isempty(sets.thermal_indices)
        @test isempty(sets.hydro_indices)
        @test isempty(sets.hydro_plant_periods)
        @test isempty(sets.renewable_indices)
        @test isempty(sets.pumping_indices)
        @test isempty(sets.interchange_indices)
        @test isempty(sets.submarket_periods)
        @test sets.periods == [1, 2, 3, 4]
    end
    
    @testset "build_index_sets validates periods" begin
        system = make_test_system(num_periods=0)
        @test_throws ArgumentError build_index_sets(system)
    end
    
    @testset "build_index_sets with submarkets" begin
        submarkets = [
            LDCore.Submarket(id=1, name="SE", demand_mw=fill(1000.0, 4)),
            LDCore.Submarket(id=2, name="NE", demand_mw=fill(800.0, 4))
        ]
        system = make_test_system(num_periods=4, submarkets=submarkets)
        
        sets = build_index_sets(system)
        
        @test length(sets.submarket_periods) == 8  # 2 submarkets × 4 periods
    end
    
    @testset "build_index_sets with interchange limits" begin
        limits = [
            LDCore.InterchangeLimit(from_submarket_id=1, to_submarket_id=2, max_flow_mw=500.0, penalty_cost_per_mwh=0.0),
            LDCore.InterchangeLimit(from_submarket_id=2, to_submarket_id=1, max_flow_mw=400.0, penalty_cost_per_mwh=0.0)
        ]
        system = make_test_system(num_periods=4, interchange_limits=limits)
        
        sets = build_index_sets(system)
        
        @test length(sets.interchange_indices) == 8  # 2 directions × 4 periods
    end
    
    @testset "attach_index_sets!" begin
        container = ModelContainer()
        system = make_test_system(num_periods=4)
        sets = build_index_sets(system)
        
        @test container.index_sets === nothing
        attach_index_sets!(container, sets)
        @test container.index_sets === sets
    end
    
    @testset "thermal_gen_indices" begin
        plants = [
            make_thermal_plant(1, 3),
            make_thermal_plant(2, 2)
        ]
        system = make_test_system(num_periods=4, thermal_plants=plants)
        sets = build_index_sets(system)
        
        indices = thermal_gen_indices(sets, 1)
        @test length(indices) == 12  # 3 units × 4 periods
        @test all(idx -> idx[1] == 1, indices)
        
        indices_missing = thermal_gen_indices(sets, 999)
        @test isempty(indices_missing)
    end
    
    @testset "hydro_gen_indices" begin
        plants = [make_hydro_plant(1, [(1, 2), (2, 1)])]  # 2 groups, 2+1 units
        system = make_test_system(num_periods=4, hydro_plants=plants)
        sets = build_index_sets(system)
        
        indices = hydro_gen_indices(sets, 1)
        @test length(indices) == 12  # 3 units × 4 periods
        @test all(idx -> idx[1] == 1, indices)
    end
    
    @testset "period_thermal_indices" begin
        plants = [make_thermal_plant(1, 2)]
        system = make_test_system(num_periods=4, thermal_plants=plants)
        sets = build_index_sets(system)
        
        indices = period_thermal_indices(sets, 2)
        @test length(indices) == 2  # 2 units in period 2
        @test all(idx -> idx[3] == 2, indices)
    end
    
    @testset "constraint_name" begin
        @test constraint_name("hydro_balance", (1, 5)) == "hydro_balance[1,5]"
        @test constraint_name("thermal_gen", (3, 2, 4)) == "thermal_gen[3,2,4]"
    end
end
