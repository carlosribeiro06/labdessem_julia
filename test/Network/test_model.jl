using Test
using LabDessem.Domain: BusId
using LabDessem.Network
import LabDessem.Network: ptdf_row, ptdf_coefficient, position_of_bus, n_branches, n_buses

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
        system = make_network_system(buses, branches)

        model = DcNetworkModel(system)
        @test model.reference_bus_id == BusId(1)
        @test length(model.non_slack_bus_ids) == 2
        @test length(model.branch_ids) == 2
        @test size(model.ptdf) == (2, 2)
    end

    @testset "ptdf_row" begin
        buses = [make_test_bus(1, is_ref=true), make_test_bus(2)]
        branches = [make_test_branch(1, 1, 2)]
        system = make_network_system(buses, branches)

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
        system = make_network_system(buses, branches)

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
        system = make_network_system(buses, branches)

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
        system = make_network_system(buses, branches)

        model = DcNetworkModel(system)
        @test n_branches(model) == 2
        @test n_buses(model) == 2
    end
end
