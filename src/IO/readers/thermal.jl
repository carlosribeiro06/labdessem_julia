# Thermal plant reader: CAD_UNID_UTE.csv + CAD_RAMPAS_TERMICAS.csv.

function read_thermal_plants(
    cad_path::String,
    ramp_path::String,
    horizon::LDCore.StudyHorizon,
    submarkets::Vector{LDCore.Submarket},
    uct_enabled::Bool,
    network_enabled::Bool
)::Vector{LDCore.ThermalPlant}
    units_df = read_csv(cad_path)
    
    startup_traj = Dict{String, Vector{Float64}}()
    shutdown_traj = Dict{String, Vector{Float64}}()
    
    if uct_enabled && isfile(ramp_path)
        ramps_df = read_csv(ramp_path)
        
        ipasso_col = if hasproperty(ramps_df, :Ipasso)
            :Ipasso
        elseif hasproperty(ramps_df, Symbol(" Ipasso"))
            Symbol(" Ipasso")
        else
            throw(ArgumentError("Missing column 'Ipasso' in $ramp_path"))
        end
        
        startup_steps = Dict{String, Vector{Tuple{Int,Float64}}}()
        shutdown_steps = Dict{String, Vector{Tuple{Int,Float64}}}()
        
        for row in eachrow(ramps_df)
            key = "$(strip(string(row.NomeUTE)))-$(row.Unidade)"
            step = (row[ipasso_col], row[Symbol("Passo.mw")])
            traj_type = uppercase(strip(string(row.Traj)))
            if traj_type == "A"
                push!(get!(startup_steps, key, Tuple{Int,Float64}[]), step)
            else
                push!(get!(shutdown_steps, key, Tuple{Int,Float64}[]), step)
            end
        end
        
        for (k, steps) in startup_steps
            sort!(steps, by=first)
            startup_traj[k] = [s[2] for s in steps]
        end
        for (k, steps) in shutdown_steps
            sort!(steps, by=first)
            shutdown_traj[k] = [s[2] for s in steps]
        end
    end
    
    plants_dict = Dict{Int, Vector{LDCore.ThermalUnit}}()
    plant_meta = Dict{Int, NamedTuple{(:name,:submarket_id,:bus_id), Tuple{String,SubmarketId,BusId}}}()
    
    for row in eachrow(units_df)
        plant_code = row.CodigoUTE
        unit_id = row.Unidade
        plant_name = strip(string(row.NomeUTE))
        sbm_id = submarket_id_by_name(submarkets, string(row.Submercado))
        bus_id = network_enabled ? BusId(row.Barra) : BusId(sbm_id)
        
        key = "$plant_name-$unit_id"
        startup = get(startup_traj, key, Float64[])
        shutdown = get(shutdown_traj, key, Float64[])
        
        pmin = Float64(row[Symbol("Pmin.mw")])
        pmax = Float64(row[Symbol("Pmax.mw")])
        max_gen = normalize_max_bound(pmin, pmax, "Pmax", key)
        
        initial_cond = if uct_enabled
            LDCore.ThermalInitialCondition(
                is_on = row.StatusInic != 0,
                generation_mw = row[Symbol("GerInic.mw")],
                time_in_state = hours_to_periods(Float64(row[Symbol("Tinic.h")]), horizon.period_duration_hours),
                time_in_ramp = hours_to_periods(Float64(row[Symbol("TRampaInic.h")]), horizon.period_duration_hours),
                is_ramping_up = row.RupInic != 0,
                is_ramping_down = row.RdownInic != 0
            )
        else
            LDCore.ThermalInitialCondition(
                is_on = false,
                generation_mw = 0.0,
                time_in_state = 0,
                time_in_ramp = 0,
                is_ramping_up = false,
                is_ramping_down = false
            )
        end
        
        unit = LDCore.ThermalUnit(
            id = ThermalUnitId(unit_id),
            name = key,
            min_generation_mw = pmin,
            max_generation_mw = max_gen,
            startup_trajectory_mw = startup,
            shutdown_trajectory_mw = shutdown,
            min_up_time = hours_to_periods(Float64(row[Symbol("Ton.h")]), horizon.period_duration_hours),
            min_down_time = hours_to_periods(Float64(row[Symbol("Toff.h")]), horizon.period_duration_hours),
            startup_cost = row[Symbol("CustoPartida.R\$")],
            shutdown_cost = row[Symbol("CustoDesliga.R\$")],
            variable_cost_per_mwh = row[Symbol("CVU.R\$/MWh")],
            initial_condition = initial_cond
        )
        
        if !haskey(plants_dict, plant_code)
            plants_dict[plant_code] = LDCore.ThermalUnit[]
            plant_meta[plant_code] = (name=plant_name, submarket_id=sbm_id, bus_id=bus_id)
        end
        push!(plants_dict[plant_code], unit)
    end
    
    sorted_codes = sort(collect(keys(plants_dict)))
    [LDCore.ThermalPlant(
        id = ThermalPlantId(code),
        name = plant_meta[code].name,
        submarket_id = plant_meta[code].submarket_id,
        bus_id = plant_meta[code].bus_id,
        units = plants_dict[code]
    ) for code in sorted_codes]
end
