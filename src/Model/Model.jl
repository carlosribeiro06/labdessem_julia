module Model

using JuMP
using HiGHS

export ModelConfig, ModelContainer, IndexSets, build_index_sets, attach_index_sets!
export thermal_gen_indices, hydro_gen_indices, hydro_plant_indices
export renewable_plant_indices, pumping_plant_indices
export period_thermal_indices, period_hydro_indices, constraint_name
export create_thermal_variables!, create_hydro_variables!, create_pumping_variables!
export create_renewable_variables!, create_interchange_variables!, create_system_variables!
export add_hydraulic_balance_constraints!, add_initial_volume_constraints!
export add_fpha_constraints!, add_productivity_constraints!
export add_thermal_uc_transition_constraints!, add_thermal_generation_bounds_constraints!
export add_min_updown_constraints!, add_startup_trajectory_constraints!
export add_demand_balance_constraints!, add_operational_limits_constraints!
export set_objective!, add_fcf_cuts!, add_fcf_cut!
export build_model

@kwdef struct ModelConfig
    thermal_uc_enabled::Bool = true
    hydro_uc_enabled::Bool = false
    optimizer_constructor = HiGHS.Optimizer
end

mutable struct ModelContainer
    model::JuMP.Model
    config::ModelConfig
    index_sets::Union{Nothing,Any}
end

function ModelContainer(config::ModelConfig = ModelConfig())
    model = try
        JuMP.Model(config.optimizer_constructor)
    catch e
        error("Failed to create solver: $e")
    end
    return ModelContainer(model, config, nothing)
end

include("indexing.jl")
include("variables.jl")
include("constraints/hydro.jl")
include("constraints/thermal.jl")
include("constraints/demand.jl")
include("constraints/limits.jl")
include("objective.jl")

function build_model(system, config::ModelConfig = ModelConfig())
    container = ModelContainer(config)
    
    sets = build_index_sets(system)
    attach_index_sets!(container, sets)
    
    create_thermal_variables!(container, system)
    create_hydro_variables!(container, system)
    create_pumping_variables!(container, system)
    create_renewable_variables!(container, system)
    create_interchange_variables!(container, system)
    create_system_variables!(container, system)
    
    add_hydraulic_balance_constraints!(container, system)
    add_fpha_constraints!(container, system)
    add_productivity_constraints!(container, system)
    
    add_thermal_uc_transition_constraints!(container, system)
    add_thermal_generation_bounds_constraints!(container, system)
    add_min_updown_constraints!(container, system)
    add_startup_trajectory_constraints!(container, system)
    
    add_demand_balance_constraints!(container, system)
    add_operational_limits_constraints!(container, system)
    
    set_objective!(container, system)
    add_fcf_cuts!(container, system)
    
    return container
end

end
