import ..Core as LDCore

function add_demand_balance_constraints!(container, system::LDCore.System)
    isnothing(container.index_sets) && error("Index sets not attached")
    
    sets = container.index_sets
    model = container.model
    num_periods = system.horizon.periods
    
    isempty(sets.submarket_periods) && return nothing
    
    deficit = model[:deficit]
    
    thermal_gen = haskey(model, :thermal_gen) ? model[:thermal_gen] : nothing
    hydro_gen = haskey(model, :hydro_gen) ? model[:hydro_gen] : nothing
    renewable_gen = haskey(model, :renewable_gen) ? model[:renewable_gen] : nothing
    interchange = haskey(model, :interchange) ? model[:interchange] : nothing
    pumping_var = haskey(model, :pumping) ? model[:pumping] : nothing
    
    plant_to_submarket_thermal = Dict{Int, Int}()
    for p in system.thermal_plants
        plant_to_submarket_thermal[p.id] = p.submarket_id
    end
    
    plant_to_submarket_hydro = Dict{Int, Int}()
    for p in system.hydro_plants
        plant_to_submarket_hydro[p.id] = p.submarket_id
    end
    
    plant_to_submarket_renewable = Dict{Int, Int}()
    for p in system.renewable_plants
        plant_to_submarket_renewable[p.id] = p.submarket_id
    end
    
    plant_to_submarket_pumping = Dict{Int, Int}()
    pumping_consumption = Dict{Int, Float64}()
    for p in system.pumping_plants
        plant_to_submarket_pumping[p.id] = p.submarket_id
        pumping_consumption[p.id] = p.specific_consumption_mw_per_m3s
    end
    
    for submarket in system.submarkets
        sub_id = submarket.id
        
        for t in 1:num_periods
            lhs = deficit[(sub_id, t)]
            
            if !isnothing(thermal_gen)
                for plant in system.thermal_plants
                    if plant.submarket_id == sub_id
                        for unit in plant.units
                            lhs = lhs + thermal_gen[(plant.id, unit.id, t)]
                        end
                    end
                end
            end
            
            if !isnothing(hydro_gen)
                for plant in system.hydro_plants
                    if plant.submarket_id == sub_id
                        for group in plant.groups
                            for unit in group.units
                                lhs = lhs + hydro_gen[(plant.id, group.id, unit.id, t)]
                            end
                        end
                    end
                end
            end
            
            if !isnothing(renewable_gen)
                for plant in system.renewable_plants
                    if plant.submarket_id == sub_id
                        lhs = lhs + renewable_gen[(plant.id, t)]
                    end
                end
            end
            
            if !isnothing(interchange)
                for limit in system.interchange_limits
                    if limit.to_submarket_id == sub_id
                        lhs = lhs + interchange[(limit.from_submarket_id, limit.to_submarket_id, t)]
                    end
                    if limit.from_submarket_id == sub_id
                        lhs = lhs - interchange[(limit.from_submarket_id, limit.to_submarket_id, t)]
                    end
                end
            end
            
            if !isnothing(pumping_var)
                for pump in system.pumping_plants
                    if pump.submarket_id == sub_id
                        consumption_factor = pump.specific_consumption_mw_per_m3s
                        lhs = lhs - consumption_factor * pumping_var[(pump.id, t)]
                    end
                end
            end
            
            demand = submarket.demand_mw[t]
            
            @constraint(model, lhs == demand,
                base_name="demand_balance[$(sub_id),$t]")
        end
    end
    
    return nothing
end
