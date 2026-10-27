# Pumping plant reader: CAD_USIE.csv.

function read_pumping_plants(
    cad_path::String,
    hydro_plants::Vector{LDCore.HydroPlant},
    submarkets::Vector{LDCore.Submarket},
    period_duration_hours::Float64,
    network_enabled::Bool
)::Vector{LDCore.PumpingPlant}
    df = read_csv(cad_path)
    
    nrow(df) == 0 && return LDCore.PumpingPlant[]
    
    hydro_by_id = Dict{Int, LDCore.HydroPlant}(p.id => p for p in hydro_plants)
    
    result = LDCore.PumpingPlant[]
    for row in eachrow(df)
        codigo = row.Codigo
        name = strip(string(row.Nome))
        
        sbm_id = submarket_id_by_name(submarkets, string(row.Submercado))
        
        downstream_id = row.Jusante
        haskey(hydro_by_id, downstream_id) || throw(ArgumentError(
            "Pumping plant $name references unknown downstream hydro plant $downstream_id"))
        
        upstream_id = row.Montante
        haskey(hydro_by_id, upstream_id) || throw(ArgumentError(
            "Pumping plant $name references unknown upstream hydro plant $upstream_id"))
        
        bus_id = if network_enabled && hasproperty(df, :Barra) && !ismissing(row.Barra)
            BusId(row.Barra)
        else
            BusId(sbm_id)
        end
        
        qmin_col = Symbol("QbombMin.m3/s")
        qmax_col = Symbol("QbombMax.m3/s")
        consumo_col = Symbol("Consumo.mw/m3s")
        
        plant = LDCore.PumpingPlant(
            id=PumpingPlantId(codigo),
            name=name,
            submarket_id=SubmarketId(sbm_id),
            bus_id=bus_id,
            downstream_hydro_id=HydroPlantId(downstream_id),
            upstream_hydro_id=HydroPlantId(upstream_id),
            min_pumping_hm3=flow_m3s_to_hm3(Float64(row[qmin_col]), period_duration_hours),
            max_pumping_hm3=flow_m3s_to_hm3(Float64(row[qmax_col]), period_duration_hours),
            specific_consumption_mw_per_m3s=Float64(row[consumo_col])
        )
        push!(result, plant)
    end
    
    sort!(result, by=p->p.id)
    result
end
