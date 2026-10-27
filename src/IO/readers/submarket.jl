# Submarket reader: CAD_SBM.csv + OPER_SBM.csv.

function read_submarkets(
    cad_path::String,
    oper_path::String,
    horizon::LDCore.StudyHorizon
)::Vector{LDCore.Submarket}
    cad_df = read_csv(cad_path)
    oper_df = read_csv(oper_path)
    
    for col in [:Codigo, :Nome]
        hasproperty(cad_df, col) || throw(ArgumentError("Missing column '$col' in $cad_path"))
    end
    for col in [:CodigoSubmercado, :Periodo, Symbol("Demanda.mw")]
        hasproperty(oper_df, col) || throw(ArgumentError("Missing column '$col' in $oper_path"))
    end
    
    sbm_static = Dict{Int, String}()
    for row in eachrow(cad_df)
        sbm_static[row.Codigo] = strip(string(row.Nome))
    end
    
    demand_by_sbm = Dict{Int, Vector{Float64}}()
    for codigo in keys(sbm_static)
        demand_by_sbm[codigo] = zeros(horizon.periods)
    end
    
    for row in eachrow(oper_df)
        codigo = row.CodigoSubmercado
        haskey(sbm_static, codigo) || throw(ArgumentError(
            "Unknown submarket codigo $codigo in $oper_path"))
        
        orig_period = row.Periodo
        (orig_period >= 1 && orig_period <= horizon.original_periods) || throw(
            ArgumentError("Period $orig_period out of range [1, $(horizon.original_periods)] in $oper_path"))
        
        demanda = row[Symbol("Demanda.mw")]
        for internal_idx in internal_periods_for_original(horizon, orig_period)
            demand_by_sbm[codigo][internal_idx + 1] = demanda
        end
    end
    
    sorted_codigos = sort(collect(keys(sbm_static)))
    [LDCore.Submarket(
        id=codigo,
        name=sbm_static[codigo],
        demand_mw=demand_by_sbm[codigo]
    ) for codigo in sorted_codigos]
end
