# Output module: writers for DESSEM study results.
module Output

using ..Domain
using CSV
using DataFrames

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

end
