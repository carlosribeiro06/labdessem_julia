# Input module: readers and study assembly for DESSEM study data.
module Input

using ..Domain
using ..Domain: SubmarketId, BusId, BranchId, ThermalPlantId, ThermalUnitId, HydroPlantId, HydroGroupId, HydroUnitId, PumpingPlantId, RenewablePlantId
using CSV
using DataFrames
using JSON3
using Parquet2

# Common utilities
include("common.jl")

export read_csv
export flow_m3s_to_hm3, hm3_to_flow_m3s
export submarket_id_by_name
export hours_to_periods
export normalize_max_bound

# Study configuration
include("study_config.jl")

export FphaOption, ConstantProductivity, Precomputed, Computed
export StudyConfig, read_study_config
export is_fpha_enabled, is_fpha_precomputed

# Readers
include("readers/horizon.jl")

export read_horizon, internal_periods_for_original
include("readers/submarket.jl")

export read_submarkets
include("readers/thermal.jl")

export read_thermal_plants
include("readers/hydro.jl")

export read_hydro_plants
include("readers/network.jl")

export read_buses, read_branches, build_dummy_buses
include("readers/pumping.jl")

export read_pumping_plants
include("readers/renewable.jl")

export read_renewable_plants
include("readers/limits.jl")

export read_interchange_limits, read_residual_costs, read_operational_limits
include("readers/future_cost.jl")

export read_future_cost_cuts
include("readers/inflow_history.jl")

export read_inflow_history

# Study orchestration
include("study.jl")

export read_study_from_path, read_study_from_path_with_options

end
