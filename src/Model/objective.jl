import ..Core as LDCore

const DEFICIT_COST_PER_MWH = 5000.0

function set_objective!(container, system::LDCore.System)
    isnothing(container.index_sets) && error("Index sets not attached")
    
    model = container.model
    num_periods = system.horizon.periods
    period_duration = system.horizon.period_duration_hours
    
    obj = AffExpr(0.0)
    
    if haskey(model, :thermal_gen)
        thermal_gen = model[:thermal_gen]
        for plant in system.thermal_plants
            for unit in plant.units
                cost = unit.variable_cost_per_mwh * period_duration
                for t in 1:num_periods
                    add_to_expression!(obj, cost, thermal_gen[(plant.id, unit.id, t)])
                end
            end
        end
    end
    
    if container.config.thermal_uc_enabled
        if haskey(model, :thermal_startup)
            thermal_startup = model[:thermal_startup]
            for plant in system.thermal_plants
                for unit in plant.units
                    for t in 1:num_periods
                        add_to_expression!(obj, unit.startup_cost, thermal_startup[(plant.id, unit.id, t)])
                    end
                end
            end
        end
        
        if haskey(model, :thermal_shutdown)
            thermal_shutdown = model[:thermal_shutdown]
            for plant in system.thermal_plants
                for unit in plant.units
                    for t in 1:num_periods
                        add_to_expression!(obj, unit.shutdown_cost, thermal_shutdown[(plant.id, unit.id, t)])
                    end
                end
            end
        end
    end
    
    if haskey(model, :hydro_spill)
        hydro_spill = model[:hydro_spill]
        for plant in system.hydro_plants
            cost = plant.spillage_cost_per_hm3
            for t in 1:num_periods
                add_to_expression!(obj, cost, hydro_spill[(plant.id, t)])
            end
        end
    end
    
    if haskey(model, :hydro_turb)
        hydro_turb = model[:hydro_turb]
        for plant in system.hydro_plants
            cost = plant.turbining_cost_per_hm3
            for group in plant.groups
                for unit in group.units
                    for t in 1:num_periods
                        add_to_expression!(obj, cost, hydro_turb[(plant.id, group.id, unit.id, t)])
                    end
                end
            end
        end
    end
    
    if haskey(model, :interchange)
        interchange = model[:interchange]
        for limit in system.interchange_limits
            cost = limit.penalty_cost_per_mwh * period_duration
            if cost > 0
                for t in 1:num_periods
                    add_to_expression!(obj, cost, interchange[(limit.from_submarket_id, limit.to_submarket_id, t)])
                end
            end
        end
    end
    
    if haskey(model, :deficit)
        deficit = model[:deficit]
        cost = DEFICIT_COST_PER_MWH * period_duration
        for (sub_id, t) in container.index_sets.submarket_periods
            add_to_expression!(obj, cost, deficit[(sub_id, t)])
        end
    end
    
    if system.future_cost_enabled && haskey(model, :future_cost)
        add_to_expression!(obj, 1.0, model[:future_cost])
    end
    
    @objective(model, Min, obj)
    
    return nothing
end

function add_fcf_cuts!(container, system::LDCore.System)
    isnothing(container.index_sets) && error("Index sets not attached")
    
    !system.future_cost_enabled && return nothing
    isempty(system.future_cost_cuts) && return nothing
    !haskey(container.model, :future_cost) && return nothing
    
    model = container.model
    future_cost = model[:future_cost]
    hydro_volume = model[:hydro_volume]
    num_periods = system.horizon.periods
    
    plant_lookup = Dict(p.id => p for p in system.hydro_plants)
    plant_ids = [p.id for p in system.hydro_plants]
    
    for cut in system.future_cost_cuts
        !cut.is_active && continue
        
        lhs = future_cost
        
        for (i, plant_id) in enumerate(plant_ids)
            if i <= length(cut.coefficients)
                coef = cut.coefficients[i]
                plant = plant_lookup[plant_id]
                v_min = plant.reservoir.min_volume_hm3
                
                lhs = lhs - coef * (hydro_volume[(plant_id, num_periods)] - v_min)
            end
        end
        
        @constraint(model, lhs >= cut.intercept,
            base_name="fcf_cut[$(cut.cut_id)]")
    end
    
    return nothing
end

function add_fcf_cut!(container, cut::LDCore.FutureCostCut, system::LDCore.System)
    isnothing(container.index_sets) && error("Index sets not attached")
    !haskey(container.model, :future_cost) && return nothing
    
    model = container.model
    future_cost = model[:future_cost]
    hydro_volume = model[:hydro_volume]
    num_periods = system.horizon.periods
    
    plant_ids = [p.id for p in system.hydro_plants]
    plant_lookup = Dict(p.id => p for p in system.hydro_plants)
    
    lhs = future_cost
    
    for (i, plant_id) in enumerate(plant_ids)
        if i <= length(cut.coefficients)
            coef = cut.coefficients[i]
            plant = plant_lookup[plant_id]
            v_min = plant.reservoir.min_volume_hm3
            
            lhs = lhs - coef * (hydro_volume[(plant_id, num_periods)] - v_min)
        end
    end
    
    @constraint(model, lhs >= cut.intercept,
        base_name="fcf_cut[$(cut.cut_id)]")
    
    return nothing
end
