module TestHelpers

import LabDessem.Domain
using LabDessem.Domain: BusId, BranchId, SubmarketId

export make_test_bus, make_test_branch, make_network_system
export make_thermal_initial_condition, make_thermal_unit, make_thermal_plant, make_thermal_plant_with_units
export make_reservoir, make_hydro_initial_condition, make_hydro_unit, make_hydro_group
export make_hydro_plant, make_hydro_plant_with_groups
export make_submarket, make_bus, make_branch, make_pumping_plant, make_renewable_plant
export make_study_horizon, make_minimal_system, make_test_system
export FIXTURES_DIR, fixture_inputs
export Mismatch, DEFAULT_EXCLUDED, read_result_table, compare_result_file, compare_result_dirs
export Divergence, load_ledger, covers, cross_check

include("golden.jl")
include("ledger.jl")

const FIXTURES_DIR = joinpath(dirname(@__DIR__), "fixtures")

fixture_inputs(case::String = "24Barras") = joinpath(FIXTURES_DIR, case, "inputs")

"""Build a one-period `Domain.Bus` with a single demand value in MW."""
function make_test_bus(id::Int; is_ref::Bool=false, submarket::Int=1, demand::Float64=100.0)
    Domain.Bus(
        id=BusId(id),
        name="Bus$id",
        submarket_id=SubmarketId(submarket),
        angle_reference=is_ref,
        demand_mw=[demand]
    )
end

"""Build a `Domain.Branch` between two buses with the given reactance and thermal limit."""
function make_test_branch(id::Int, from::Int, to::Int; x::Float64=0.1, limit::Float64=100.0)
    Domain.Branch(
        id=BranchId(id),
        name="L$id",
        from_bus_id=BusId(from),
        to_bus_id=BusId(to),
        reactance_pu=x,
        thermal_limit_mw=limit
    )
end

"""Build a one-period `Domain.System` holding only the given buses and branches."""
function make_network_system(buses::Vector{Domain.Bus}, branches::Vector{Domain.Branch})
    horizon = Domain.StudyHorizon(
        periods=1,
        period_duration_hours=1.0,
        original_periods=1,
        original_period_durations_hours=[1.0],
        internal_to_original_period=[1],
        internal_subperiod_index=[1]
    )
    Domain.System(
        horizon=horizon,
        thermal_unit_commitment_enabled=false,
        hydro_unit_commitment_enabled=false,
        ton_residual_enabled=false,
        fpha_enabled=false,
        future_cost_enabled=false,
        residual_costs=Domain.ResidualCost[],
        future_cost_cuts=Domain.FutureCostCut[],
        submarkets=Domain.Submarket[],
        interchange_limits=Domain.InterchangeLimit[],
        operational_limits=Domain.OperationalLimit[],
        buses=buses,
        branches=branches,
        thermal_plants=Domain.ThermalPlant[],
        hydro_plants=Domain.HydroPlant[],
        pumping_plants=Domain.PumpingPlant[],
        renewable_plants=Domain.RenewablePlant[],
        inflow_history=Domain.InflowHistoryRow[]
    )
end

function make_thermal_initial_condition(; time_in_state=1)
    Domain.ThermalInitialCondition(
        is_on=true, generation_mw=50.0, time_in_state=time_in_state,
        time_in_ramp=0, is_ramping_up=false, is_ramping_down=false
    )
end

function make_thermal_unit(id=1; name="TU$(id)", pmin=0.0, pmax=100.0,
    startup_trajectory_mw=[50.0], shutdown_trajectory_mw=[50.0], time_in_state=1, startup_cost=1000.0)
    Domain.ThermalUnit(
        id=id, name=name, min_generation_mw=pmin, max_generation_mw=pmax,
        startup_trajectory_mw=startup_trajectory_mw, shutdown_trajectory_mw=shutdown_trajectory_mw,
        min_up_time=1, min_down_time=1, startup_cost=startup_cost, shutdown_cost=0.0,
        variable_cost_per_mwh=50.0, initial_condition=make_thermal_initial_condition(time_in_state=time_in_state)
    )
end

function make_thermal_plant(id=1; name="TP$(id)", submarket_id=1, bus_id=1, units=[make_thermal_unit(id)])
    Domain.ThermalPlant(id=id, name=name, submarket_id=submarket_id, bus_id=bus_id, units=units)
end

"""Build a thermal plant with units `1:num_units`; `unit_kwargs` are forwarded to `make_thermal_unit`."""
function make_thermal_plant_with_units(id, num_units; submarket_id=1, bus_id=1, unit_kwargs...)
    make_thermal_plant(id; submarket_id=submarket_id, bus_id=bus_id,
        units=[make_thermal_unit(u; unit_kwargs...) for u in 1:num_units])
end

function make_reservoir()
    Domain.Reservoir(min_volume_hm3=0.0, max_volume_hm3=100.0, initial_volume_hm3=50.0)
end

function make_hydro_initial_condition(; time_in_state=1)
    Domain.HydroInitialCondition(is_on=true, generation_mw=50.0, time_in_state=time_in_state)
end

function make_hydro_unit(id=1; name="HU$(id)", max_turbining_hm3=50.0, effective_head_m=100.0, time_in_state=1)
    Domain.HydroUnit(
        id=id, name=name, min_generation_mw=0.0, max_generation_mw=100.0,
        max_turbining_hm3=max_turbining_hm3, effective_head_m=effective_head_m,
        initial_condition=make_hydro_initial_condition(time_in_state=time_in_state)
    )
end

function make_hydro_group(id=1; name="HG$(id)", units=[make_hydro_unit(id)])
    Domain.HydroGroup(id=id, name=name, units=units)
end

function make_hydro_plant(id=1; name="HP$(id)", downstream_plant_id=nothing, upstream_plant_ids=Int[],
    submarket_id=1, bus_id=1, reservoir=make_reservoir(),
    natural_inflow_hm3=[10.0], water_withdrawal_hm3=[0.0],
    spillage_cost_per_hm3=0.0, turbining_cost_per_hm3=0.0, specific_productivity_mw_per_m3s=0.01,
    groups=[make_hydro_group(id)])
    Domain.HydroPlant(
        id=id, name=name, submarket_id=submarket_id, bus_id=bus_id,
        upstream_plant_ids=upstream_plant_ids, downstream_plant_id=downstream_plant_id,
        diversion_upstream_plant_ids=Int[], diversion_plant_id=nothing,
        reservoir=reservoir,
        natural_inflow_hm3=natural_inflow_hm3, water_withdrawal_hm3=water_withdrawal_hm3,
        spillage_cost_per_hm3=spillage_cost_per_hm3, turbining_cost_per_hm3=turbining_cost_per_hm3,
        specific_productivity_mw_per_m3s=specific_productivity_mw_per_m3s,
        hydraulic_loss_m=nothing, efficiency=nothing,
        fpha_segments=Domain.HydroFphaSegment[], groups=groups,
        turbine_type=Domain.Francis, volume_level_table=nothing, tailrace_coefficients=nothing
    )
end

"""
Build a hydro plant from `groups_config`, a vector of `(group_id, num_units)` pairs; each group holds units
`1:num_units`. Unit keywords go to `make_hydro_unit`; the remaining keywords go to `make_hydro_plant`.
"""
function make_hydro_plant_with_groups(id, groups_config; num_periods=4,
    max_turbining_hm3=50.0, effective_head_m=100.0, time_in_state=1, plant_kwargs...)
    groups = [
        make_hydro_group(g; units=[
            make_hydro_unit(u; max_turbining_hm3=max_turbining_hm3,
                effective_head_m=effective_head_m, time_in_state=time_in_state)
            for u in 1:n
        ])
        for (g, n) in groups_config
    ]
    make_hydro_plant(id; groups=groups,
        natural_inflow_hm3=fill(10.0, num_periods), water_withdrawal_hm3=fill(0.0, num_periods),
        plant_kwargs...)
end

function make_submarket(id=1; name="SM$(id)")
    Domain.Submarket(id=id, name=name, demand_mw=[100.0])
end

function make_bus(id=1; name="B$(id)", angle_reference=true)
    Domain.Bus(id=id, name=name, submarket_id=1, demand_mw=[50.0], angle_reference=angle_reference)
end

function make_branch(id=1; name="BR$(id)")
    Domain.Branch(id=id, name=name, from_bus_id=1, to_bus_id=2, reactance_pu=0.1, thermal_limit_mw=100.0)
end

function make_pumping_plant(id=1; name="PP$(id)")
    Domain.PumpingPlant(
        id=id, name=name, submarket_id=1, bus_id=1,
        downstream_hydro_id=1, upstream_hydro_id=2,
        min_pumping_hm3=0.0, max_pumping_hm3=50.0,
        specific_consumption_mw_per_m3s=0.01
    )
end

function make_renewable_plant(id=1; name="RP$(id)")
    Domain.RenewablePlant(id=id, name=name, submarket_id=1, bus_id=1, available_generation_mw=[100.0])
end

function make_study_horizon()
    Domain.StudyHorizon(
        periods=1, period_duration_hours=1.0,
        original_periods=1, original_period_durations_hours=[1.0],
        internal_to_original_period=[1], internal_subperiod_index=[1]
    )
end

function make_minimal_system(;
    submarkets=[make_submarket()],
    buses=[make_bus()],
    branches=Domain.Branch[],
    thermal_plants=Domain.ThermalPlant[],
    hydro_plants=Domain.HydroPlant[],
    pumping_plants=Domain.PumpingPlant[],
    renewable_plants=Domain.RenewablePlant[],
    interchange_limits=Domain.InterchangeLimit[],
    residual_costs=Domain.ResidualCost[],
    future_cost_cuts=Domain.FutureCostCut[],
    operational_limits=Domain.OperationalLimit[],
    inflow_history=Domain.InflowHistoryRow[],
    ton_residual_enabled=false,
    future_cost_enabled=false,
    fpha_enabled=false
)
    Domain.System(
        horizon=make_study_horizon(),
        thermal_unit_commitment_enabled=false,
        hydro_unit_commitment_enabled=false,
        ton_residual_enabled=ton_residual_enabled,
        fpha_enabled=fpha_enabled,
        future_cost_enabled=future_cost_enabled,
        residual_costs=residual_costs,
        future_cost_cuts=future_cost_cuts,
        submarkets=submarkets,
        interchange_limits=interchange_limits,
        operational_limits=operational_limits,
        buses=buses,
        branches=branches,
        thermal_plants=thermal_plants,
        hydro_plants=hydro_plants,
        pumping_plants=pumping_plants,
        renewable_plants=renewable_plants,
        inflow_history=inflow_history
    )
end

function make_test_system(;
    num_periods=4,
    thermal_plants=nothing,
    hydro_plants=nothing,
    renewable_plants=nothing,
    pumping_plants=nothing,
    submarkets=nothing,
    interchange_limits=nothing
)
    horizon = Domain.StudyHorizon(
        periods=num_periods,
        period_duration_hours=0.5,
        original_periods=num_periods,
        original_period_durations_hours=fill(0.5, num_periods),
        internal_to_original_period=collect(1:num_periods),
        internal_subperiod_index=ones(Int, num_periods)
    )
    
    thermal_plants = something(thermal_plants, Domain.ThermalPlant[])
    hydro_plants = something(hydro_plants, Domain.HydroPlant[])
    renewable_plants = something(renewable_plants, Domain.RenewablePlant[])
    pumping_plants = something(pumping_plants, Domain.PumpingPlant[])
    submarkets = something(submarkets, Domain.Submarket[])
    interchange_limits = something(interchange_limits, Domain.InterchangeLimit[])
    
    return Domain.System(
        horizon=horizon,
        thermal_unit_commitment_enabled=true,
        hydro_unit_commitment_enabled=false,
        ton_residual_enabled=false,
        fpha_enabled=false,
        future_cost_enabled=false,
        residual_costs=Domain.ResidualCost[],
        future_cost_cuts=Domain.FutureCostCut[],
        submarkets=submarkets,
        interchange_limits=interchange_limits,
        operational_limits=Domain.OperationalLimit[],
        buses=Domain.Bus[],
        branches=Domain.Branch[],
        thermal_plants=thermal_plants,
        hydro_plants=hydro_plants,
        pumping_plants=pumping_plants,
        renewable_plants=renewable_plants,
        inflow_history=Domain.InflowHistoryRow[]
    )
end

end
