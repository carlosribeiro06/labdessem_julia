module Model

using JuMP
using HiGHS

export ModelConfig, ModelContainer, IndexSets, build_index_sets, attach_index_sets!
export thermal_gen_indices, hydro_gen_indices, hydro_plant_indices
export renewable_plant_indices, pumping_plant_indices
export period_thermal_indices, period_hydro_indices, constraint_name
export create_thermal_variables!, create_hydro_variables!, create_pumping_variables!
export create_renewable_variables!, create_interchange_variables!, create_system_variables!

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
include("objective.jl")

end
