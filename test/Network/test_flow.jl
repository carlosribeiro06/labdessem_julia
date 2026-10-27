using Test
import LabDessem.Core as LDCore
using LabDessem.Core: BusId, BranchId, SubmarketId
using LabDessem.Network
import LabDessem.Network: round_to_digits, dot, bus_name

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

@testset "Flow" begin
    @testset "round_to_digits" begin
        @test round_to_digits(1.2345, 2) ≈ 1.23
        @test round_to_digits(1.2355, 2) ≈ 1.24
        @test round_to_digits(-1.2345, 2) ≈ -1.23
        @test round_to_digits(3.14159, 0) ≈ 3.0
    end

    @testset "dot" begin
        @test dot([1.0, 2.0, 3.0], [4.0, 5.0, 6.0]) ≈ 32.0
        @test dot(Float64[], Float64[]) ≈ 0.0
    end

    @testset "compute_line_flows" begin
        buses = [make_test_bus(1, is_ref=true), make_test_bus(2)]
        branches = [make_test_branch(1, 1, 2)]
        system = make_minimal_system(buses, branches)
        model = DcNetworkModel(system)

        injections = reshape([50.0], 1, 1)
        flows = compute_line_flows(system, model, injections)

        @test length(flows) == 1
        @test flows[1].branch_id == BranchId(1)
        @test flows[1].period == 1
        @test abs(flows[1].flow_mw) ≈ 50.0 atol=1e-6
    end

    @testset "detect_flow_violations" begin
        buses = [make_test_bus(1, is_ref=true), make_test_bus(2)]
        branches = [make_test_branch(1, 1, 2, limit=40.0)]
        system = make_minimal_system(buses, branches)
        model = DcNetworkModel(system)

        injections = reshape([50.0], 1, 1)
        violations = detect_flow_violations(system, model, injections)

        @test length(violations) == 1
        @test violations[1].limit_mw == 40.0
        @test abs(violations[1].flow_mw) > violations[1].limit_mw
    end

    @testset "detect_flow_violations no violation" begin
        buses = [make_test_bus(1, is_ref=true), make_test_bus(2)]
        branches = [make_test_branch(1, 1, 2, limit=100.0)]
        system = make_minimal_system(buses, branches)
        model = DcNetworkModel(system)

        injections = reshape([50.0], 1, 1)
        violations = detect_flow_violations(system, model, injections)

        @test isempty(violations)
    end

    @testset "all_flow_constraints" begin
        buses = [make_test_bus(1, is_ref=true), make_test_bus(2)]
        branches = [make_test_branch(1, 1, 2), make_test_branch(2, 1, 2)]
        system = make_minimal_system(buses, branches)

        keys = all_flow_constraints(system)
        @test length(keys) == 2
    end

    @testset "constant_load_shift" begin
        buses = [make_test_bus(1, is_ref=true), make_test_bus(2, demand=100.0)]
        branches = [make_test_branch(1, 1, 2)]
        system = make_minimal_system(buses, branches)
        model = DcNetworkModel(system)

        shift = constant_load_shift(system, model, 1, 1)
        @test abs(shift) ≈ 100.0 atol=1e-6
    end
end
