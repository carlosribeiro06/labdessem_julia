using Test
import LabDessem.Core as LDCore
using LabDessem.Core: BusId, BranchId, SubmarketId
using LabDessem.Network

function make_test_bus(id::Int; is_ref::Bool=false, submarket::Int=1)
    LDCore.Bus(
        id=BusId(id),
        name="Bus$id",
        submarket_id=SubmarketId(submarket),
        angle_reference=is_ref,
        demand_mw=[100.0]
    )
end

function make_test_branch(id::Int, from::Int, to::Int; x::Float64=0.1, limit::Float64=100.0)
    LDCore.Branch(
        id=BranchId(id),
        name="L$id",
        from_bus_id=BusId(from),
        to_bus_id=BusId(to),
        reactance_pu=x,
        thermal_limit_mw=limit
    )
end

function make_minimal_system(buses::Vector{LDCore.Bus}, branches::Vector{LDCore.Branch})
    horizon = LDCore.StudyHorizon(
        periods=1,
        period_duration_hours=1.0,
        original_periods=1,
        original_period_durations_hours=[1.0],
        internal_to_original_period=[1],
        internal_subperiod_index=[1]
    )
    LDCore.System(
        horizon=horizon,
        thermal_unit_commitment_enabled=false,
        hydro_unit_commitment_enabled=false,
        ton_residual_enabled=false,
        fpha_enabled=false,
        future_cost_enabled=false,
        residual_costs=LDCore.ResidualCost[],
        future_cost_cuts=LDCore.FutureCostCut[],
        submarkets=LDCore.Submarket[],
        interchange_limits=LDCore.InterchangeLimit[],
        operational_limits=LDCore.OperationalLimit[],
        buses=buses,
        branches=branches,
        thermal_plants=LDCore.ThermalPlant[],
        hydro_plants=LDCore.HydroPlant[],
        pumping_plants=LDCore.PumpingPlant[],
        renewable_plants=LDCore.RenewablePlant[],
        inflow_history=LDCore.InflowHistoryRow[]
    )
end

@testset "Constraints" begin
    @testset "GeneratorEntry" begin
        entry = GeneratorEntry(bus_id=BusId(1), variable_name="gt_1")
        @test entry.bus_id == BusId(1)
        @test entry.variable_name == "gt_1"
    end

    @testset "PumpingEntry" begin
        entry = PumpingEntry(
            bus_id=BusId(2),
            variable_name="pump_1",
            specific_consumption_mw_per_m3s=1.5
        )
        @test entry.bus_id == BusId(2)
        @test entry.specific_consumption_mw_per_m3s ≈ 1.5
    end

    @testset "FlowCutInput construction" begin
        input = FlowCutInput(0.0036)
        @test isempty(input.thermal_entries)
        @test input.flow_conversion ≈ 0.0036
    end

    @testset "FlowCutInput add entries" begin
        input = FlowCutInput(0.0036)
        add_thermal!(input, GeneratorEntry(bus_id=BusId(1), variable_name="th_1"))
        add_hydro!(input, GeneratorEntry(bus_id=BusId(2), variable_name="hy_1"))
        add_renewable!(input, GeneratorEntry(bus_id=BusId(3), variable_name="ren_1"))
        add_pumping!(input, PumpingEntry(bus_id=BusId(4), variable_name="pump_1", specific_consumption_mw_per_m3s=1.0))

        @test length(input.thermal_entries) == 1
        @test length(input.hydro_entries) == 1
        @test length(input.renewable_entries) == 1
        @test length(input.pumping_entries) == 1
    end

    @testset "build_flow_cut_terms empty input" begin
        buses = [make_test_bus(1, is_ref=true), make_test_bus(2)]
        branches = [make_test_branch(1, 1, 2)]
        system = make_minimal_system(buses, branches)
        model = DcNetworkModel(system)

        input = FlowCutInput(0.0036)
        terms = build_flow_cut_terms(model, 1, input)
        @test isempty(terms)
    end

    @testset "build_flow_cut_terms with generator" begin
        buses = [make_test_bus(1, is_ref=true), make_test_bus(2)]
        branches = [make_test_branch(1, 1, 2)]
        system = make_minimal_system(buses, branches)
        model = DcNetworkModel(system)

        input = FlowCutInput(0.0036)
        add_thermal!(input, GeneratorEntry(bus_id=BusId(2), variable_name="gt_1"))
        terms = build_flow_cut_terms(model, 1, input)

        @test length(terms) == 1
        @test terms[1].variable_name == "gt_1"
        @test abs(terms[1].coefficient) ≈ 1.0 atol=1e-9
    end

    @testset "build_flow_cut_terms generator at slack skipped" begin
        buses = [make_test_bus(1, is_ref=true), make_test_bus(2)]
        branches = [make_test_branch(1, 1, 2)]
        system = make_minimal_system(buses, branches)
        model = DcNetworkModel(system)

        input = FlowCutInput(0.0036)
        add_thermal!(input, GeneratorEntry(bus_id=BusId(1), variable_name="gt_slack"))
        terms = build_flow_cut_terms(model, 1, input)

        @test isempty(terms)
    end
end
