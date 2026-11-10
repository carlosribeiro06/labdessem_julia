# Limits reader: interchange, residual costs, operational limits.

function read_interchange_limits(oper_path::String)::Vector{Domain.InterchangeLimit}
    !isfile(oper_path) && return Domain.InterchangeLimit[]
    df = read_csv(oper_path)
    nrow(df) == 0 && return Domain.InterchangeLimit[]
    
    result = Domain.InterchangeLimit[]
    for row in eachrow(df)
        limit = Domain.InterchangeLimit(
            from_submarket_id=SubmarketId(row.SbmDe),
            to_submarket_id=SubmarketId(row.SbmPara),
            max_flow_mw=Float64(row[Symbol("Limite.mw")]),
            penalty_cost_per_mwh=Float64(row[Symbol("Penalidade.R\$/MWh")])
        )
        push!(result, limit)
    end
    result
end

function read_residual_costs(oper_path::String, enabled::Bool)::Vector{Domain.ResidualCost}
    !enabled && return Domain.ResidualCost[]
    !isfile(oper_path) && return Domain.ResidualCost[]
    df = read_csv(oper_path)
    nrow(df) == 0 && return Domain.ResidualCost[]
    
    result = Domain.ResidualCost[]
    for row in eachrow(df)
        cost = Domain.ResidualCost(
            submarket_id=SubmarketId(row.Submercado),
            cmo_per_mwh=Float64(row[Symbol("CMO.R\$/MWh")])
        )
        push!(result, cost)
    end
    result
end

function parse_operational_limit_variable(val::AbstractString)::Domain.OperationalLimitVariable
    s = uppercase(strip(string(val)))
    s == "GER" && return Domain.Generation
    s == "VERT" && return Domain.Spillage
    s == "VOL" && return Domain.Volume
    s == "DEFLU" && return Domain.Defluence
    s == "TURB" && return Domain.Turbining
    s == "QDES" && return Domain.Diversion
    s == "QBOM" && return Domain.Pumping
    throw(ArgumentError("Unknown operational limit variable: $val"))
end

function parse_restriction_period(val::AbstractString, horizon_periods::Int, is_start::Bool)::Int
    s = strip(string(val))
    uppercase(s) == "I" && return 1
    uppercase(s) == "F" && return horizon_periods
    period = tryparse(Int, s)
    period === nothing && throw(ArgumentError("Invalid restriction period: $val"))
    (period < 1 || period > horizon_periods) && throw(ArgumentError(
        "Restriction $(is_start ? "initial" : "final") period $period outside horizon 1..$horizon_periods"))
    period
end

function parse_optional_bound(val)::Union{Float64, Nothing}
    ismissing(val) && return nothing
    s = strip(string(val))
    (s == "" || s == "-") && return nothing
    parsed = tryparse(Float64, s)
    parsed === nothing && throw(ArgumentError("Invalid bound value: $val"))
    parsed
end

function read_operational_limits(
    oper_path::String,
    thermal_plants::Vector{Domain.ThermalPlant},
    hydro_plants::Vector{Domain.HydroPlant},
    pumping_plants::Vector{Domain.PumpingPlant},
    horizon::Domain.StudyHorizon
)::Vector{Domain.OperationalLimit}
    !isfile(oper_path) && return Domain.OperationalLimit[]
    df = read_csv(oper_path)
    nrow(df) == 0 && return Domain.OperationalLimit[]
    
    thermal_by_id = Dict{Int, Domain.ThermalPlant}(p.id => p for p in thermal_plants)
    hydro_by_id = Dict{Int, Domain.HydroPlant}(p.id => p for p in hydro_plants)
    pumping_by_id = Dict{Int, Domain.PumpingPlant}(p.id => p for p in pumping_plants)
    
    result = Domain.OperationalLimit[]
    for row in eachrow(df)
        start_orig = parse_restriction_period(row.PeriodoInicial, horizon.original_periods, true)
        end_orig = parse_restriction_period(row.PeriodoFinal, horizon.original_periods, false)
        
        start_orig > end_orig && throw(ArgumentError(
            "Operational limit for $(row.NomeUsina) has start > end period"))
        
        start_internal = internal_periods_for_original(horizon, start_orig)
        end_internal = internal_periods_for_original(horizon, end_orig)
        
        start_period = first(start_internal) + 1
        end_period = last(end_internal) + 1
        
        variable = parse_operational_limit_variable(row.Variavel)
        lower_bound = parse_optional_bound(row.Linf)
        upper_bound = parse_optional_bound(row.Lsup)
        
        codigo = row.CodigoUsina
        plant_name = strip(string(row.NomeUsina))
        
        thermal_match = get(thermal_by_id, codigo, nothing)
        hydro_match = get(hydro_by_id, codigo, nothing)
        pumping_match = get(pumping_by_id, codigo, nothing)
        
        target = if variable == Domain.Generation
            if thermal_match !== nothing && hydro_match === nothing
                Domain.ThermalPlantTarget(ThermalPlantId(codigo))
            elseif thermal_match === nothing && hydro_match !== nothing
                Domain.HydroPlantTarget(HydroPlantId(codigo))
            elseif thermal_match !== nothing && hydro_match !== nothing
                throw(ArgumentError("Ambiguous generation limit for $plant_name"))
            else
                throw(ArgumentError("Unknown plant $plant_name ($codigo) in OPER_REST_LIM"))
            end
        elseif variable == Domain.Pumping
            pumping_match === nothing && throw(ArgumentError(
                "Unknown pumping plant $plant_name ($codigo) in OPER_REST_LIM"))
            Domain.PumpingPlantTarget(PumpingPlantId(codigo))
        else
            hydro_match === nothing && throw(ArgumentError(
                "Unknown hydro plant $plant_name ($codigo) for variable $variable"))
            Domain.HydroPlantTarget(HydroPlantId(codigo))
        end
        
        limit = Domain.OperationalLimit(
            target=target,
            plant_name=plant_name,
            variable=variable,
            start_period=start_period,
            end_period=end_period,
            lower_bound=lower_bound,
            upper_bound=upper_bound
        )
        push!(result, limit)
    end
    result
end
