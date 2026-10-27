# Horizon reader: OPER_DURACAO.csv.

const INTERNAL_PERIOD_DURATION_HOURS = 0.5

function read_horizon(path::String)::LDCore.StudyHorizon
    df = read_csv(path)
    
    for col in [:Periodo, Symbol("Duracao.h")]
        hasproperty(df, col) || throw(ArgumentError("Missing column '$col' in $path"))
    end
    
    n_original = nrow(df)
    sort!(df, :Periodo)
    
    seen_periods = Set{Int}()
    original_durations = Float64[]
    internal_to_original = Int[]
    internal_subperiod_idx = Int[]
    
    for row in eachrow(df)
        orig = row.Periodo
        orig > 0 || throw(ArgumentError("Invalid period $orig in $path"))
        orig in seen_periods && throw(ArgumentError("Duplicate period $orig in $path"))
        push!(seen_periods, orig)
        
        dur = row[Symbol("Duracao.h")]
        dur > 0 || throw(ArgumentError("Non-positive duration $dur for period $orig in $path"))
        
        subperiods = dur / INTERNAL_PERIOD_DURATION_HOURS
        rounded = round(Int, subperiods)
        abs(subperiods - rounded) > 1e-8 && throw(ArgumentError(
            "Duration $dur for period $orig must be multiple of $INTERNAL_PERIOD_DURATION_HOURS in $path"))
        
        push!(original_durations, dur)
        for sub in 1:rounded
            push!(internal_to_original, orig)
            push!(internal_subperiod_idx, sub)
        end
    end
    
    LDCore.StudyHorizon(
        periods=length(internal_to_original),
        period_duration_hours=INTERNAL_PERIOD_DURATION_HOURS,
        original_periods=n_original,
        original_period_durations_hours=original_durations,
        internal_to_original_period=internal_to_original,
        internal_subperiod_index=internal_subperiod_idx
    )
end

function internal_periods_for_original(horizon::LDCore.StudyHorizon, original::Int)::Vector{Int}
    [i-1 for (i, o) in enumerate(horizon.internal_to_original_period) if o == original]
end
