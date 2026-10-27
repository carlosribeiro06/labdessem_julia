function find_reference_bus(system::System)::Bus
    for bus in system.buses
        bus.angle_reference && return bus
    end
    throw(NoReferenceBusError())
end

function build_non_slack_bus_mapping(system::System, ref_bus_id::BusId)
    non_slack = filter(b -> b.id != ref_bus_id, system.buses)
    bus_to_pos = Dict{BusId, Int}(bus.id => i for (i, bus) in enumerate(non_slack))
    non_slack_ids = BusId[bus.id for bus in non_slack]
    return bus_to_pos, non_slack_ids
end

function build_incidence_matrix(system::System, bus_to_pos::Dict{BusId, Int})::Matrix{Float64}
    isempty(system.branches) && throw(NoBranchesError())
    n_branches = length(system.branches)
    n_buses = length(bus_to_pos)
    
    n_buses == 0 && return zeros(Float64, n_branches, 0)
    
    A = zeros(Float64, n_branches, n_buses)
    for (l, branch) in enumerate(system.branches)
        from_pos = get(bus_to_pos, branch.from_bus_id, nothing)
        to_pos = get(bus_to_pos, branch.to_bus_id, nothing)
        from_pos !== nothing && (A[l, from_pos] = 1.0)
        to_pos !== nothing && (A[l, to_pos] = -1.0)
    end
    return A
end

function build_susceptance_matrix(system::System, bus_to_pos::Dict{BusId, Int})::Matrix{Float64}
    n = length(bus_to_pos)
    n == 0 && return zeros(Float64, 0, 0)
    
    B = zeros(Float64, n, n)
    for branch in system.branches
        susceptance = 1.0 / branch.reactance_pu
        from_pos = get(bus_to_pos, branch.from_bus_id, nothing)
        to_pos = get(bus_to_pos, branch.to_bus_id, nothing)

        from_pos !== nothing && (B[from_pos, from_pos] += susceptance)
        to_pos !== nothing && (B[to_pos, to_pos] += susceptance)

        if from_pos !== nothing && to_pos !== nothing
            B[from_pos, to_pos] -= susceptance
            B[to_pos, from_pos] -= susceptance
        end
    end
    return B
end

function build_branch_susceptance_diag(system::System)::Diagonal{Float64, Vector{Float64}}
    susceptances = [1.0 / branch.reactance_pu for branch in system.branches]
    return Diagonal(susceptances)
end

function compute_ptdf(system::System)
    ref_bus = find_reference_bus(system)
    bus_to_pos, non_slack_ids = build_non_slack_bus_mapping(system, ref_bus.id)

    isempty(system.branches) && throw(NoBranchesError())
    
    if isempty(bus_to_pos)
        ptdf = zeros(Float64, length(system.branches), 0)
        return ptdf, bus_to_pos, non_slack_ids, ref_bus.id
    end

    A = build_incidence_matrix(system, bus_to_pos)
    B = build_susceptance_matrix(system, bus_to_pos)
    D = build_branch_susceptance_diag(system)

    try
        B_inv_At = B \ A'
        PTDF = D * B_inv_At'
        return PTDF, bus_to_pos, non_slack_ids, ref_bus.id
    catch e
        if e isa LinearAlgebra.SingularException
            throw(SingularMatrixError("susceptance matrix"))
        end
        rethrow()
    end
end
