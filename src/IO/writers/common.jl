# Common utilities for writers.

function write_csv(path::String, df::DataFrame; delim::Char=';')
    dir = dirname(path)
    !isempty(dir) && !isdir(dir) && mkpath(dir)
    CSV.write(path, df; delim=delim)
end

function operational_limit_variable_label(variable::LDCore.OperationalLimitVariable)::String
    variable == LDCore.Generation && return "GER"
    variable == LDCore.Spillage && return "VERT"
    variable == LDCore.Volume && return "VOL"
    variable == LDCore.Defluence && return "DEFLU"
    variable == LDCore.Turbining && return "TURB"
    variable == LDCore.Diversion && return "QDES"
    variable == LDCore.Pumping && return "QBOM"
    "UNKNOWN"
end

function original_period_for_internal(horizon::LDCore.StudyHorizon, internal_period::Int)::Int
    horizon.internal_to_original_period[internal_period]
end

function original_period_duration_hours(horizon::LDCore.StudyHorizon, original_period::Int)::Float64
    horizon.original_period_durations_hours[original_period]
end

function average_internal_values(
    horizon::LDCore.StudyHorizon,
    periods::Vector{Int},
    values::Function
)::Float64
    weighted_sum = 0.0
    total_duration = 0.0
    
    for period in periods
        original = horizon.internal_to_original_period[period]
        duration = horizon.original_period_durations_hours[original]
        weighted_sum += values(period) * duration
        total_duration += duration
    end
    
    abs(total_duration) < 1e-12 && return 0.0
    weighted_sum / total_duration
end

function sum_internal_values(periods::Vector{Int}, values::Function)::Float64
    sum(values(p) for p in periods)
end

function thermal_residence_times(
    initial_is_on::Bool,
    initial_time_in_state::Int,
    statuses::Vector{Bool}
)::Tuple{Vector{Int}, Vector{Int}}
    times_on = Int[]
    times_off = Int[]
    previous_status = initial_is_on
    current_residence = initial_time_in_state
    
    for status in statuses
        if status == previous_status
            current_residence += 1
        else
            current_residence = 1
            previous_status = status
        end
        
        if status
            push!(times_on, current_residence)
            push!(times_off, 0)
        else
            push!(times_on, 0)
            push!(times_off, current_residence)
        end
    end
    
    (times_on, times_off)
end
