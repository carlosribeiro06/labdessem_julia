# IO module: readers and writers for DESSEM study data.
module IO

# NOTE: Julia's builtin Core conflicts with LabDessem.Core, so we use explicit imports.
import ..Core as LDCore
using ..Core: SubmarketId, BusId, BranchId, ThermalPlantId, ThermalUnitId, HydroPlantId, HydroGroupId, HydroUnitId, PumpingPlantId, RenewablePlantId
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

# Writers
include("writers/common.jl")

export write_csv, operational_limit_variable_label
export original_period_for_internal, original_period_duration_hours
export average_internal_values, sum_internal_values
export thermal_residence_times
include("writers/hydro.jl")
include("writers/thermal.jl")
include("writers/pumping.jl")
include("writers/renewable.jl")
include("writers/network.jl")
include("writers/summary.jl")
include("writers/limits.jl")
include("writers/orchestrator.jl")

# Study orchestration
include("study.jl")

end
