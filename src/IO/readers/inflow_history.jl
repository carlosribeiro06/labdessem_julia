# Inflow history reader: parquet file.
#
# Reads inflow_history.parquet with columns: hydro_id, start_date, end_date, value_m3s

using Dates

function read_inflow_history(oper_path::String)::Vector{LDCore.InflowHistoryRow}
    !isfile(oper_path) && return LDCore.InflowHistoryRow[]
    
    ds = Parquet2.Dataset(oper_path)
    df = DataFrame(ds; copycols=false)
    
    nrow(df) == 0 && return LDCore.InflowHistoryRow[]
    
    for col in [:hydro_id, :start_date, :value_m3s]
        hasproperty(df, col) || throw(ArgumentError("Missing column '$col' in $oper_path"))
    end
    
    rows = LDCore.InflowHistoryRow[]
    for row in eachrow(df)
        hydro_id = row.hydro_id
        start_date = row.start_date
        value_m3s = Float64(row.value_m3s)
        
        !isfinite(value_m3s) && throw(ArgumentError(
            "Non-finite value_m3s for hydro $hydro_id in $oper_path"))
        
        year = Dates.year(start_date)
        month = Dates.month(start_date)
        
        # Convert m3/s to hm3 assuming monthly average over ~30 days
        # This is a placeholder conversion - actual conversion depends on period duration
        inflow_hm3 = value_m3s * 30.0 * 24.0 * 3600.0 / 1_000_000.0
        
        push!(rows, LDCore.InflowHistoryRow(
            plant_id=HydroPlantId(hydro_id),
            year=year,
            month=month,
            inflow_hm3=inflow_hm3
        ))
    end
    
    sort!(rows, by=r->(r.plant_id, r.year, r.month))
    rows
end
