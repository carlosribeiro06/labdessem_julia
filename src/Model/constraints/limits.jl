import ..Core as LDCore

function add_operational_limits_constraints!(container, system::LDCore.System)
    isnothing(container.index_sets) && error("Index sets not attached")
    
    model = container.model
    
    isempty(system.operational_limits) && return nothing
    
    for limit in system.operational_limits
        for t in limit.start_period:limit.end_period
            var = get_limit_variable(model, limit.target, limit.variable, t)
            isnothing(var) && continue
            
            name_prefix = "op_limit[$(limit.plant_name),$(limit.variable),$t]"
            
            if !isnothing(limit.lower_bound)
                @constraint(model, var >= limit.lower_bound,
                    base_name="$(name_prefix)_lower")
            end
            
            if !isnothing(limit.upper_bound)
                @constraint(model, var <= limit.upper_bound,
                    base_name="$(name_prefix)_upper")
            end
        end
    end
    
    return nothing
end

function get_limit_variable(model, target::LDCore.ThermalPlantTarget, variable::LDCore.OperationalLimitVariable, t::Int)
    variable == LDCore.Generation || return nothing
    haskey(model, :thermal_gen) || return nothing
    
    thermal_gen = model[:thermal_gen]
    plant_id = target.id
    
    total_gen = AffExpr(0.0)
    for key in keys(thermal_gen)
        if key[1] == plant_id && key[3] == t
            add_to_expression!(total_gen, thermal_gen[key])
        end
    end
    
    return total_gen
end

function get_limit_variable(model, target::LDCore.ThermalUnitTarget, variable::LDCore.OperationalLimitVariable, t::Int)
    variable == LDCore.Generation || return nothing
    haskey(model, :thermal_gen) || return nothing
    
    thermal_gen = model[:thermal_gen]
    return get(thermal_gen, (target.plant_id, target.unit_id, t), nothing)
end

function get_limit_variable(model, target::LDCore.HydroPlantTarget, variable::LDCore.OperationalLimitVariable, t::Int)
    plant_id = target.id
    
    if variable == LDCore.Generation
        haskey(model, :hydro_gen) || return nothing
        hydro_gen = model[:hydro_gen]
        total_gen = AffExpr(0.0)
        for key in keys(hydro_gen)
            if key[1] == plant_id && key[4] == t
                add_to_expression!(total_gen, hydro_gen[key])
            end
        end
        return total_gen
        
    elseif variable == LDCore.Spillage
        haskey(model, :hydro_spill) || return nothing
        return get(model[:hydro_spill], (plant_id, t), nothing)
        
    elseif variable == LDCore.Volume
        haskey(model, :hydro_volume) || return nothing
        return get(model[:hydro_volume], (plant_id, t), nothing)
        
    elseif variable == LDCore.Defluence
        haskey(model, :hydro_turb) || return nothing
        haskey(model, :hydro_spill) || return nothing
        hydro_turb = model[:hydro_turb]
        hydro_spill = model[:hydro_spill]
        
        total_turb = AffExpr(0.0)
        for key in keys(hydro_turb)
            if key[1] == plant_id && key[4] == t
                add_to_expression!(total_turb, hydro_turb[key])
            end
        end
        total_turb = total_turb + get(hydro_spill, (plant_id, t), 0.0)
        return total_turb
        
    elseif variable == LDCore.Turbining
        haskey(model, :hydro_turb) || return nothing
        hydro_turb = model[:hydro_turb]
        total_turb = AffExpr(0.0)
        for key in keys(hydro_turb)
            if key[1] == plant_id && key[4] == t
                add_to_expression!(total_turb, hydro_turb[key])
            end
        end
        return total_turb
        
    elseif variable == LDCore.Diversion
        haskey(model, :hydro_diversion) || return nothing
        return get(model[:hydro_diversion], (plant_id, t), nothing)
    end
    
    return nothing
end

function get_limit_variable(model, target::LDCore.HydroUnitTarget, variable::LDCore.OperationalLimitVariable, t::Int)
    return nothing
end

function get_limit_variable(model, target::LDCore.PumpingPlantTarget, variable::LDCore.OperationalLimitVariable, t::Int)
    variable == LDCore.Pumping || return nothing
    haskey(model, :pumping) || return nothing
    return get(model[:pumping], (target.id, t), nothing)
end
