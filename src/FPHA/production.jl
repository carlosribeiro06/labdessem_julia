const K_GRAVITY = 0.00981

Base.@kwdef struct ProductionFunction
    forebay::ForebayTable
    tailrace::Union{TailraceModel,Nothing} = nothing
    hydraulic_loss_m::Float64 = 0.0
    efficiency::Float64 = 1.0
    max_turbined_m3s::Float64
    max_generation_mw::Float64
    hydro_name::String
end

function tailrace_level(pf::ProductionFunction, outflow_m3s::Float64)::Float64
    pf.tailrace === nothing ? 0.0 : evaluate(pf.tailrace, outflow_m3s)
end

function net_head(pf::ProductionFunction, volume_hm3::Float64, outflow_m3s::Float64)::Float64
    h_forebay = interpolate(pf.forebay, volume_hm3)
    h_tailrace = tailrace_level(pf, outflow_m3s)
    max(0.0, h_forebay - h_tailrace - pf.hydraulic_loss_m)
end

function evaluate(pf::ProductionFunction, volume_hm3::Float64,
                  turbined_m3s::Float64, spillage_m3s::Float64)::Float64
    q = clamp(turbined_m3s, 0.0, pf.max_turbined_m3s)
    outflow = q + spillage_m3s
    h = net_head(pf, volume_hm3, outflow)
    K_GRAVITY * pf.efficiency * q * h
end

function evaluate_capped(pf::ProductionFunction, volume_hm3::Float64,
                         turbined_m3s::Float64, spillage_m3s::Float64)::Float64
    min(evaluate(pf, volume_hm3, turbined_m3s, spillage_m3s), pf.max_generation_mw)
end
