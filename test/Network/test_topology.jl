using Test
import LabDessem.Core as LDCore
using LabDessem.Core: BusId, BranchId, SubmarketId
using LabDessem.Network
import LabDessem.Network: find_reference_bus, build_non_slack_bus_mapping
import LabDessem.Network: build_incidence_matrix, build_susceptance_matrix
import LabDessem.Network: build_branch_susceptance_diag, compute_ptdf

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

@testset "Topology" begin
    @testset "find_reference_bus" begin
        buses = [
            make_test_bus(1, is_ref=true),
            make_test_bus(2),
            make_test_bus(3)
        ]
        branches = [make_test_branch(1, 1, 2)]
        system = make_minimal_system(buses, branches)

        ref = find_reference_bus(system)
        @test ref.id == BusId(1)
        @test ref.angle_reference == true
    end

    @testset "find_reference_bus throws on missing" begin
        buses = [make_test_bus(1), make_test_bus(2)]
        branches = [make_test_branch(1, 1, 2)]
        system = make_minimal_system(buses, branches)
        @test_throws NoReferenceBusError find_reference_bus(system)
    end

    @testset "build_non_slack_bus_mapping" begin
        buses = [
            make_test_bus(1, is_ref=true),
            make_test_bus(2),
            make_test_bus(3)
        ]
        branches = [make_test_branch(1, 1, 2)]
        system = make_minimal_system(buses, branches)

        bus_to_pos, non_slack_ids = build_non_slack_bus_mapping(system, BusId(1))
        @test length(bus_to_pos) == 2
        @test length(non_slack_ids) == 2
        @test BusId(2) in non_slack_ids
        @test BusId(3) in non_slack_ids
        @test !(BusId(1) in non_slack_ids)
    end

    @testset "build_incidence_matrix 3-bus radial" begin
        buses = [
            make_test_bus(1, is_ref=true),
            make_test_bus(2),
            make_test_bus(3)
        ]
        branches = [
            make_test_branch(1, 1, 2),
            make_test_branch(2, 2, 3)
        ]
        system = make_minimal_system(buses, branches)

        bus_to_pos, _ = build_non_slack_bus_mapping(system, BusId(1))
        A = build_incidence_matrix(system, bus_to_pos)

        @test size(A) == (2, 2)
        @test A[1, bus_to_pos[BusId(2)]] == -1.0
        @test A[2, bus_to_pos[BusId(2)]] == 1.0
        @test A[2, bus_to_pos[BusId(3)]] == -1.0
    end

    @testset "build_incidence_matrix no branches throws" begin
        buses = [make_test_bus(1, is_ref=true), make_test_bus(2)]
        system = make_minimal_system(buses, LDCore.Branch[])
        bus_to_pos, _ = build_non_slack_bus_mapping(system, BusId(1))
        @test_throws NoBranchesError build_incidence_matrix(system, bus_to_pos)
    end

    @testset "build_susceptance_matrix 2-bus" begin
        buses = [make_test_bus(1, is_ref=true), make_test_bus(2)]
        branches = [make_test_branch(1, 1, 2, x=0.1)]
        system = make_minimal_system(buses, branches)

        bus_to_pos, _ = build_non_slack_bus_mapping(system, BusId(1))
        B = build_susceptance_matrix(system, bus_to_pos)

        @test size(B) == (1, 1)
        @test B[1, 1] ≈ 10.0 atol=1e-10
    end

    @testset "build_susceptance_matrix 3-bus radial" begin
        buses = [
            make_test_bus(1, is_ref=true),
            make_test_bus(2),
            make_test_bus(3)
        ]
        branches = [
            make_test_branch(1, 1, 2, x=0.1),
            make_test_branch(2, 2, 3, x=0.2)
        ]
        system = make_minimal_system(buses, branches)

        bus_to_pos, _ = build_non_slack_bus_mapping(system, BusId(1))
        B = build_susceptance_matrix(system, bus_to_pos)

        @test size(B) == (2, 2)
        @test B ≈ B' atol=1e-10
        @test B[bus_to_pos[BusId(2)], bus_to_pos[BusId(2)]] ≈ 10.0 + 5.0 atol=1e-10
        @test B[bus_to_pos[BusId(3)], bus_to_pos[BusId(3)]] ≈ 5.0 atol=1e-10
        @test B[bus_to_pos[BusId(2)], bus_to_pos[BusId(3)]] ≈ -5.0 atol=1e-10
    end

    @testset "build_branch_susceptance_diag" begin
        buses = [make_test_bus(1, is_ref=true), make_test_bus(2), make_test_bus(3)]
        branches = [
            make_test_branch(1, 1, 2, x=0.1),
            make_test_branch(2, 2, 3, x=0.2),
            make_test_branch(3, 1, 3, x=0.5)
        ]
        system = make_minimal_system(buses, branches)

        D = build_branch_susceptance_diag(system)
        @test D[1, 1] ≈ 10.0 atol=1e-10
        @test D[2, 2] ≈ 5.0 atol=1e-10
        @test D[3, 3] ≈ 2.0 atol=1e-10
    end

    @testset "compute_ptdf 2-bus system" begin
        buses = [make_test_bus(1, is_ref=true), make_test_bus(2)]
        branches = [make_test_branch(1, 1, 2, x=0.1)]
        system = make_minimal_system(buses, branches)

        ptdf, bus_to_pos, non_slack_ids, ref_id = compute_ptdf(system)
        @test ref_id == BusId(1)
        @test size(ptdf) == (1, 1)
        @test abs(ptdf[1, 1]) ≈ 1.0 atol=1e-10
    end

    @testset "compute_ptdf 3-bus radial" begin
        buses = [
            make_test_bus(1, is_ref=true),
            make_test_bus(2),
            make_test_bus(3)
        ]
        branches = [
            make_test_branch(1, 1, 2, x=0.1),
            make_test_branch(2, 2, 3, x=0.1)
        ]
        system = make_minimal_system(buses, branches)

        ptdf, bus_to_pos, non_slack_ids, ref_id = compute_ptdf(system)
        @test size(ptdf) == (2, 2)

        pos2 = bus_to_pos[BusId(2)]
        pos3 = bus_to_pos[BusId(3)]
        @test abs(ptdf[1, pos2]) ≈ 1.0 atol=1e-10
        @test abs(ptdf[1, pos3]) ≈ 1.0 atol=1e-10
        @test abs(ptdf[2, pos2]) < 1e-10
        @test abs(ptdf[2, pos3]) ≈ 1.0 atol=1e-10
    end
end
