# Common utilities for IO operations.

const SECONDS_PER_HOUR = 3600.0
const M3_PER_HM3 = 1_000_000.0
const BOUND_TOLERANCE = 1e-2

function read_csv(path::String; delim::Char=';', kwargs...)
    !isfile(path) && throw(ArgumentError("CSV file not found: $path"))
    try
        CSV.read(path, DataFrame; delim=delim, missingstring=["-", ""], stringtype=String, kwargs...)
    catch e
        throw(ArgumentError("Failed to read CSV '$path': $(sprint(showerror, e))"))
    end
end

function flow_m3s_to_hm3(flow_m3s::Float64, duration_hours::Float64)::Float64
    duration_hours == 0.0 && return 0.0
    flow_m3s * duration_hours * SECONDS_PER_HOUR / M3_PER_HM3
end

function hm3_to_flow_m3s(volume_hm3::Float64, duration_hours::Float64)::Float64
    duration_hours == 0.0 && throw(ArgumentError("Cannot convert to flow with zero duration"))
    volume_hm3 * M3_PER_HM3 / (duration_hours * SECONDS_PER_HOUR)
end

function submarket_id_by_name(submarkets::Vector{LDCore.Submarket}, name::String)::SubmarketId
    name_stripped = strip(name)
    for sbm in submarkets
        strip(sbm.name) == name_stripped && return sbm.id
    end
    throw(KeyError("Submarket '$name_stripped' not found in $(length(submarkets)) submarkets"))
end

function hours_to_periods(hours::Float64, period_duration_hours::Float64)::Int
    hours < 0.0 && throw(ArgumentError("hours_to_periods: hours must be non-negative, got $hours"))
    period_duration_hours <= 0.0 && throw(ArgumentError("hours_to_periods: period duration must be positive, got $period_duration_hours"))
    ceil(Int, hours / period_duration_hours)
end

function normalize_max_bound(min_val::Float64, max_val::Float64, field_name::AbstractString, asset_name::AbstractString)::Float64
    max_val >= min_val && return max_val
    abs(max_val - min_val) <= BOUND_TOLERANCE && return min_val
    throw(ArgumentError("$field_name for '$asset_name': max ($max_val) < min ($min_val) beyond tolerance"))
end
