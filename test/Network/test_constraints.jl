using Test
using LabDessem.Domain: BusId
using LabDessem.Network

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
        system = make_network_system(buses, branches)
        model = DcNetworkModel(system)

        input = FlowCutInput(0.0036)
        terms = build_flow_cut_terms(model, 1, input)
        @test isempty(terms)
    end

    @testset "build_flow_cut_terms with generator" begin
        buses = [make_test_bus(1, is_ref=true), make_test_bus(2)]
        branches = [make_test_branch(1, 1, 2)]
        system = make_network_system(buses, branches)
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
        system = make_network_system(buses, branches)
        model = DcNetworkModel(system)

        input = FlowCutInput(0.0036)
        add_thermal!(input, GeneratorEntry(bus_id=BusId(1), variable_name="gt_slack"))
        terms = build_flow_cut_terms(model, 1, input)

        @test isempty(terms)
    end
end
