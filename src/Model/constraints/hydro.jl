import ..Core as LDCore

function add_hydraulic_balance_constraints!(container, system::LDCore.System)
    isnothing(container.index_sets) && error("Index sets not attached")
    
    sets = container.index_sets
    model = container.model
    num_periods = system.horizon.periods
    
    isempty(sets.hydro_plant_periods) && return nothing
    
    plant_lookup = Dict(p.id => p for p in system.hydro_plants)
    pumping_lookup = Dict(p.id => p for p in system.pumping_plants)
    
    hydro_turb = model[:hydro_turb]
    hydro_spill = model[:hydro_spill]
    hydro_volume = model[:hydro_volume]
    hydro_diversion = haskey(model, :hydro_diversion) ? model[:hydro_diversion] : nothing
    pumping_var = haskey(model, :pumping) ? model[:pumping] : nothing
    
    for plant in system.hydro_plants
        for t in 1:num_periods
            plant_id = plant.id
            
            lhs = hydro_volume[(plant_id, t)]
            
            if t == 1
                lhs = lhs - plant.reservoir.initial_volume_hm3
            else
                lhs = lhs - hydro_volume[(plant_id, t-1)]
            end
            
            for group in plant.groups
                for unit in group.units
                    lhs = lhs + hydro_turb[(plant_id, group.id, unit.id, t)]
                end
            end
            
            lhs = lhs + hydro_spill[(plant_id, t)]
            
            if !isnothing(hydro_diversion)
                lhs = lhs + hydro_diversion[(plant_id, t)]
            end
            
            for upstream_id in plant.upstream_plant_ids
                upstream_plant = plant_lookup[upstream_id]
                for g in upstream_plant.groups
                    for u in g.units
                        lhs = lhs - hydro_turb[(upstream_id, g.id, u.id, t)]
                    end
                end
                lhs = lhs - hydro_spill[(upstream_id, t)]
            end
            
            for div_upstream_id in plant.diversion_upstream_plant_ids
                if !isnothing(hydro_diversion)
                    lhs = lhs - hydro_diversion[(div_upstream_id, t)]
                end
            end
            
            if !isnothing(pumping_var)
                for pump in system.pumping_plants
                    if pump.downstream_hydro_id == plant_id
                        lhs = lhs + pumping_var[(pump.id, t)]
                    end
                    if pump.upstream_hydro_id == plant_id
                        lhs = lhs - pumping_var[(pump.id, t)]
                    end
                end
            end
            
            rhs = plant.natural_inflow_hm3[t] - plant.water_withdrawal_hm3[t]
            
            @constraint(model, lhs == rhs, base_name="hydro_balance[$(plant.id),$t]")
        end
    end
    
    return nothing
end

function add_initial_volume_constraints!(container, system::LDCore.System)
    isnothing(container.index_sets) && error("Index sets not attached")
    
    model = container.model
    
    isempty(system.hydro_plants) && return nothing
    
    for plant in system.hydro_plants
        v_initial = plant.reservoir.initial_volume_hm3
        fix(model[:hydro_volume][(plant.id, 1)], v_initial; force=false)
    end
    
    return nothing
end

function add_fpha_constraints!(container, system::LDCore.System)
    isnothing(container.index_sets) && error("Index sets not attached")
    
    !system.fpha_enabled && return nothing
    
    model = container.model
    num_periods = system.horizon.periods
    
    hydro_gen = model[:hydro_gen]
    hydro_turb = model[:hydro_turb]
    hydro_volume = model[:hydro_volume]
    hydro_spill = model[:hydro_spill]
    
    for plant in system.hydro_plants
        isempty(plant.fpha_segments) && continue
        
        for seg in plant.fpha_segments
            for t in 1:num_periods
                total_gen = sum(
                    hydro_gen[(plant.id, g.id, u.id, t)]
                    for g in plant.groups for u in g.units
                )
                
                total_turb = sum(
                    hydro_turb[(plant.id, g.id, u.id, t)]
                    for g in plant.groups for u in g.units
                )
                
                lhs = total_gen - seg.correction_factor * (
                    seg.rhs +
                    seg.volume_coefficient * hydro_volume[(plant.id, t)] +
                    seg.turbining_coefficient * total_turb +
                    seg.lateral_flow_coefficient * hydro_spill[(plant.id, t)]
                )
                
                @constraint(model, lhs <= 0, 
                    base_name="fpha[$(plant.id),seg=$(seg.segment),$t]")
            end
        end
    end
    
    return nothing
end

function add_productivity_constraints!(container, system::LDCore.System)
    isnothing(container.index_sets) && error("Index sets not attached")
    
    system.fpha_enabled && return nothing
    
    model = container.model
    num_periods = system.horizon.periods
    
    hydro_gen = model[:hydro_gen]
    hydro_turb = model[:hydro_turb]
    
    for plant in system.hydro_plants
        productivity = plant.specific_productivity_mw_per_m3s
        
        for group in plant.groups
            for unit in group.units
                for t in 1:num_periods
                    gen = hydro_gen[(plant.id, group.id, unit.id, t)]
                    turb = hydro_turb[(plant.id, group.id, unit.id, t)]
                    
                    @constraint(model, gen == productivity * turb,
                        base_name="productivity[$(plant.id),$(group.id),$(unit.id),$t]")
                end
            end
        end
    end
    
    return nothing
end
