function extract_flow_duals(
    dual_values::Vector{Float64},
    mapping::FlowCutMapping,
    base_row_offset::Int
)::Dict{Tuple{Int,Int}, Float64}
    result = Dict{Tuple{Int,Int}, Float64}()

    for ((branch_idx, period), (upper_idx, lower_idx)) in mapping.indices
        upper_row = base_row_offset + upper_idx
        lower_row = base_row_offset + lower_idx

        @assert upper_row <= length(dual_values) "row index out of bounds: upper_row=$upper_row >= dual.len()=$(length(dual_values))"
        @assert lower_row <= length(dual_values) "row index out of bounds: lower_row=$lower_row >= dual.len()=$(length(dual_values))"

        lambda_l = dual_values[upper_row] + dual_values[lower_row]
        result[(branch_idx, period)] = lambda_l
    end

    return result
end

function compute_cmb_per_bus(
    system::LDCore.System,
    model::DcNetworkModel,
    demand_duals::Dict{Tuple{SubmarketId, Int}, Float64},
    flow_duals::Dict{Tuple{Int, Int}, Float64},
    periods::Vector{Int}
)::Vector{CmbRecord}
    records = CmbRecord[]

    for period in periods
        for (bus_pos, bus_id) in enumerate(model.non_slack_bus_ids)
            bus = nothing
            for b in system.buses
                if b.id == bus_id
                    bus = b
                    break
                end
            end
            bus === nothing && continue

            lambda_ds = get(demand_duals, (bus.submarket_id, period), 0.0)

            network_component = 0.0
            for ((branch_idx, flow_period), lambda_l) in flow_duals
                flow_period != period && continue
                ptdf_r = ptdf_row(model, branch_idx)
                if bus_pos <= length(ptdf_r)
                    network_component += ptdf_r[bus_pos] * lambda_l
                end
            end

            cmb = lambda_ds + network_component

            push!(records, CmbRecord(
                bus_id=bus_id,
                period=period,
                cmb=cmb,
                submarket_id=bus.submarket_id
            ))
        end
    end

    return records
end

function compute_cmo_from_cmb(
    cmb_records::Vector{CmbRecord},
    system::LDCore.System
)::Dict{Tuple{SubmarketId, Int}, Float64}
    bus_map = Dict{BusId, LDCore.Bus}(b.id => b for b in system.buses)

    grouped = Dict{Tuple{SubmarketId, Int}, Vector{CmbRecord}}()
    for record in cmb_records
        key = (record.submarket_id, record.period)
        if !haskey(grouped, key)
            grouped[key] = CmbRecord[]
        end
        push!(grouped[key], record)
    end

    cmo_map = Dict{Tuple{SubmarketId, Int}, Float64}()

    for ((submarket_id, period), records) in grouped
        weighted_sum = 0.0
        demand_sum = 0.0

        for record in records
            bus = get(bus_map, record.bus_id, nothing)
            demand = 0.0
            if bus !== nothing && period <= length(bus.demand_mw)
                demand = bus.demand_mw[period]
            end

            weighted_sum += record.cmb * demand
            demand_sum += demand
        end

        cmo = if abs(demand_sum) < 1e-9
            sum(r.cmb for r in records) / length(records)
        else
            weighted_sum / demand_sum
        end

        cmo_map[(submarket_id, period)] = cmo
    end

    return cmo_map
end
