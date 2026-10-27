# Hydro plant reader: CAD_UHE.csv + CAD_CONJ_UHE.csv + OPER_VAZAO.csv + OPER_FPHA.csv.

function parse_plant_ref(val, valid_codes::Set{Int})::Union{HydroPlantId, Nothing}
    ismissing(val) && return nothing
    s = strip(string(val))
    (s == "-" || s == "" || s == "-1" || s == "missing") && return nothing
    code = tryparse(Int, s)
    code === nothing && throw(ArgumentError("Invalid plant reference: $s"))
    code in valid_codes || return nothing
    HydroPlantId(code)
end

function parse_turbine_type(val)::LDCore.TurbineType
    v = tryparse(Int, string(val))
    v === nothing && return LDCore.Unknown
    v == 1 && return LDCore.Francis
    v == 2 && return LDCore.Kaplan
    LDCore.Unknown
end

function read_hydro_plants(
    cad_path::String,
    conj_path::String,
    vazao_path::String,
    fpha_path::Union{String,Nothing},
    horizon::LDCore.StudyHorizon,
    submarkets::Vector{LDCore.Submarket},
    fpha_enabled::Bool,
    network_enabled::Bool
)::Vector{LDCore.HydroPlant}
    plants_df = read_csv(cad_path)
    conj_df = read_csv(conj_path)
    vazao_df = read_csv(vazao_path)
    fpha_df = (fpha_enabled && fpha_path !== nothing && isfile(fpha_path)) ? read_csv(fpha_path) : nothing
    
    plant_codes = Set{Int}()
    for row in eachrow(plants_df)
        push!(plant_codes, row.Codigo)
    end
    
    downstream_map = Dict{Int, Union{HydroPlantId, Nothing}}()
    diversion_map = Dict{Int, Union{HydroPlantId, Nothing}}()
    for row in eachrow(plants_df)
        downstream_map[row.Codigo] = parse_plant_ref(row.Jusante, plant_codes)
        diversion_map[row.Codigo] = parse_plant_ref(row.Desvio, plant_codes)
    end
    
    upstream_map = Dict{Int, Vector{HydroPlantId}}(c => HydroPlantId[] for c in plant_codes)
    div_upstream_map = Dict{Int, Vector{HydroPlantId}}(c => HydroPlantId[] for c in plant_codes)
    for (code, downstream) in downstream_map
        downstream !== nothing && push!(upstream_map[downstream], HydroPlantId(code))
    end
    for (code, diversion) in diversion_map
        diversion !== nothing && push!(div_upstream_map[diversion], HydroPlantId(code))
    end
    
    inflow_map = Dict{Int, Vector{Float64}}()
    withdrawal_map = Dict{Int, Vector{Float64}}()
    for code in plant_codes
        inflow_map[code] = zeros(horizon.periods)
        withdrawal_map[code] = zeros(horizon.periods)
    end
    for row in eachrow(vazao_df)
        code = row.Codigo
        haskey(inflow_map, code) || continue
        orig_period = row.Periodo
        (orig_period < 1 || orig_period > horizon.original_periods) && continue
        for idx in internal_periods_for_original(horizon, orig_period)
            inflow_map[code][idx+1] = flow_m3s_to_hm3(Float64(row[Symbol("Afluencia.m3/s")]), horizon.period_duration_hours)
            withdrawal_map[code][idx+1] = flow_m3s_to_hm3(Float64(row[Symbol("Retirada.m3/s")]), horizon.period_duration_hours)
        end
    end
    
    fpha_map = Dict{Int, Vector{LDCore.HydroFphaSegment}}()
    if fpha_df !== nothing
        for row in eachrow(fpha_df)
            code = row.USIH
            seg = LDCore.HydroFphaSegment(
                segment=row.SegFPHA,
                correction_factor=row.Fcorrec,
                rhs=Float64(row[Symbol("Rhs.MW")]),
                volume_coefficient=Float64(row[Symbol("Varm.MW/hm3")]),
                turbining_coefficient=Float64(row[Symbol("Qtur.MW/m3s")]),
                lateral_flow_coefficient=Float64(row[Symbol("Qlat.MW/m3s")])
            )
            push!(get!(fpha_map, code, LDCore.HydroFphaSegment[]), seg)
        end
    end
    
    groups_map = Dict{Int, Vector{LDCore.HydroGroup}}()
    bus_map = Dict{Int, BusId}()
    
    for row in eachrow(conj_df)
        code = row.Codigo
        group_id = row.Conjunto
        n_units = row.Unidades
        plant_name = strip(string(row.Nome))
        
        pmin = Float64(row[Symbol("Pmin.mw")])
        pmax = Float64(row[Symbol("Pmax.mw")])
        max_gen = normalize_max_bound(pmin, pmax, "Pmax", "$plant_name-$group_id")
        max_turb_hm3 = flow_m3s_to_hm3(Float64(row[Symbol("MaxTurb.m3/s")]), horizon.period_duration_hours)
        hef = Float64(row[Symbol("Hef.m")])
        tinic = hours_to_periods(Float64(row[Symbol("Tinic.h")]), horizon.period_duration_hours)
        is_on = row.StatusInic != 0
        
        units = [LDCore.HydroUnit(
            id=HydroUnitId(u),
            name="$plant_name-$group_id-$u",
            min_generation_mw=pmin,
            max_generation_mw=max_gen,
            max_turbining_hm3=max_turb_hm3,
            effective_head_m=hef,
            initial_condition=LDCore.HydroInitialCondition(
                is_on=is_on,
                generation_mw=is_on ? pmin : 0.0,
                time_in_state=tinic
            )
        ) for u in 1:n_units]
        
        group = LDCore.HydroGroup(id=HydroGroupId(group_id), name="$plant_name-$group_id", units=units)
        push!(get!(groups_map, code, LDCore.HydroGroup[]), group)
        
        if !haskey(bus_map, code)
            bus_map[code] = network_enabled ? BusId(row.Barra) : BusId(0)
        end
    end
    
    result = LDCore.HydroPlant[]
    for row in eachrow(plants_df)
        code = row.Codigo
        name = strip(string(row.Nome))
        sbm_id = submarket_id_by_name(submarkets, string(row.Submercado))
        
        groups = get(groups_map, code, LDCore.HydroGroup[])
        bus_id = network_enabled ? get(bus_map, code, BusId(sbm_id)) : BusId(sbm_id)
        
        turbine = parse_turbine_type(row.Turbina)
        
        vmin = Float64(row[Symbol("Vmin.hm3")])
        vmax = Float64(row[Symbol("Vmax.hm3")])
        vmax_norm = normalize_max_bound(vmin, vmax, "Vmax", name)
        
        loss_col = Symbol("Perda.m")
        eff_col = Symbol("Eficiencia")
        loss = hasproperty(plants_df, loss_col) && !ismissing(row[loss_col]) ? Float64(row[loss_col]) : nothing
        eff = hasproperty(plants_df, eff_col) && !ismissing(row[eff_col]) ? Float64(row[eff_col]) : nothing
        
        plant = LDCore.HydroPlant(
            id=HydroPlantId(code),
            name=name,
            submarket_id=sbm_id,
            bus_id=bus_id,
            upstream_plant_ids=upstream_map[code],
            downstream_plant_id=downstream_map[code],
            diversion_upstream_plant_ids=div_upstream_map[code],
            diversion_plant_id=diversion_map[code],
            reservoir=LDCore.Reservoir(
                min_volume_hm3=vmin,
                max_volume_hm3=vmax_norm,
                initial_volume_hm3=Float64(row[Symbol("VolInic.hm3")])
            ),
            natural_inflow_hm3=inflow_map[code],
            water_withdrawal_hm3=withdrawal_map[code],
            spillage_cost_per_hm3=Float64(row[Symbol("PenalVert.R\$/hm3")]),
            turbining_cost_per_hm3=Float64(row[Symbol("PenalTurb.R\$/hm3")]),
            specific_productivity_mw_per_m3s=Float64(row[Symbol("Prod.mw/m3s")]),
            hydraulic_loss_m=loss,
            efficiency=eff,
            fpha_segments=get(fpha_map, code, LDCore.HydroFphaSegment[]),
            groups=groups,
            turbine_type=turbine,
            volume_level_table=nothing,
            tailrace_coefficients=nothing
        )
        push!(result, plant)
    end
    
    sort!(result, by=p->p.id)
    result
end
