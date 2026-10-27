Base.@kwdef struct GeneratorEntry
    bus_id::BusId
    variable_name::String
end

Base.@kwdef struct PumpingEntry
    bus_id::BusId
    variable_name::String
    specific_consumption_mw_per_m3s::Float64
end

Base.@kwdef mutable struct FlowCutInput
    thermal_entries::Vector{GeneratorEntry} = GeneratorEntry[]
    hydro_entries::Vector{GeneratorEntry} = GeneratorEntry[]
    renewable_entries::Vector{GeneratorEntry} = GeneratorEntry[]
    pumping_entries::Vector{PumpingEntry} = PumpingEntry[]
    flow_conversion::Float64
end

FlowCutInput(flow_conversion::Float64) = FlowCutInput(
    thermal_entries=GeneratorEntry[],
    hydro_entries=GeneratorEntry[],
    renewable_entries=GeneratorEntry[],
    pumping_entries=PumpingEntry[],
    flow_conversion=flow_conversion
)

function add_thermal!(input::FlowCutInput, entry::GeneratorEntry)
    push!(input.thermal_entries, entry)
end

function add_hydro!(input::FlowCutInput, entry::GeneratorEntry)
    push!(input.hydro_entries, entry)
end

function add_renewable!(input::FlowCutInput, entry::GeneratorEntry)
    push!(input.renewable_entries, entry)
end

function add_pumping!(input::FlowCutInput, entry::PumpingEntry)
    push!(input.pumping_entries, entry)
end

function build_flow_cut_terms(
    model::DcNetworkModel,
    branch_idx::Int,
    input::FlowCutInput
)::Vector{NetworkTerm}
    ptdf_r = ptdf_row(model, branch_idx)
    terms = NetworkTerm[]

    for entry in input.thermal_entries
        pos = position_of_bus(model, entry.bus_id)
        pos === nothing && continue
        coefficient = ptdf_r[pos]
        abs(coefficient) > 1e-12 && push!(terms, NetworkTerm(
            variable_name=entry.variable_name,
            coefficient=coefficient
        ))
    end

    for entry in input.hydro_entries
        pos = position_of_bus(model, entry.bus_id)
        pos === nothing && continue
        coefficient = ptdf_r[pos]
        abs(coefficient) > 1e-12 && push!(terms, NetworkTerm(
            variable_name=entry.variable_name,
            coefficient=coefficient
        ))
    end

    for entry in input.renewable_entries
        pos = position_of_bus(model, entry.bus_id)
        pos === nothing && continue
        coefficient = ptdf_r[pos]
        abs(coefficient) > 1e-12 && push!(terms, NetworkTerm(
            variable_name=entry.variable_name,
            coefficient=coefficient
        ))
    end

    for entry in input.pumping_entries
        pos = position_of_bus(model, entry.bus_id)
        pos === nothing && continue
        coefficient = -ptdf_r[pos] * entry.specific_consumption_mw_per_m3s / input.flow_conversion
        abs(coefficient) > 1e-12 && push!(terms, NetworkTerm(
            variable_name=entry.variable_name,
            coefficient=coefficient
        ))
    end

    return terms
end
