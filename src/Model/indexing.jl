import ..Core as LDCore

struct IndexSets
    periods::Vector{Int}
    thermal_indices::Vector{Tuple{Int,Int,Int}}
    hydro_indices::Vector{Tuple{Int,Int,Int,Int}}
    hydro_plant_periods::Vector{Tuple{Int,Int}}
    renewable_indices::Vector{Tuple{Int,Int}}
    pumping_indices::Vector{Tuple{Int,Int}}
    interchange_indices::Vector{Tuple{Int,Int,Int}}
    submarket_periods::Vector{Tuple{Int,Int}}
end

function build_index_sets(system::LDCore.System)::IndexSets
    num_periods = system.horizon.periods
    num_periods < 1 && throw(ArgumentError("periods must be >= 1"))
    
    periods = collect(1:num_periods)
    
    thermal_indices = Tuple{Int,Int,Int}[]
    for plant in system.thermal_plants
        for unit in plant.units
            for t in periods
                push!(thermal_indices, (plant.id, unit.id, t))
            end
        end
    end
    
    hydro_indices = Tuple{Int,Int,Int,Int}[]
    hydro_plant_periods = Tuple{Int,Int}[]
    for plant in system.hydro_plants
        for t in periods
            push!(hydro_plant_periods, (plant.id, t))
        end
        for group in plant.groups
            for unit in group.units
                for t in periods
                    push!(hydro_indices, (plant.id, group.id, unit.id, t))
                end
            end
        end
    end
    
    renewable_indices = Tuple{Int,Int}[]
    for plant in system.renewable_plants
        for t in periods
            push!(renewable_indices, (plant.id, t))
        end
    end
    
    pumping_indices = Tuple{Int,Int}[]
    for plant in system.pumping_plants
        for t in periods
            push!(pumping_indices, (plant.id, t))
        end
    end
    
    interchange_indices = Tuple{Int,Int,Int}[]
    for limit in system.interchange_limits
        for t in periods
            push!(interchange_indices, (limit.from_submarket_id, limit.to_submarket_id, t))
        end
    end
    
    submarket_periods = Tuple{Int,Int}[]
    for submarket in system.submarkets
        for t in periods
            push!(submarket_periods, (submarket.id, t))
        end
    end
    
    return IndexSets(
        periods,
        thermal_indices,
        hydro_indices,
        hydro_plant_periods,
        renewable_indices,
        pumping_indices,
        interchange_indices,
        submarket_periods
    )
end

function attach_index_sets!(container, index_sets::IndexSets)
    container.index_sets = index_sets
    return nothing
end

function thermal_gen_indices(sets::IndexSets, plant_id::Int)
    filter(idx -> idx[1] == plant_id, sets.thermal_indices)
end

function hydro_gen_indices(sets::IndexSets, plant_id::Int)
    filter(idx -> idx[1] == plant_id, sets.hydro_indices)
end

function hydro_plant_indices(sets::IndexSets, plant_id::Int)
    filter(idx -> idx[1] == plant_id, sets.hydro_plant_periods)
end

function renewable_plant_indices(sets::IndexSets, plant_id::Int)
    filter(idx -> idx[1] == plant_id, sets.renewable_indices)
end

function pumping_plant_indices(sets::IndexSets, plant_id::Int)
    filter(idx -> idx[1] == plant_id, sets.pumping_indices)
end

function period_thermal_indices(sets::IndexSets, period::Int)
    filter(idx -> idx[end] == period, sets.thermal_indices)
end

function period_hydro_indices(sets::IndexSets, period::Int)
    filter(idx -> idx[end] == period, sets.hydro_indices)
end

function constraint_name(prefix::String, indices::Tuple)::String
    idx_str = join(string.(indices), ",")
    return "$(prefix)[$(idx_str)]"
end
