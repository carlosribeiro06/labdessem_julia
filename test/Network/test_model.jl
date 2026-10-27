using Test
import LabDessem.Core as LDCore
using LabDessem.Core: BusId, BranchId, SubmarketId
using LabDessem.Network
import LabDessem.Network: ptdf_row, ptdf_coefficient, position_of_bus, n_branches, n_buses

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

@testset "DcNetworkModel" begin
    @testset "construction" begin
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

        model = DcNetworkModel(system)
        @test model.reference_bus_id == BusId(1)
        @test length(model.non_slack_bus_ids) == 2
        @test length(model.branch_ids) == 2
        @test size(model.ptdf) == (2, 2)
    end

    @testset "ptdf_row" begin
        buses = [make_test_bus(1, is_ref=true), make_test_bus(2)]
        branches = [make_test_branch(1, 1, 2)]
        system = make_minimal_system(buses, branches)

        model = DcNetworkModel(system)
        row = ptdf_row(model, 1)
        @test length(row) == 1
        @test abs(row[1]) ≈ 1.0 atol=1e-10
    end

    @testset "ptdf_coefficient" begin
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

        model = DcNetworkModel(system)
        coef = ptdf_coefficient(model, 1, BusId(2))
        @test abs(coef) > 0.0

        coef_ref = ptdf_coefficient(model, 1, BusId(1))
        @test coef_ref == 0.0

        coef_unknown = ptdf_coefficient(model, 1, BusId(99))
        @test coef_unknown == 0.0
    end

    @testset "position_of_bus" begin
        buses = [make_test_bus(1, is_ref=true), make_test_bus(2)]
        branches = [make_test_branch(1, 1, 2)]
        system = make_minimal_system(buses, branches)

        model = DcNetworkModel(system)
        @test position_of_bus(model, BusId(2)) == 1
        @test position_of_bus(model, BusId(1)) === nothing
        @test position_of_bus(model, BusId(99)) === nothing
    end

    @testset "n_branches and n_buses" begin
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

        model = DcNetworkModel(system)
        @test n_branches(model) == 2
        @test n_buses(model) == 2
    end
end
