# Limits reader: interchange, residual costs, operational limits.

function read_interchange_limits(oper_path::String)::Vector{LDCore.InterchangeLimit}
    !isfile(oper_path) && return LDCore.InterchangeLimit[]
    df = read_csv(oper_path)
    nrow(df) == 0 && return LDCore.InterchangeLimit[]
    
    result = LDCore.InterchangeLimit[]
    for row in eachrow(df)
        limit = LDCore.InterchangeLimit(
            from_submarket_id=SubmarketId(row.SbmDe),
            to_submarket_id=SubmarketId(row.SbmPara),
            max_flow_mw=Float64(row[Symbol("Limite.mw")]),
            penalty_cost_per_mwh=Float64(row[Symbol("Penalidade.R\$/MWh")])
        )
        push!(result, limit)
    end
    result
end

function read_residual_costs(oper_path::String, enabled::Bool)::Vector{LDCore.ResidualCost}
    !enabled && return LDCore.ResidualCost[]
    !isfile(oper_path) && return LDCore.ResidualCost[]
    df = read_csv(oper_path)
    nrow(df) == 0 && return LDCore.ResidualCost[]
    
    result = LDCore.ResidualCost[]
    for row in eachrow(df)
        cost = LDCore.ResidualCost(
            submarket_id=SubmarketId(row.Submercado),
            cmo_per_mwh=Float64(row[Symbol("CMO.R\$/MWh")])
        )
        push!(result, cost)
    end
    result
end

function parse_operational_limit_variable(val::AbstractString)::LDCore.OperationalLimitVariable
    s = uppercase(strip(string(val)))
    s == "GER" && return LDCore.Generation
    s == "VERT" && return LDCore.Spillage
    s == "VOL" && return LDCore.Volume
    s == "DEFLU" && return LDCore.Defluence
    s == "TURB" && return LDCore.Turbining
    s == "QDES" && return LDCore.Diversion
    s == "QBOM" && return LDCore.Pumping
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
    thermal_plants::Vector{LDCore.ThermalPlant},
    hydro_plants::Vector{LDCore.HydroPlant},
    pumping_plants::Vector{LDCore.PumpingPlant},
    horizon::LDCore.StudyHorizon
)::Vector{LDCore.OperationalLimit}
    !isfile(oper_path) && return LDCore.OperationalLimit[]
    df = read_csv(oper_path)
    nrow(df) == 0 && return LDCore.OperationalLimit[]
    
    thermal_by_id = Dict{Int, LDCore.ThermalPlant}(p.id => p for p in thermal_plants)
    hydro_by_id = Dict{Int, LDCore.HydroPlant}(p.id => p for p in hydro_plants)
    pumping_by_id = Dict{Int, LDCore.PumpingPlant}(p.id => p for p in pumping_plants)
    
    result = LDCore.OperationalLimit[]
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
        
        target = if variable == LDCore.Generation
            if thermal_match !== nothing && hydro_match === nothing
                LDCore.ThermalPlantTarget(ThermalPlantId(codigo))
            elseif thermal_match === nothing && hydro_match !== nothing
                LDCore.HydroPlantTarget(HydroPlantId(codigo))
            elseif thermal_match !== nothing && hydro_match !== nothing
                throw(ArgumentError("Ambiguous generation limit for $plant_name"))
            else
                throw(ArgumentError("Unknown plant $plant_name ($codigo) in OPER_REST_LIM"))
            end
        elseif variable == LDCore.Pumping
            pumping_match === nothing && throw(ArgumentError(
                "Unknown pumping plant $plant_name ($codigo) in OPER_REST_LIM"))
            LDCore.PumpingPlantTarget(PumpingPlantId(codigo))
        else
            hydro_match === nothing && throw(ArgumentError(
                "Unknown hydro plant $plant_name ($codigo) for variable $variable"))
            LDCore.HydroPlantTarget(HydroPlantId(codigo))
        end
        
        limit = LDCore.OperationalLimit(
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
