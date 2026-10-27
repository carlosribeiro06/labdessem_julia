function round_to_digits(value::Float64, digits::Int)::Float64
    factor = 10.0^digits
    round(value * factor) / factor
end

function dot(left::AbstractVector{Float64}, right::AbstractVector{Float64})::Float64
    isempty(left) && return 0.0
    sum(a * b for (a, b) in zip(left, right))
end

function compute_line_flows(
    system::LDCore.System,
    model::DcNetworkModel,
    injections::Matrix{Float64}
)::Vector{LineFlowResult}
    n_periods = size(injections, 2)
    n_branches_count = n_branches(model)
    results = LineFlowResult[]

    for period in 1:n_periods
        period_injections = @view injections[:, period]
        for (branch_idx, branch) in enumerate(system.branches)
            ptdf_r = ptdf_row(model, branch_idx)
            flow = dot(ptdf_r, period_injections)
            push!(results, LineFlowResult(
                branch_id=branch.id,
                branch_name=branch.name,
                from_bus_name=bus_name(system, branch.from_bus_id),
                to_bus_name=bus_name(system, branch.to_bus_id),
                period=period,
                flow_mw=flow,
                limit_mw=branch.thermal_limit_mw
            ))
        end
    end
    return results
end

function bus_name(system::LDCore.System, bus_id::BusId)::String
    for bus in system.buses
        bus.id == bus_id && return bus.name
    end
    return "BUS-$(bus_id)"
end

function detect_flow_violations(
    system::LDCore.System,
    model::DcNetworkModel,
    injections::Matrix{Float64}
)::Vector{FlowViolation}
    flows = compute_line_flows(system, model, injections)
    violations = FlowViolation[]

    for flow_result in flows
        rounded_flow = round_to_digits(flow_result.flow_mw, 4)
        if abs(rounded_flow) > flow_result.limit_mw
            push!(violations, FlowViolation(
                branch_id=flow_result.branch_id,
                branch_name=flow_result.branch_name,
                period=flow_result.period,
                flow_mw=flow_result.flow_mw,
                limit_mw=flow_result.limit_mw
            ))
        end
    end
    return violations
end

function all_flow_constraints(system::LDCore.System)::Set{FlowCutKey}
    keys = Set{FlowCutKey}()
    n_branches_count = length(system.branches)
    n_periods = system.horizon.periods

    for branch_idx in 1:n_branches_count
        for period in 1:n_periods
            push!(keys, FlowCutKey(branch_idx=branch_idx, period=period))
        end
    end
    return keys
end

function constant_load_shift(
    system::LDCore.System,
    model::DcNetworkModel,
    branch_idx::Int,
    period::Int
)::Float64
    ptdf_r = ptdf_row(model, branch_idx)
    shift = 0.0
    for (bus_pos, bus_id) in enumerate(model.non_slack_bus_ids)
        bus = nothing
        for b in system.buses
            if b.id == bus_id
                bus = b
                break
            end
        end
        bus === nothing && continue
        demand = length(bus.demand_mw) >= period ? bus.demand_mw[period] : 0.0
        shift += ptdf_r[bus_pos] * demand
    end
    return shift
end
