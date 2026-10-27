# Study loading orchestration.

function read_study_from_path(case_path::String)::LDCore.System
    config_path = joinpath(case_path, "study_config.json")
    
    !isfile(config_path) && throw(ArgumentError(
        "Configuration file not found: $config_path\n" *
        "Each study case must contain a study_config.json file in its root directory."))
    
    config = read_study_config(config_path)
    
    read_study_from_path_with_options(
        case_path,
        config.ton_residual,
        config.rede,
        config.uct,
        config.uch,
        is_fpha_precomputed(config),
        config.fcf
    )
end

function read_study_from_path_with_options(
    base_path::String,
    ton_residual_enabled::Bool,
    network_enabled::Bool,
    thermal_unit_commitment_enabled::Bool,
    hydro_unit_commitment_enabled::Bool,
    fpha_enabled::Bool,
    future_cost_enabled::Bool
)::LDCore.System
    cad_path = joinpath(base_path, "CAD")
    oper_path = joinpath(base_path, "OPER")
    
    horizon = read_horizon(joinpath(oper_path, "OPER_DURACAO.csv"))
    
    submarkets = read_submarkets(
        joinpath(cad_path, "CAD_SBM.csv"),
        joinpath(oper_path, "OPER_SBM.csv"),
        horizon
    )
    
    buses = if network_enabled
        read_buses(joinpath(oper_path, "OPER_CARGA_BARRA.csv"), horizon)
    else
        build_dummy_buses(submarkets, horizon)
    end
    
    branches = if network_enabled
        read_branches(joinpath(oper_path, "OPER_LINHA.csv"))
    else
        LDCore.Branch[]
    end
    
    interchange_limits = read_interchange_limits(joinpath(oper_path, "OPER_LIMITE_INTERCAMBIO.csv"))
    residual_costs = read_residual_costs(joinpath(oper_path, "OPER_CUSTO_RESIDUAL.csv"), ton_residual_enabled)
    
    future_cost_cuts = if future_cost_enabled
        read_future_cost_cuts(joinpath(oper_path, "OPER_FCF.bin"))
    else
        LDCore.FutureCostCut[]
    end
    
    thermal_plants = read_thermal_plants(
        joinpath(cad_path, "CAD_UNID_UTE.csv"),
        joinpath(cad_path, "CAD_RAMPAS_TERMICAS.csv"),
        horizon,
        submarkets,
        thermal_unit_commitment_enabled,
        network_enabled
    )
    
    fpha_path = fpha_enabled ? joinpath(oper_path, "OPER_FPHA.csv") : nothing
    hydro_plants = read_hydro_plants(
        joinpath(cad_path, "CAD_UHE.csv"),
        joinpath(cad_path, "CAD_CONJ_UHE.csv"),
        joinpath(oper_path, "OPER_VAZAO.csv"),
        fpha_path,
        horizon,
        submarkets,
        fpha_enabled,
        network_enabled
    )
    
    pumping_plants = read_pumping_plants(
        joinpath(cad_path, "CAD_USIE.csv"),
        hydro_plants,
        submarkets,
        horizon.period_duration_hours,
        network_enabled
    )
    
    renewable_plants = read_renewable_plants(
        joinpath(cad_path, "CAD_REN.csv"),
        joinpath(oper_path, "OPER_REN.csv"),
        submarkets,
        horizon,
        network_enabled
    )
    
    operational_limits = read_operational_limits(
        joinpath(oper_path, "OPER_REST_LIM.csv"),
        thermal_plants,
        hydro_plants,
        pumping_plants,
        horizon
    )
    
    inflow_history = read_inflow_history(joinpath(oper_path, "inflow_history.parquet"))
    
    system = LDCore.System(
        horizon=horizon,
        thermal_unit_commitment_enabled=thermal_unit_commitment_enabled,
        hydro_unit_commitment_enabled=hydro_unit_commitment_enabled,
        ton_residual_enabled=ton_residual_enabled,
        fpha_enabled=fpha_enabled,
        future_cost_enabled=future_cost_enabled,
        residual_costs=residual_costs,
        future_cost_cuts=future_cost_cuts,
        submarkets=submarkets,
        interchange_limits=interchange_limits,
        operational_limits=operational_limits,
        buses=buses,
        branches=branches,
        thermal_plants=thermal_plants,
        hydro_plants=hydro_plants,
        pumping_plants=pumping_plants,
        renewable_plants=renewable_plants,
        inflow_history=inflow_history
    )
    
    LDCore.validate!(system)
    system
end
