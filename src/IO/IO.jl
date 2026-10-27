# IO module: readers and writers for DESSEM study data.
module IO

using ..Core
using CSV
using DataFrames
using JSON3
using Parquet2

# Common utilities
include("common.jl")

# Study configuration
include("study_config.jl")

# Readers
include("readers/horizon.jl")
include("readers/submarket.jl")
include("readers/thermal.jl")
include("readers/hydro.jl")
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
