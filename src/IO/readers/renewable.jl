# Renewable plant reader: CAD_REN.csv + OPER_REN.csv.

function read_renewable_plants(
    cad_path::String,
    oper_path::String,
    submarkets::Vector{LDCore.Submarket},
    horizon::LDCore.StudyHorizon,
    network_enabled::Bool
)::Vector{LDCore.RenewablePlant}
    cad_df = read_csv(cad_path)
    oper_df = read_csv(oper_path)
    
    nrow(cad_df) == 0 && return LDCore.RenewablePlant[]
    
    generation_by_plant = Dict{Int, Vector{Float64}}()
    
    for row in eachrow(oper_df)
        codigo = row.Codigo
        if !haskey(generation_by_plant, codigo)
            generation_by_plant[codigo] = zeros(horizon.periods)
        end
        
        orig_period = row.Periodo
        (orig_period < 1 || orig_period > horizon.original_periods) && continue
        
        ger_prog = Float64(row[Symbol("GerProg.mw")])
        for idx in internal_periods_for_original(horizon, orig_period)
            generation_by_plant[codigo][idx + 1] = ger_prog
        end
    end
    
    result = LDCore.RenewablePlant[]
    for row in eachrow(cad_df)
        codigo = row.Codigo
        name = strip(string(row.Nome))
        
        sbm_id = submarket_id_by_name(submarkets, string(row.Submercado))
        
        bus_id = if network_enabled && hasproperty(cad_df, :Barra) && !ismissing(row.Barra)
            barra_str = strip(string(row.Barra))
            if barra_str == "-" || barra_str == ""
                BusId(sbm_id)
            else
                BusId(parse(Int, barra_str))
            end
        else
            BusId(sbm_id)
        end
        
        avail_gen = get(generation_by_plant, codigo, zeros(horizon.periods))
        
        plant = LDCore.RenewablePlant(
            id=RenewablePlantId(codigo),
            name=name,
            submarket_id=SubmarketId(sbm_id),
            bus_id=bus_id,
            available_generation_mw=avail_gen
        )
        push!(result, plant)
    end
    
    sort!(result, by=p->p.id)
    result
end
