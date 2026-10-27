# IO module: readers and writers for DESSEM study data.
module IO

# NOTE: Julia's builtin Core conflicts with LabDessem.Core, so we use explicit imports.
import ..Core as LDCore
using ..Core: SubmarketId, BusId, ThermalPlantId, ThermalUnitId, HydroPlantId, HydroGroupId, HydroUnitId
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
include("readers/pumping.jl")
include("readers/renewable.jl")
include("readers/limits.jl")
include("readers/future_cost.jl")
include("readers/inflow_history.jl")

# Writers
include("writers/common.jl")
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
