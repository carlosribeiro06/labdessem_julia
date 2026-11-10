# Domain entity structs.

@enum TurbineType Francis Kaplan Unknown

function turbine_alpha(t::TurbineType)::Float64
    t == Francis && return 0.5
    t == Kaplan && return 0.2
    return 0.5
end

Base.@kwdef struct ThermalInitialCondition
    is_on::Bool
    generation_mw::Float64
    time_in_state::Int
    time_in_ramp::Int
    is_ramping_up::Bool
    is_ramping_down::Bool
end

Base.@kwdef struct ThermalUnit
    id::ThermalUnitId
    name::String
    min_generation_mw::Float64
    max_generation_mw::Float64
    startup_trajectory_mw::Vector{Float64}
    shutdown_trajectory_mw::Vector{Float64}
    min_up_time::Int
    min_down_time::Int
    startup_cost::Float64
    shutdown_cost::Float64
    variable_cost_per_mwh::Float64
    initial_condition::ThermalInitialCondition
end

Base.@kwdef struct ThermalPlant
    id::ThermalPlantId
    name::String
    submarket_id::SubmarketId
    bus_id::BusId
    units::Vector{ThermalUnit}
end

Base.@kwdef struct HydroInitialCondition
    is_on::Bool
    generation_mw::Float64
    time_in_state::Int
end

Base.@kwdef struct HydroUnit
    id::HydroUnitId
    name::String
    min_generation_mw::Float64
    max_generation_mw::Float64
    max_turbining_hm3::Float64
    effective_head_m::Float64
    initial_condition::HydroInitialCondition
end

Base.@kwdef struct HydroGroup
    id::HydroGroupId
    name::String
    units::Vector{HydroUnit}
end

Base.@kwdef struct Reservoir
    min_volume_hm3::Float64
    max_volume_hm3::Float64
    initial_volume_hm3::Float64
end

Base.@kwdef struct HydroFphaSegment
    segment::Int
    correction_factor::Float64
    rhs::Float64
    volume_coefficient::Float64
    turbining_coefficient::Float64
    lateral_flow_coefficient::Float64
end

Base.@kwdef struct HydroPlant
    id::HydroPlantId
    name::String
    submarket_id::SubmarketId
    bus_id::BusId
    upstream_plant_ids::Vector{HydroPlantId}
    downstream_plant_id::Union{HydroPlantId, Nothing}
    diversion_upstream_plant_ids::Vector{HydroPlantId}
    diversion_plant_id::Union{HydroPlantId, Nothing}
    reservoir::Reservoir
    natural_inflow_hm3::Vector{Float64}
    water_withdrawal_hm3::Vector{Float64}
    spillage_cost_per_hm3::Float64
    turbining_cost_per_hm3::Float64
    specific_productivity_mw_per_m3s::Float64
    hydraulic_loss_m::Union{Float64, Nothing}
    efficiency::Union{Float64, Nothing}
    fpha_segments::Vector{HydroFphaSegment}
    groups::Vector{HydroGroup}
    turbine_type::TurbineType
    volume_level_table::Union{Vector{Tuple{Float64, Float64}}, Nothing}
    tailrace_coefficients::Union{NTuple{5, Float64}, Nothing}
end

# Network entities

Base.@kwdef struct Submarket
    id::SubmarketId
    name::String
    demand_mw::Vector{Float64}
end

Base.@kwdef struct Bus
    id::BusId
    name::String
    submarket_id::SubmarketId
    angle_reference::Bool
    demand_mw::Vector{Float64}
end

Base.@kwdef struct Branch
    id::BranchId
    name::String
    from_bus_id::BusId
    to_bus_id::BusId
    reactance_pu::Float64
    thermal_limit_mw::Float64
end

# Other plants

Base.@kwdef struct PumpingPlant
    id::PumpingPlantId
    name::String
    submarket_id::SubmarketId
    bus_id::BusId
    downstream_hydro_id::HydroPlantId
    upstream_hydro_id::HydroPlantId
    min_pumping_hm3::Float64
    max_pumping_hm3::Float64
    specific_consumption_mw_per_m3s::Float64
end

Base.@kwdef struct RenewablePlant
    id::RenewablePlantId
    name::String
    submarket_id::SubmarketId
    bus_id::BusId
    available_generation_mw::Vector{Float64}
end

# System-level types

Base.@kwdef struct InterchangeLimit
    from_submarket_id::SubmarketId
    to_submarket_id::SubmarketId
    max_flow_mw::Float64
    penalty_cost_per_mwh::Float64
end

Base.@kwdef struct ResidualCost
    submarket_id::SubmarketId
    cmo_per_mwh::Float64
end

Base.@kwdef struct FutureCostCut
    stage_id::Int
    cut_id::Int
    slot_index::Int
    iteration::Int
    forward_pass_index::Int
    intercept::Float64
    coefficients::Vector{Float64}
    is_active::Bool
end

Base.@kwdef struct StudyHorizon
    periods::Int
    period_duration_hours::Float64
    original_periods::Int
    original_period_durations_hours::Vector{Float64}
    internal_to_original_period::Vector{Int}
    internal_subperiod_index::Vector{Int}
end

# Operational limit types

@enum OperationalLimitVariable Generation Spillage Volume Defluence Turbining Diversion Pumping

abstract type OperationalLimitTarget end

struct ThermalPlantTarget <: OperationalLimitTarget
    id::ThermalPlantId
end

struct ThermalUnitTarget <: OperationalLimitTarget
    plant_id::ThermalPlantId
    unit_id::ThermalUnitId
end

struct HydroPlantTarget <: OperationalLimitTarget
    id::HydroPlantId
end

struct HydroUnitTarget <: OperationalLimitTarget
    plant_id::HydroPlantId
    unit_id::HydroUnitId
end

struct PumpingPlantTarget <: OperationalLimitTarget
    id::PumpingPlantId
end

Base.@kwdef struct OperationalLimit
    target::OperationalLimitTarget
    plant_name::String
    variable::OperationalLimitVariable
    start_period::Int
    end_period::Int
    lower_bound::Union{Float64, Nothing}
    upper_bound::Union{Float64, Nothing}
end

# Supporting types

Base.@kwdef struct InflowHistoryRow
    plant_id::HydroPlantId
    year::Int
    month::Int
    inflow_hm3::Float64
end

Base.@kwdef struct EngMaxBounds
    lower_mw::Float64
    upper_mw::Float64
end

# System container

Base.@kwdef struct System
    horizon::StudyHorizon
    thermal_unit_commitment_enabled::Bool
    hydro_unit_commitment_enabled::Bool
    ton_residual_enabled::Bool
    fpha_enabled::Bool
    future_cost_enabled::Bool
    residual_costs::Vector{ResidualCost}
    future_cost_cuts::Vector{FutureCostCut}
    submarkets::Vector{Submarket}
    interchange_limits::Vector{InterchangeLimit}
    operational_limits::Vector{OperationalLimit}
    buses::Vector{Bus}
    branches::Vector{Branch}
    thermal_plants::Vector{ThermalPlant}
    hydro_plants::Vector{HydroPlant}
    pumping_plants::Vector{PumpingPlant}
    renewable_plants::Vector{RenewablePlant}
    inflow_history::Vector{InflowHistoryRow}
end
