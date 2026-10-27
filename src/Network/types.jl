@enum ConstraintSense LessThanOrEqual GreaterThanOrEqual Equal

Base.@kwdef struct FlowViolation
    branch_id::BranchId
    branch_name::String
    period::Int
    flow_mw::Float64
    limit_mw::Float64
end

Base.@kwdef struct LineFlowResult
    branch_id::BranchId
    branch_name::String
    from_bus_name::String
    to_bus_name::String
    period::Int
    flow_mw::Float64
    limit_mw::Float64
end

Base.@kwdef struct AddedFlowCutLineResult
    branch_id::BranchId
    branch_name::String
    from_bus_id::BusId
    to_bus_id::BusId
    flow_mw::Float64
    limit_mw::Float64
end

Base.@kwdef struct NetworkTerm
    variable_name::String
    coefficient::Float64
end

Base.@kwdef struct NetworkConstraint
    name::String
    terms::Vector{NetworkTerm}
    sense::ConstraintSense
    rhs::Float64
end

Base.@kwdef struct FlowCutKey
    branch_idx::Int
    period::Int
end

Base.@kwdef struct FlowCutMapping
    indices::Dict{Tuple{Int,Int}, Tuple{Int,Int}} = Dict{Tuple{Int,Int}, Tuple{Int,Int}}()
end

Base.@kwdef struct CmbRecord
    bus_id::BusId
    period::Int
    cmb::Float64
    submarket_id::SubmarketId
end
