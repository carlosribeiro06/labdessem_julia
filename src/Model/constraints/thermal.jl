import ..Core as LDCore

function add_thermal_uc_transition_constraints!(container, system::LDCore.System)
    isnothing(container.index_sets) && error("Index sets not attached")
    
    !container.config.thermal_uc_enabled && return nothing
    
    sets = container.index_sets
    model = container.model
    num_periods = system.horizon.periods
    
    isempty(sets.thermal_indices) && return nothing
    
    thermal_commit = model[:thermal_commit]
    thermal_startup = model[:thermal_startup]
    thermal_shutdown = model[:thermal_shutdown]
    
    plant_lookup = Dict(p.id => p for p in system.thermal_plants)
    
    for plant in system.thermal_plants
        for unit in plant.units
            for t in 1:num_periods
                u_t = thermal_commit[(plant.id, unit.id, t)]
                v_t = thermal_startup[(plant.id, unit.id, t)]
                w_t = thermal_shutdown[(plant.id, unit.id, t)]
                
                if t == 1
                    u_prev = unit.initial_condition.is_on ? 1.0 : 0.0
                    @constraint(model, u_t - u_prev == v_t - w_t,
                        base_name="uc_transition[$(plant.id),$(unit.id),$t]")
                else
                    u_prev = thermal_commit[(plant.id, unit.id, t-1)]
                    @constraint(model, u_t - u_prev == v_t - w_t,
                        base_name="uc_transition[$(plant.id),$(unit.id),$t]")
                end
                
                @constraint(model, v_t + w_t <= 1,
                    base_name="uc_exclusivity[$(plant.id),$(unit.id),$t]")
            end
        end
    end
    
    return nothing
end

function add_thermal_generation_bounds_constraints!(container, system::LDCore.System)
    isnothing(container.index_sets) && error("Index sets not attached")
    
    sets = container.index_sets
    model = container.model
    num_periods = system.horizon.periods
    
    isempty(sets.thermal_indices) && return nothing
    
    thermal_gen = model[:thermal_gen]
    thermal_commit = model[:thermal_commit]
    
    for plant in system.thermal_plants
        for unit in plant.units
            pmin = unit.min_generation_mw
            pmax = unit.max_generation_mw
            
            for t in 1:num_periods
                gen = thermal_gen[(plant.id, unit.id, t)]
                commit = thermal_commit[(plant.id, unit.id, t)]
                
                @constraint(model, gen >= pmin * commit,
                    base_name="thermal_gen_lower[$(plant.id),$(unit.id),$t]")
                @constraint(model, gen <= pmax * commit,
                    base_name="thermal_gen_upper[$(plant.id),$(unit.id),$t]")
            end
        end
    end
    
    return nothing
end

function add_min_updown_constraints!(container, system::LDCore.System)
    isnothing(container.index_sets) && error("Index sets not attached")
    
    !container.config.thermal_uc_enabled && return nothing
    
    model = container.model
    num_periods = system.horizon.periods
    
    thermal_commit = model[:thermal_commit]
    thermal_startup = model[:thermal_startup]
    thermal_shutdown = model[:thermal_shutdown]
    
    for plant in system.thermal_plants
        for unit in plant.units
            min_up = unit.min_up_time
            min_down = unit.min_down_time
            
            for t in 1:num_periods
                if min_up > 1 && t >= min_up
                    startup_sum = sum(thermal_startup[(plant.id, unit.id, τ)] for τ in (t-min_up+1):t)
                    @constraint(model, startup_sum <= thermal_commit[(plant.id, unit.id, t)],
                        base_name="min_up[$(plant.id),$(unit.id),$t]")
                end
                
                if min_down > 1 && t >= min_down
                    shutdown_sum = sum(thermal_shutdown[(plant.id, unit.id, τ)] for τ in (t-min_down+1):t)
                    @constraint(model, shutdown_sum <= 1 - thermal_commit[(plant.id, unit.id, t)],
                        base_name="min_down[$(plant.id),$(unit.id),$t]")
                end
            end
        end
    end
    
    return nothing
end

function add_startup_trajectory_constraints!(container, system::LDCore.System)
    isnothing(container.index_sets) && error("Index sets not attached")
    
    !container.config.thermal_uc_enabled && return nothing
    
    model = container.model
    num_periods = system.horizon.periods
    
    thermal_gen = model[:thermal_gen]
    thermal_startup = model[:thermal_startup]
    
    for plant in system.thermal_plants
        for unit in plant.units
            traj = unit.startup_trajectory_mw
            isempty(traj) && continue
            
            traj_len = length(traj)
            
            for t in 1:num_periods
                for step in 1:min(traj_len, t)
                    if t - step + 1 >= 1
                        v_start = thermal_startup[(plant.id, unit.id, t - step + 1)]
                        gen = thermal_gen[(plant.id, unit.id, t)]
                        
                        if step <= traj_len
                            @constraint(model, gen >= traj[step] * v_start,
                                base_name="startup_traj[$(plant.id),$(unit.id),$t,step=$step]")
                        end
                    end
                end
            end
        end
    end
    
    return nothing
end
