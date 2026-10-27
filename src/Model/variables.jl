import ..Core as LDCore

function create_thermal_variables!(container, system::LDCore.System)
    isnothing(container.index_sets) && error("Index sets not attached. Call build_index_sets first.")
    
    sets = container.index_sets
    model = container.model
    config = container.config
    
    isempty(sets.thermal_indices) && return nothing
    
    plant_lookup = Dict(p.id => p for p in system.thermal_plants)
    
    @variable(model, thermal_gen[idx in sets.thermal_indices] >= 0)
    for idx in sets.thermal_indices
        plant_id, unit_id, _ = idx
        plant = plant_lookup[plant_id]
        unit = plant.units[findfirst(u -> u.id == unit_id, plant.units)]
        set_upper_bound(thermal_gen[idx], unit.max_generation_mw)
    end
    
    @variable(model, thermal_commit[idx in sets.thermal_indices])
    @variable(model, thermal_startup[idx in sets.thermal_indices] >= 0)
    @variable(model, thermal_shutdown[idx in sets.thermal_indices] >= 0)
    
    if config.thermal_uc_enabled
        for idx in sets.thermal_indices
            set_binary(thermal_commit[idx])
            set_binary(thermal_startup[idx])
            set_binary(thermal_shutdown[idx])
        end
    else
        for idx in sets.thermal_indices
            fix(thermal_commit[idx], 1.0; force=true)
            fix(thermal_startup[idx], 0.0; force=true)
            fix(thermal_shutdown[idx], 0.0; force=true)
        end
    end
    
    return nothing
end

function create_hydro_variables!(container, system::LDCore.System)
    isnothing(container.index_sets) && error("Index sets not attached. Call build_index_sets first.")
    
    sets = container.index_sets
    model = container.model
    config = container.config
    
    isempty(sets.hydro_indices) && isempty(sets.hydro_plant_periods) && return nothing
    
    plant_lookup = Dict(p.id => p for p in system.hydro_plants)
    
    if !isempty(sets.hydro_indices)
        @variable(model, hydro_gen[idx in sets.hydro_indices] >= 0)
        @variable(model, hydro_turb[idx in sets.hydro_indices] >= 0)
        
        for idx in sets.hydro_indices
            plant_id, group_id, unit_id, _ = idx
            plant = plant_lookup[plant_id]
            group = plant.groups[findfirst(g -> g.id == group_id, plant.groups)]
            unit = group.units[findfirst(u -> u.id == unit_id, group.units)]
            set_upper_bound(hydro_gen[idx], unit.max_generation_mw)
            set_upper_bound(hydro_turb[idx], unit.max_turbining_hm3)
        end
        
        @variable(model, hydro_commit[idx in sets.hydro_indices])
        if config.hydro_uc_enabled
            for idx in sets.hydro_indices
                set_binary(hydro_commit[idx])
            end
        else
            for idx in sets.hydro_indices
                fix(hydro_commit[idx], 1.0; force=true)
            end
        end
    end
    
    if !isempty(sets.hydro_plant_periods)
        @variable(model, hydro_spill[idx in sets.hydro_plant_periods] >= 0)
        @variable(model, hydro_volume[idx in sets.hydro_plant_periods])
        @variable(model, hydro_diversion[idx in sets.hydro_plant_periods] >= 0)
        
        for idx in sets.hydro_plant_periods
            plant_id, _ = idx
            plant = plant_lookup[plant_id]
            set_lower_bound(hydro_volume[idx], plant.reservoir.min_volume_hm3)
            set_upper_bound(hydro_volume[idx], plant.reservoir.max_volume_hm3)
            
            if isnothing(plant.diversion_plant_id)
                fix(hydro_diversion[idx], 0.0; force=true)
            end
        end
    end
    
    return nothing
end

function create_pumping_variables!(container, system::LDCore.System)
    isnothing(container.index_sets) && error("Index sets not attached. Call build_index_sets first.")
    
    sets = container.index_sets
    model = container.model
    
    isempty(sets.pumping_indices) && return nothing
    
    plant_lookup = Dict(p.id => p for p in system.pumping_plants)
    
    @variable(model, pumping[idx in sets.pumping_indices])
    
    for idx in sets.pumping_indices
        plant_id, _ = idx
        plant = plant_lookup[plant_id]
        set_lower_bound(pumping[idx], plant.min_pumping_hm3)
        set_upper_bound(pumping[idx], plant.max_pumping_hm3)
    end
    
    return nothing
end

function create_renewable_variables!(container, system::LDCore.System)
    isnothing(container.index_sets) && error("Index sets not attached. Call build_index_sets first.")
    
    sets = container.index_sets
    model = container.model
    
    isempty(sets.renewable_indices) && return nothing
    
    plant_lookup = Dict(p.id => p for p in system.renewable_plants)
    
    @variable(model, renewable_gen[idx in sets.renewable_indices] >= 0)
    
    for idx in sets.renewable_indices
        plant_id, period = idx
        plant = plant_lookup[plant_id]
        avail = plant.available_generation_mw[period]
        set_upper_bound(renewable_gen[idx], avail)
    end
    
    return nothing
end

function create_interchange_variables!(container, system::LDCore.System)
    isnothing(container.index_sets) && error("Index sets not attached. Call build_index_sets first.")
    
    sets = container.index_sets
    model = container.model
    
    isempty(sets.interchange_indices) && return nothing
    
    limits = Dict{Tuple{Int,Int}, Float64}()
    for lim in system.interchange_limits
        limits[(lim.from_submarket_id, lim.to_submarket_id)] = lim.max_flow_mw
    end
    
    @variable(model, interchange[idx in sets.interchange_indices] >= 0)
    
    for idx in sets.interchange_indices
        from_sub, to_sub, _ = idx
        limit = get(limits, (from_sub, to_sub), 0.0)
        set_upper_bound(interchange[idx], limit)
    end
    
    return nothing
end

function create_system_variables!(container, system::LDCore.System)
    isnothing(container.index_sets) && error("Index sets not attached. Call build_index_sets first.")
    
    model = container.model
    sets = container.index_sets
    
    if system.future_cost_enabled
        @variable(model, future_cost >= 0)
    end
    
    if !isempty(sets.submarket_periods)
        @variable(model, deficit[idx in sets.submarket_periods] >= 0)
    end
    
    return nothing
end
