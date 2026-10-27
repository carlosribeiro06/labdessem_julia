# Network reader: OPER_CARGA_BARRA.csv + OPER_LINHA.csv.

function parse_bool_flag(val)::Bool
    s = lowercase(strip(string(val)))
    s in ("true", "1") && return true
    s in ("false", "0") && return false
    throw(ArgumentError("Invalid boolean flag: $val"))
end

function read_buses(
    oper_path::String,
    horizon::LDCore.StudyHorizon
)::Vector{LDCore.Bus}
    df = read_csv(oper_path)
    
    for col in [:CodigoBarra, :NomeBarra, :Periodo, Symbol("Carga.mw"), :CodigoSubmercado, :Swing]
        hasproperty(df, col) || throw(ArgumentError("Missing column '$col' in $oper_path"))
    end
    
    bus_data = Dict{Int, NamedTuple{(:name, :submarket_id, :angle_reference, :demand_mw), 
                                     Tuple{String, Int, Bool, Vector{Float64}}}}()
    
    for row in eachrow(df)
        bus_id = row.CodigoBarra
        name = strip(string(row.NomeBarra))
        sbm_id = row.CodigoSubmercado
        swing = parse_bool_flag(row.Swing)
        
        if !haskey(bus_data, bus_id)
            bus_data[bus_id] = (name=name, submarket_id=sbm_id, angle_reference=swing, 
                               demand_mw=zeros(horizon.periods))
        else
            entry = bus_data[bus_id]
            entry.name != name && throw(ArgumentError(
                "Bus $bus_id has inconsistent name across periods"))
            entry.submarket_id != sbm_id && throw(ArgumentError(
                "Bus $bus_id has inconsistent submarket across periods"))
            entry.angle_reference != swing && throw(ArgumentError(
                "Bus $bus_id has inconsistent swing flag across periods"))
        end
        
        orig_period = row.Periodo
        (orig_period < 1 || orig_period > horizon.original_periods) && throw(ArgumentError(
            "Period $orig_period out of range in $oper_path"))
        
        carga = Float64(row[Symbol("Carga.mw")])
        for idx in internal_periods_for_original(horizon, orig_period)
            bus_data[bus_id].demand_mw[idx + 1] = carga
        end
    end
    
    sorted_ids = sort(collect(keys(bus_data)))
    [LDCore.Bus(
        id=BusId(id),
        name=bus_data[id].name,
        submarket_id=SubmarketId(bus_data[id].submarket_id),
        angle_reference=bus_data[id].angle_reference,
        demand_mw=bus_data[id].demand_mw
    ) for id in sorted_ids]
end

function read_branches(oper_path::String)::Vector{LDCore.Branch}
    df = read_csv(oper_path)
    
    for col in [:De, :Para, Symbol("Capacidade.mw"), Symbol("Reatancia.pu"), :CodigoLinha]
        hasproperty(df, col) || throw(ArgumentError("Missing column '$col' in $oper_path"))
    end
    
    result = LDCore.Branch[]
    for row in eachrow(df)
        branch = LDCore.Branch(
            id=BranchId(row.CodigoLinha),
            name="LINHA-$(row.CodigoLinha)",
            from_bus_id=BusId(row.De),
            to_bus_id=BusId(row.Para),
            reactance_pu=Float64(row[Symbol("Reatancia.pu")]),
            thermal_limit_mw=Float64(row[Symbol("Capacidade.mw")])
        )
        push!(result, branch)
    end
    
    sort!(result, by=b->b.id)
    result
end

function build_dummy_buses(
    submarkets::Vector{LDCore.Submarket},
    horizon::LDCore.StudyHorizon
)::Vector{LDCore.Bus}
    [LDCore.Bus(
        id=BusId(sbm.id),
        name="DUMMY-BUS-$(sbm.name)",
        submarket_id=SubmarketId(sbm.id),
        angle_reference=(sbm.id == 1),
        demand_mw=zeros(horizon.periods)
    ) for sbm in submarkets]
end
