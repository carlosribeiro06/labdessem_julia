using Test
import LabDessem.Core as LDCore
using LabDessem.Core: BusId, BranchId, SubmarketId
using LabDessem.Network

function make_test_bus(id::Int; is_ref::Bool=false, submarket::Int=1, demand::Float64=100.0)
    LDCore.Bus(
        id=BusId(id),
        name="Bus$id",
        submarket_id=SubmarketId(submarket),
        angle_reference=is_ref,
        demand_mw=[demand]
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

@testset "Duals" begin
    @testset "extract_flow_duals single" begin
        duals = [0.0, 100.0, -30.0]
        mapping = FlowCutMapping(indices=Dict((1, 1) => (1, 2)))

        result = extract_flow_duals(duals, mapping, 1)

        @test length(result) == 1
        @test result[(1, 1)] ≈ 70.0 atol=1e-9
    end

    @testset "extract_flow_duals multiple" begin
        duals = [0.0, 10.0, -5.0, 20.0, -8.0]
        mapping = FlowCutMapping(indices=Dict(
            (1, 1) => (1, 2),
            (2, 1) => (3, 4)
        ))

        result = extract_flow_duals(duals, mapping, 1)

        @test length(result) == 2
        @test result[(1, 1)] ≈ 5.0 atol=1e-9
        @test result[(2, 1)] ≈ 12.0 atol=1e-9
    end

    @testset "extract_flow_duals empty" begin
        duals = [0.0, 10.0]
        mapping = FlowCutMapping()

        result = extract_flow_duals(duals, mapping, 0)
        @test isempty(result)
    end

    @testset "compute_cmb_per_bus" begin
        buses = [
            make_test_bus(1, is_ref=true, submarket=1),
            make_test_bus(2, submarket=1, demand=50.0)
        ]
        branches = [make_test_branch(1, 1, 2)]
        system = make_minimal_system(buses, branches)
        model = DcNetworkModel(system)

        demand_duals = Dict((SubmarketId(1), 1) => 100.0)
        flow_duals = Dict((1, 1) => 10.0)

        records = compute_cmb_per_bus(system, model, demand_duals, flow_duals, [1])

        @test length(records) == 1
        @test records[1].bus_id == BusId(2)
        @test records[1].period == 1
        # PTDF(branch=1, bus=2) = -1.0, so network_component = -1.0 * 10.0 = -10.0
        @test records[1].cmb ≈ 100.0 - 10.0 atol=1e-6
    end

    @testset "compute_cmo_from_cmb" begin
        buses = [
            make_test_bus(1, is_ref=true, submarket=1, demand=0.0),
            make_test_bus(2, submarket=1, demand=100.0),
            make_test_bus(3, submarket=1, demand=100.0)
        ]
        branches = [
            make_test_branch(1, 1, 2),
            make_test_branch(2, 2, 3)
        ]
        system = make_minimal_system(buses, branches)

        cmb_records = [
            CmbRecord(bus_id=BusId(2), period=1, cmb=50.0, submarket_id=SubmarketId(1)),
            CmbRecord(bus_id=BusId(3), period=1, cmb=70.0, submarket_id=SubmarketId(1))
        ]

        cmo = compute_cmo_from_cmb(cmb_records, system)

        @test length(cmo) == 1
        expected = (50.0 * 100.0 + 70.0 * 100.0) / (100.0 + 100.0)
        @test cmo[(SubmarketId(1), 1)] ≈ expected atol=1e-9
    end

    @testset "compute_cmo_from_cmb zero demand" begin
        buses = [
            make_test_bus(1, is_ref=true, submarket=1, demand=0.0),
            make_test_bus(2, submarket=1, demand=0.0)
        ]
        branches = [make_test_branch(1, 1, 2)]
        system = make_minimal_system(buses, branches)

        cmb_records = [
            CmbRecord(bus_id=BusId(2), period=1, cmb=50.0, submarket_id=SubmarketId(1))
        ]

        cmo = compute_cmo_from_cmb(cmb_records, system)

        @test cmo[(SubmarketId(1), 1)] ≈ 50.0 atol=1e-9
    end
end
