Base.@kwdef struct DcNetworkModel
    ptdf::Matrix{Float64}
    bus_to_position::Dict{BusId, Int}
    non_slack_bus_ids::Vector{BusId}
    branch_ids::Vector{BranchId}
    reference_bus_id::BusId
end

function DcNetworkModel(system::System)
    ptdf, bus_to_pos, non_slack_ids, ref_bus_id = compute_ptdf(system)
    branch_ids = BranchId[branch.id for branch in system.branches]
    return DcNetworkModel(
        ptdf=ptdf,
        bus_to_position=bus_to_pos,
        non_slack_bus_ids=non_slack_ids,
        branch_ids=branch_ids,
        reference_bus_id=ref_bus_id
    )
end

ptdf_row(model::DcNetworkModel, branch_idx::Int) = @view model.ptdf[branch_idx, :]

function ptdf_coefficient(model::DcNetworkModel, branch_idx::Int, bus_id::BusId)::Float64
    pos = get(model.bus_to_position, bus_id, nothing)
    pos === nothing && return 0.0
    return model.ptdf[branch_idx, pos]
end

position_of_bus(model::DcNetworkModel, bus_id::BusId) = get(model.bus_to_position, bus_id, nothing)

n_branches(model::DcNetworkModel)::Int = size(model.ptdf, 1)
n_buses(model::DcNetworkModel)::Int = size(model.ptdf, 2)
reference_bus(model::DcNetworkModel)::BusId = model.reference_bus_id
ptdf_column(model::DcNetworkModel, bus_pos::Int) = @view model.ptdf[:, bus_pos]
