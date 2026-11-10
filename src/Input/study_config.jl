# Study configuration types and loading.

@enum FphaOption begin
    ConstantProductivity
    Precomputed
    Computed
end

function parse_fpha_option(s::AbstractString)::FphaOption
    s == "constant_productivity" && return ConstantProductivity
    s == "precomputed" && return Precomputed
    s == "computed" && return Computed
    throw(ArgumentError("Invalid FPHA option '$s'. Valid: constant_productivity, precomputed, computed"))
end

struct StudyConfig
    opcao_execucao::Int
    rede::Bool
    uct::Bool
    uch::Bool
    fpha::FphaOption
    fcf::Bool
    ton_residual::Bool
    engmax::Bool
end

function read_study_config(path::String)::StudyConfig
    !isfile(path) && throw(ArgumentError("Config file not found: $path"))
    json = JSON3.read(read(path, String))
    
    haskey(json, :opcao_execucao) || throw(ArgumentError("Missing required field 'opcao_execucao' in $path"))
    
    StudyConfig(
        json.opcao_execucao,
        get(json, :rede, 0) != 0,
        get(json, :UCT, 0) != 0,
        get(json, :UCH, 0) != 0,
        parse_fpha_option(string(get(json, :FPHA, "constant_productivity"))),
        get(json, :FCF, 0) != 0,
        get(json, :TON_Residual, 0) != 0,
        get(json, :EngMax, 0) != 0
    )
end

is_fpha_enabled(cfg::StudyConfig)::Bool = cfg.fpha != ConstantProductivity
is_fpha_precomputed(cfg::StudyConfig)::Bool = cfg.fpha == Precomputed
