using Test
using JuMP
using HiGHS
using LabDessem
using LabDessem.Model
import LabDessem.Core as LDCore

function make_integration_system()
    num_periods = 4
    
    horizon = LDCore.StudyHorizon(
        periods=num_periods,
        period_duration_hours=0.5,
        original_periods=num_periods,
        original_period_durations_hours=fill(0.5, num_periods),
        internal_to_original_period=collect(1:num_periods),
        internal_subperiod_index=ones(Int, num_periods)
    )
    
    thermal_unit = LDCore.ThermalUnit(
        id=1,
        name="Unit1",
        min_generation_mw=10.0,
        max_generation_mw=100.0,
        startup_trajectory_mw=Float64[],
        shutdown_trajectory_mw=Float64[],
        min_up_time=1,
        min_down_time=1,
        startup_cost=1000.0,
        shutdown_cost=500.0,
        variable_cost_per_mwh=50.0,
        initial_condition=LDCore.ThermalInitialCondition(
            is_on=true, generation_mw=50.0, time_in_state=10,
            time_in_ramp=0, is_ramping_up=false, is_ramping_down=false
        )
    )
    
    thermal_plant = LDCore.ThermalPlant(
        id=1, name="Thermal1", submarket_id=1, bus_id=1, units=[thermal_unit]
    )
    
    hydro_unit = LDCore.HydroUnit(
        id=1, name="HydroUnit1",
        min_generation_mw=0.0, max_generation_mw=100.0,
        max_turbining_hm3=10.0, effective_head_m=50.0,
        initial_condition=LDCore.HydroInitialCondition(is_on=true, generation_mw=50.0, time_in_state=10)
    )
    
    hydro_group = LDCore.HydroGroup(id=1, name="Group1", units=[hydro_unit])
    
    hydro_plant = LDCore.HydroPlant(
        id=1, name="Hydro1", submarket_id=1, bus_id=1,
        upstream_plant_ids=Int[], downstream_plant_id=nothing,
        diversion_upstream_plant_ids=Int[], diversion_plant_id=nothing,
        reservoir=LDCore.Reservoir(min_volume_hm3=10.0, max_volume_hm3=100.0, initial_volume_hm3=50.0),
        natural_inflow_hm3=fill(5.0, num_periods),
        water_withdrawal_hm3=fill(0.0, num_periods),
        spillage_cost_per_hm3=0.1, turbining_cost_per_hm3=0.01,
        specific_productivity_mw_per_m3s=10.0,
        hydraulic_loss_m=nothing, efficiency=nothing,
        fpha_segments=LDCore.HydroFphaSegment[],
        groups=[hydro_group],
        turbine_type=LDCore.Francis,
        volume_level_table=nothing, tailrace_coefficients=nothing
    )
    
    submarket = LDCore.Submarket(id=1, name="SE", demand_mw=fill(80.0, num_periods))
    
    return LDCore.System(
        horizon=horizon,
        thermal_unit_commitment_enabled=true,
        hydro_unit_commitment_enabled=false,
        ton_residual_enabled=false,
        fpha_enabled=false,
        future_cost_enabled=false,
        residual_costs=LDCore.ResidualCost[],
        future_cost_cuts=LDCore.FutureCostCut[],
        submarkets=[submarket],
        interchange_limits=LDCore.InterchangeLimit[],
        operational_limits=LDCore.OperationalLimit[],
        buses=LDCore.Bus[],
        branches=LDCore.Branch[],
        thermal_plants=[thermal_plant],
        hydro_plants=[hydro_plant],
        pumping_plants=LDCore.PumpingPlant[],
        renewable_plants=LDCore.RenewablePlant[],
        inflow_history=LDCore.InflowHistoryRow[]
    )
end

@testset "Model Integration" begin
    @testset "build_model creates complete model" begin
        system = make_integration_system()
        config = ModelConfig(thermal_uc_enabled=true)
        
        container = build_model(system, config)
        
        @test container.model isa JuMP.Model
        @test container.index_sets !== nothing
        
        model = container.model
        @test haskey(model, :thermal_gen)
        @test haskey(model, :thermal_commit)
        @test haskey(model, :hydro_gen)
        @test haskey(model, :hydro_turb)
        @test haskey(model, :hydro_volume)
        @test haskey(model, :deficit)
        
        @test num_variables(model) > 0
        @test num_constraints(model; count_variable_in_set_constraints=false) > 0
    end
    
    @testset "build_model and solve" begin
        system = make_integration_system()
        config = ModelConfig(thermal_uc_enabled=false)
        
        container = build_model(system, config)
        
        set_silent(container.model)
        optimize!(container.model)
        
        @test termination_status(container.model) == OPTIMAL
        @test primal_status(container.model) == FEASIBLE_POINT
        @test objective_value(container.model) >= 0
        
        model = container.model
        for t in 1:4
            total_gen = value(model[:thermal_gen][(1, 1, t)])
            for g in system.hydro_plants[1].groups
                for u in g.units
                    total_gen += value(model[:hydro_gen][(1, g.id, u.id, t)])
                end
            end
            deficit_val = value(model[:deficit][(1, t)])
            demand = system.submarkets[1].demand_mw[t]
            
            @test isapprox(total_gen + deficit_val, demand; atol=1e-4)
        end
    end
    
    @testset "build_model with UC enabled" begin
        system = make_integration_system()
        config = ModelConfig(thermal_uc_enabled=true)
        
        container = build_model(system, config)
        
        set_silent(container.model)
        optimize!(container.model)
        
        @test termination_status(container.model) == OPTIMAL
    end
end
