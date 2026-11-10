# Entity-level validation functions.

function validate!(cond::ThermalInitialCondition)
    cond.generation_mw < 0 && throw(ArgumentError("ThermalInitialCondition generation_mw must be >= 0"))
    cond.time_in_state < 0 && throw(ArgumentError("ThermalInitialCondition time_in_state must be >= 0"))
    cond.time_in_ramp < 0 && throw(ArgumentError("ThermalInitialCondition time_in_ramp must be >= 0"))
    nothing
end

function validate!(unit::ThermalUnit)
    isempty(strip(unit.name)) && throw(ArgumentError("ThermalUnit name cannot be empty"))
    unit.min_generation_mw < 0 && throw(ArgumentError("ThermalUnit min_generation_mw must be >= 0"))
    unit.max_generation_mw < unit.min_generation_mw && throw(ArgumentError("ThermalUnit max_generation_mw must be >= min_generation_mw"))
    any(x -> x < 0, unit.startup_trajectory_mw) && throw(ArgumentError("ThermalUnit startup_trajectory_mw values must be >= 0"))
    any(x -> x < 0, unit.shutdown_trajectory_mw) && throw(ArgumentError("ThermalUnit shutdown_trajectory_mw values must be >= 0"))
    unit.min_up_time < 0 && throw(ArgumentError("ThermalUnit min_up_time must be >= 0"))
    unit.min_down_time < 0 && throw(ArgumentError("ThermalUnit min_down_time must be >= 0"))
    unit.startup_cost < 0 && throw(ArgumentError("ThermalUnit startup_cost must be >= 0"))
    unit.shutdown_cost < 0 && throw(ArgumentError("ThermalUnit shutdown_cost must be >= 0"))
    unit.variable_cost_per_mwh < 0 && throw(ArgumentError("ThermalUnit variable_cost_per_mwh must be >= 0"))
    validate!(unit.initial_condition)
    nothing
end

function validate!(plant::ThermalPlant)
    isempty(strip(plant.name)) && throw(ArgumentError("ThermalPlant name cannot be empty"))
    isempty(plant.units) && throw(ArgumentError("ThermalPlant units cannot be empty"))
    ids = Set{ThermalUnitId}()
    for unit in plant.units
        unit.id in ids && throw(ArgumentError("ThermalPlant has duplicate unit ID: $(unit.id)"))
        push!(ids, unit.id)
        validate!(unit)
    end
    nothing
end

function validate!(cond::HydroInitialCondition)
    cond.generation_mw < 0 && throw(ArgumentError("HydroInitialCondition generation_mw must be >= 0"))
    cond.time_in_state < 0 && throw(ArgumentError("HydroInitialCondition time_in_state must be >= 0"))
    nothing
end

function validate!(unit::HydroUnit)
    isempty(strip(unit.name)) && throw(ArgumentError("HydroUnit name cannot be empty"))
    unit.min_generation_mw < 0 && throw(ArgumentError("HydroUnit min_generation_mw must be >= 0"))
    unit.max_generation_mw < unit.min_generation_mw && throw(ArgumentError("HydroUnit max_generation_mw must be >= min_generation_mw"))
    unit.max_turbining_hm3 < 0 && throw(ArgumentError("HydroUnit max_turbining_hm3 must be >= 0"))
    unit.effective_head_m <= 0 && throw(ArgumentError("HydroUnit effective_head_m must be > 0"))
    validate!(unit.initial_condition)
    nothing
end

function validate!(group::HydroGroup)
    isempty(strip(group.name)) && throw(ArgumentError("HydroGroup name cannot be empty"))
    isempty(group.units) && throw(ArgumentError("HydroGroup units cannot be empty"))
    ids = Set{HydroUnitId}()
    for unit in group.units
        unit.id in ids && throw(ArgumentError("HydroGroup has duplicate unit ID: $(unit.id)"))
        push!(ids, unit.id)
        validate!(unit)
    end
    nothing
end

function validate!(res::Reservoir)
    res.min_volume_hm3 < 0 && throw(ArgumentError("Reservoir min_volume_hm3 must be >= 0"))
    res.max_volume_hm3 < res.min_volume_hm3 && throw(ArgumentError("Reservoir max_volume_hm3 must be >= min_volume_hm3"))
    (res.initial_volume_hm3 < res.min_volume_hm3 || res.initial_volume_hm3 > res.max_volume_hm3) &&
        throw(ArgumentError("Reservoir initial_volume_hm3 must be in [min_volume_hm3, max_volume_hm3]"))
    nothing
end

function validate!(seg::HydroFphaSegment)
    seg.segment < 1 && throw(ArgumentError("HydroFphaSegment segment must be >= 1"))
    seg.correction_factor <= 0 && throw(ArgumentError("HydroFphaSegment correction_factor must be > 0"))
    nothing
end

function validate!(plant::HydroPlant)
    isempty(strip(plant.name)) && throw(ArgumentError("HydroPlant name cannot be empty"))
    plant.spillage_cost_per_hm3 < 0 && throw(ArgumentError("HydroPlant spillage_cost_per_hm3 must be >= 0"))
    plant.turbining_cost_per_hm3 < 0 && throw(ArgumentError("HydroPlant turbining_cost_per_hm3 must be >= 0"))
    plant.specific_productivity_mw_per_m3s <= 0 && throw(ArgumentError("HydroPlant specific_productivity_mw_per_m3s must be > 0"))
    if plant.hydraulic_loss_m !== nothing && plant.hydraulic_loss_m < 0
        throw(ArgumentError("HydroPlant hydraulic_loss_m must be >= 0"))
    end
    if plant.efficiency !== nothing && (plant.efficiency <= 0 || plant.efficiency > 1)
        throw(ArgumentError("HydroPlant efficiency must be in (0, 1]"))
    end
    validate!(plant.reservoir)
    for seg in plant.fpha_segments
        validate!(seg)
    end
    for group in plant.groups
        validate!(group)
    end
    nothing
end

function validate!(s::Submarket)
    isempty(strip(s.name)) && throw(ArgumentError("Submarket name cannot be empty"))
    nothing
end

function validate!(b::Bus)
    isempty(strip(b.name)) && throw(ArgumentError("Bus name cannot be empty"))
    nothing
end

function validate!(br::Branch)
    isempty(strip(br.name)) && throw(ArgumentError("Branch name cannot be empty"))
    br.from_bus_id == br.to_bus_id && throw(ArgumentError("Branch from_bus_id must not equal to_bus_id"))
    br.reactance_pu == 0 && throw(ArgumentError("Branch reactance_pu must not be 0"))
    br.thermal_limit_mw <= 0 && throw(ArgumentError("Branch thermal_limit_mw must be > 0"))
    nothing
end

function validate!(p::PumpingPlant)
    isempty(strip(p.name)) && throw(ArgumentError("PumpingPlant name cannot be empty"))
    p.min_pumping_hm3 < 0 && throw(ArgumentError("PumpingPlant min_pumping_hm3 must be >= 0"))
    p.max_pumping_hm3 < p.min_pumping_hm3 && throw(ArgumentError("PumpingPlant max_pumping_hm3 must be >= min_pumping_hm3"))
    p.specific_consumption_mw_per_m3s <= 0 && throw(ArgumentError("PumpingPlant specific_consumption_mw_per_m3s must be > 0"))
    nothing
end

function validate!(p::RenewablePlant)
    isempty(strip(p.name)) && throw(ArgumentError("RenewablePlant name cannot be empty"))
    any(x -> x < 0, p.available_generation_mw) && throw(ArgumentError("RenewablePlant available_generation_mw values must be >= 0"))
    nothing
end

function validate!(il::InterchangeLimit)
    il.from_submarket_id == il.to_submarket_id && throw(ArgumentError("InterchangeLimit from_submarket_id must not equal to_submarket_id"))
    il.max_flow_mw < 0 && throw(ArgumentError("InterchangeLimit max_flow_mw must be >= 0"))
    il.penalty_cost_per_mwh < 0 && throw(ArgumentError("InterchangeLimit penalty_cost_per_mwh must be >= 0"))
    nothing
end

function validate!(rc::ResidualCost)
    rc.cmo_per_mwh < 0 && throw(ArgumentError("ResidualCost cmo_per_mwh must be >= 0"))
    nothing
end

function validate!(cut::FutureCostCut)
    isempty(cut.coefficients) && throw(ArgumentError("FutureCostCut coefficients cannot be empty"))
    nothing
end

function validate!(h::StudyHorizon)
    h.periods < 1 && throw(ArgumentError("StudyHorizon periods must be >= 1"))
    h.period_duration_hours <= 0 && throw(ArgumentError("StudyHorizon period_duration_hours must be > 0"))
    h.original_periods < 1 && throw(ArgumentError("StudyHorizon original_periods must be >= 1"))
    length(h.original_period_durations_hours) != h.original_periods &&
        throw(ArgumentError("StudyHorizon original_period_durations_hours length must equal original_periods"))
    any(x -> x <= 0, h.original_period_durations_hours) &&
        throw(ArgumentError("StudyHorizon original_period_durations_hours values must be > 0"))
    length(h.internal_to_original_period) != h.periods &&
        throw(ArgumentError("StudyHorizon internal_to_original_period length must equal periods"))
    any(x -> x < 1 || x > h.original_periods, h.internal_to_original_period) &&
        throw(ArgumentError("StudyHorizon internal_to_original_period values must be in 1:original_periods"))
    length(h.internal_subperiod_index) != h.periods &&
        throw(ArgumentError("StudyHorizon internal_subperiod_index length must equal periods"))
    nothing
end

function validate!(ol::OperationalLimit)
    ol.start_period < 1 && throw(ArgumentError("OperationalLimit start_period must be >= 1"))
    ol.end_period < ol.start_period && throw(ArgumentError("OperationalLimit end_period must be >= start_period"))
    ol.lower_bound === nothing && ol.upper_bound === nothing &&
        throw(ArgumentError("OperationalLimit must have at least one bound"))
    if ol.lower_bound !== nothing && ol.upper_bound !== nothing && ol.lower_bound > ol.upper_bound
        throw(ArgumentError("OperationalLimit lower_bound must be <= upper_bound"))
    end
    nothing
end


# System-level validation

function validate!(system::System)
    # 1. Entity-level validation
    validate!(system.horizon)
    for submarket in system.submarkets
        validate!(submarket)
    end
    for bus in system.buses
        validate!(bus)
    end
    for branch in system.branches
        validate!(branch)
    end
    for plant in system.thermal_plants
        validate!(plant)
    end
    for plant in system.hydro_plants
        validate!(plant)
    end
    for plant in system.pumping_plants
        validate!(plant)
    end
    for plant in system.renewable_plants
        validate!(plant)
    end
    for il in system.interchange_limits
        validate!(il)
    end
    for rc in system.residual_costs
        validate!(rc)
    end
    for cut in system.future_cost_cuts
        validate!(cut)
    end
    for ol in system.operational_limits
        validate!(ol)
    end

    # 2. Unique IDs
    submarket_ids = Set{SubmarketId}()
    for s in system.submarkets
        s.id in submarket_ids && throw(ArgumentError("duplicate Submarket ID: $(s.id)"))
        push!(submarket_ids, s.id)
    end

    bus_ids = Set{BusId}()
    for b in system.buses
        b.id in bus_ids && throw(ArgumentError("duplicate Bus ID: $(b.id)"))
        push!(bus_ids, b.id)
    end

    branch_ids = Set{BranchId}()
    for br in system.branches
        br.id in branch_ids && throw(ArgumentError("duplicate Branch ID: $(br.id)"))
        push!(branch_ids, br.id)
    end

    thermal_plant_ids = Set{ThermalPlantId}()
    for plant in system.thermal_plants
        plant.id in thermal_plant_ids && throw(ArgumentError("duplicate ThermalPlant ID: $(plant.id)"))
        push!(thermal_plant_ids, plant.id)
        unit_ids_in_plant = Set{ThermalUnitId}()
        for unit in plant.units
            unit.id in unit_ids_in_plant && throw(ArgumentError("duplicate ThermalUnit ID: $(unit.id) within plant $(plant.id)"))
            push!(unit_ids_in_plant, unit.id)
        end
    end

    hydro_plant_ids = Set{HydroPlantId}()
    for plant in system.hydro_plants
        plant.id in hydro_plant_ids && throw(ArgumentError("duplicate HydroPlant ID: $(plant.id)"))
        push!(hydro_plant_ids, plant.id)
        group_ids_in_plant = Set{HydroGroupId}()
        for group in plant.groups
            group.id in group_ids_in_plant && throw(ArgumentError("duplicate HydroGroup ID: $(group.id) within plant $(plant.id)"))
            push!(group_ids_in_plant, group.id)
            unit_ids_in_group = Set{HydroUnitId}()
            for unit in group.units
                unit.id in unit_ids_in_group && throw(ArgumentError("duplicate HydroUnit ID: $(unit.id) within group $(group.id)"))
                push!(unit_ids_in_group, unit.id)
            end
        end
    end

    pumping_plant_ids = Set{PumpingPlantId}()
    for plant in system.pumping_plants
        plant.id in pumping_plant_ids && throw(ArgumentError("duplicate PumpingPlant ID: $(plant.id)"))
        push!(pumping_plant_ids, plant.id)
    end

    renewable_plant_ids = Set{RenewablePlantId}()
    for plant in system.renewable_plants
        plant.id in renewable_plant_ids && throw(ArgumentError("duplicate RenewablePlant ID: $(plant.id)"))
        push!(renewable_plant_ids, plant.id)
    end

    # 3. Cross-reference validation
    for bus in system.buses
        bus.submarket_id in submarket_ids || throw(ArgumentError("Bus $(bus.id) references non-existent submarket_id $(bus.submarket_id)"))
    end

    for plant in system.thermal_plants
        plant.submarket_id in submarket_ids || throw(ArgumentError("ThermalPlant $(plant.id) references non-existent submarket_id $(plant.submarket_id)"))
        plant.bus_id in bus_ids || throw(ArgumentError("ThermalPlant $(plant.id) references non-existent bus_id $(plant.bus_id)"))
    end

    for plant in system.hydro_plants
        plant.submarket_id in submarket_ids || throw(ArgumentError("HydroPlant $(plant.id) references non-existent submarket_id $(plant.submarket_id)"))
        plant.bus_id in bus_ids || throw(ArgumentError("HydroPlant $(plant.id) references non-existent bus_id $(plant.bus_id)"))
    end

    for branch in system.branches
        branch.from_bus_id in bus_ids || throw(ArgumentError("Branch $(branch.id) references non-existent from_bus_id $(branch.from_bus_id)"))
        branch.to_bus_id in bus_ids || throw(ArgumentError("Branch $(branch.id) references non-existent to_bus_id $(branch.to_bus_id)"))
    end

    for plant in system.pumping_plants
        plant.submarket_id in submarket_ids || throw(ArgumentError("PumpingPlant $(plant.id) references non-existent submarket_id $(plant.submarket_id)"))
        plant.bus_id in bus_ids || throw(ArgumentError("PumpingPlant $(plant.id) references non-existent bus_id $(plant.bus_id)"))
        plant.downstream_hydro_id in hydro_plant_ids || throw(ArgumentError("PumpingPlant $(plant.id) references non-existent downstream_hydro_id $(plant.downstream_hydro_id)"))
        plant.upstream_hydro_id in hydro_plant_ids || throw(ArgumentError("PumpingPlant $(plant.id) references non-existent upstream_hydro_id $(plant.upstream_hydro_id)"))
    end

    for plant in system.renewable_plants
        plant.submarket_id in submarket_ids || throw(ArgumentError("RenewablePlant $(plant.id) references non-existent submarket_id $(plant.submarket_id)"))
        plant.bus_id in bus_ids || throw(ArgumentError("RenewablePlant $(plant.id) references non-existent bus_id $(plant.bus_id)"))
    end

    # 4. Cascade consistency
    hydro_map = Dict(p.id => p for p in system.hydro_plants)
    for plant in system.hydro_plants
        for upstream_id in plant.upstream_plant_ids
            upstream_id in hydro_plant_ids || throw(ArgumentError("HydroPlant $(plant.id) references non-existent upstream plant $(upstream_id)"))
            upstream = hydro_map[upstream_id]
            upstream.downstream_plant_id == plant.id || throw(ArgumentError("Cascade inconsistency: HydroPlant $(plant.id) lists $(upstream_id) as upstream but $(upstream_id) does not list $(plant.id) as downstream"))
        end
        if plant.downstream_plant_id !== nothing
            downstream_id = plant.downstream_plant_id
            downstream_id in hydro_plant_ids || throw(ArgumentError("HydroPlant $(plant.id) references non-existent downstream plant $(downstream_id)"))
            downstream = hydro_map[downstream_id]
            plant.id in downstream.upstream_plant_ids || throw(ArgumentError("Cascade inconsistency: HydroPlant $(plant.id) lists $(downstream_id) as downstream but $(downstream_id) does not list $(plant.id) as upstream"))
        end
    end

    # 5. Diversion consistency
    for plant in system.hydro_plants
        for div_upstream_id in plant.diversion_upstream_plant_ids
            div_upstream_id in hydro_plant_ids || throw(ArgumentError("HydroPlant $(plant.id) references non-existent diversion upstream plant $(div_upstream_id)"))
            div_upstream = hydro_map[div_upstream_id]
            div_upstream.diversion_plant_id == plant.id || throw(ArgumentError("Diversion inconsistency: HydroPlant $(plant.id) lists $(div_upstream_id) as diversion upstream but $(div_upstream_id) does not list $(plant.id) as diversion destination"))
        end
        if plant.diversion_plant_id !== nothing
            div_id = plant.diversion_plant_id
            div_id in hydro_plant_ids || throw(ArgumentError("HydroPlant $(plant.id) references non-existent diversion plant $(div_id)"))
            div_plant = hydro_map[div_id]
            plant.id in div_plant.diversion_upstream_plant_ids || throw(ArgumentError("Diversion inconsistency: HydroPlant $(plant.id) lists $(div_id) as diversion destination but $(div_id) does not list $(plant.id) as diversion upstream"))
        end
    end

    # 6. Horizon consistency
    periods = system.horizon.periods
    for s in system.submarkets
        length(s.demand_mw) == periods || throw(ArgumentError("Submarket $(s.id) demand_mw length $(length(s.demand_mw)) != horizon.periods $(periods)"))
    end
    for b in system.buses
        length(b.demand_mw) == periods || throw(ArgumentError("Bus $(b.id) demand_mw length $(length(b.demand_mw)) != horizon.periods $(periods)"))
    end
    for plant in system.hydro_plants
        length(plant.natural_inflow_hm3) == periods || throw(ArgumentError("HydroPlant $(plant.id) natural_inflow_hm3 length != horizon.periods"))
        length(plant.water_withdrawal_hm3) == periods || throw(ArgumentError("HydroPlant $(plant.id) water_withdrawal_hm3 length != horizon.periods"))
    end
    for plant in system.renewable_plants
        length(plant.available_generation_mw) == periods || throw(ArgumentError("RenewablePlant $(plant.id) available_generation_mw length != horizon.periods"))
    end

    # 7. Slack bus
    slack_count = count(b -> b.angle_reference, system.buses)
    slack_count == 1 || throw(ArgumentError("System must have exactly one slack bus (angle_reference=true), found $(slack_count)"))

    # 8. TON residual
    if system.ton_residual_enabled
        rc_submarkets = Set(rc.submarket_id for rc in system.residual_costs)
        for s in system.submarkets
            s.id in rc_submarkets || throw(ArgumentError("TON residual enabled but no ResidualCost for submarket $(s.id)"))
        end
    end

    # 9. FCF
    if system.future_cost_enabled
        isempty(system.future_cost_cuts) && throw(ArgumentError("Future cost enabled but future_cost_cuts is empty"))
        n_hydro = length(system.hydro_plants)
        for cut in system.future_cost_cuts
            length(cut.coefficients) == n_hydro || throw(ArgumentError("FutureCostCut $(cut.cut_id) coefficients length $(length(cut.coefficients)) != hydro_plants count $(n_hydro)"))
        end
    end

    # 10. FPHA
    if system.fpha_enabled
        for plant in system.hydro_plants
            if !isempty(plant.groups) && isempty(plant.fpha_segments)
                throw(ArgumentError("FPHA enabled but HydroPlant $(plant.id) has groups but no fpha_segments"))
            end
        end
    end

    # 11. Operational limits
    for ol in system.operational_limits
        ol.start_period >= 1 && ol.start_period <= periods || throw(ArgumentError("OperationalLimit start_period $(ol.start_period) out of range 1:$(periods)"))
        ol.end_period >= ol.start_period && ol.end_period <= periods || throw(ArgumentError("OperationalLimit end_period $(ol.end_period) out of range"))
        
        if ol.target isa ThermalPlantTarget
            ol.target.id in thermal_plant_ids || throw(ArgumentError("OperationalLimit references non-existent ThermalPlant $(ol.target.id)"))
        elseif ol.target isa ThermalUnitTarget
            ol.target.plant_id in thermal_plant_ids || throw(ArgumentError("OperationalLimit references non-existent ThermalPlant $(ol.target.plant_id)"))
            ol.target.unit_id in thermal_unit_ids || throw(ArgumentError("OperationalLimit references non-existent ThermalUnit $(ol.target.unit_id)"))
        elseif ol.target isa HydroPlantTarget
            ol.target.id in hydro_plant_ids || throw(ArgumentError("OperationalLimit references non-existent HydroPlant $(ol.target.id)"))
        elseif ol.target isa HydroUnitTarget
            ol.target.plant_id in hydro_plant_ids || throw(ArgumentError("OperationalLimit references non-existent HydroPlant $(ol.target.plant_id)"))
            ol.target.unit_id in hydro_unit_ids || throw(ArgumentError("OperationalLimit references non-existent HydroUnit $(ol.target.unit_id)"))
        elseif ol.target isa PumpingPlantTarget
            ol.target.id in pumping_plant_ids || throw(ArgumentError("OperationalLimit references non-existent PumpingPlant $(ol.target.id)"))
            ol.variable == Pumping || throw(ArgumentError("PumpingPlantTarget can only have Pumping variable"))
        end

        if ol.target isa ThermalPlantTarget || ol.target isa ThermalUnitTarget
            ol.variable == Generation || throw(ArgumentError("ThermalPlant/Unit can only have Generation variable"))
        end
        
        if ol.target isa PumpingPlantTarget && ol.variable != Pumping
            throw(ArgumentError("PumpingPlantTarget can only have Pumping variable"))
        end
    end

    nothing
end
