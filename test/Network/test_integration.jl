using Test
import LabDessem.Core as LDCore
using LabDessem.Core: BusId, BranchId, SubmarketId
using LabDessem.Network

function build_3bus_network()
    buses = [
        LDCore.Bus(
            id=BusId(1),
            name="Bus1",
            submarket_id=SubmarketId(1),
            angle_reference=true,
            demand_mw=[0.0]
        ),
        LDCore.Bus(
            id=BusId(2),
            name="Bus2",
            submarket_id=SubmarketId(1),
            angle_reference=false,
            demand_mw=[100.0]
        ),
        LDCore.Bus(
            id=BusId(3),
            name="Bus3",
            submarket_id=SubmarketId(2),
            angle_reference=false,
            demand_mw=[150.0]
        )
    ]

    branches = [
        LDCore.Branch(
            id=BranchId(1),
            name="L1-2",
            from_bus_id=BusId(1),
            to_bus_id=BusId(2),
            reactance_pu=0.1,
            thermal_limit_mw=80.0
        ),
        LDCore.Branch(
            id=BranchId(2),
            name="L1-3",
            from_bus_id=BusId(1),
            to_bus_id=BusId(3),
            reactance_pu=0.2,
            thermal_limit_mw=120.0
        ),
        LDCore.Branch(
            id=BranchId(3),
            name="L2-3",
            from_bus_id=BusId(2),
            to_bus_id=BusId(3),
            reactance_pu=0.15,
            thermal_limit_mw=60.0
        )
    ]

    horizon = LDCore.StudyHorizon(
        periods=2,
        period_duration_hours=1.0,
        original_periods=2,
        original_period_durations_hours=[1.0, 1.0],
        internal_to_original_period=[1, 2],
        internal_subperiod_index=[1, 1]
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

@testset "Integration" begin
    @testset "full DC network pipeline" begin
        system = build_3bus_network()
        model = DcNetworkModel(system)

        @test n_buses(model) == 2
        @test n_branches(model) == 3
        @test reference_bus(model) == BusId(1)

        injections = [50.0 40.0; 100.0 90.0]  # [bus_pos, period]
        flows = compute_line_flows(system, model, injections)

        @test length(flows) == 6  # 3 branches × 2 periods

        period1_flows = filter(f -> f.period == 1, flows)
        @test length(period1_flows) == 3

        violations = detect_flow_violations(system, model, injections)
        @test all(v -> abs(v.flow_mw) > v.limit_mw, violations)
    end

    @testset "constraint generation pipeline" begin
        system = build_3bus_network()
        model = DcNetworkModel(system)

        input = FlowCutInput(0.0036)
        add_thermal!(input, GeneratorEntry(bus_id=BusId(2), variable_name="gt_1"))
        add_hydro!(input, GeneratorEntry(bus_id=BusId(3), variable_name="gh_1"))

        terms = build_flow_cut_terms(model, 1, input)

        @test length(terms) == 2
        @test any(t -> t.variable_name == "gt_1", terms)
        @test any(t -> t.variable_name == "gh_1", terms)
    end

    @testset "dual extraction pipeline" begin
        system = build_3bus_network()
        model = DcNetworkModel(system)

        duals = [0.0, 5.0, -3.0, 2.0, -1.0]
        mapping = FlowCutMapping(indices=Dict(
            (1, 1) => (1, 2),
            (2, 1) => (3, 4)
        ))

        flow_duals = extract_flow_duals(duals, mapping, 1)

        @test length(flow_duals) == 2
        @test flow_duals[(1, 1)] ≈ 2.0 atol=1e-9
        @test flow_duals[(2, 1)] ≈ 1.0 atol=1e-9

        demand_duals = Dict(
            (SubmarketId(1), 1) => 50.0,
            (SubmarketId(2), 1) => 60.0
        )

        cmb_records = compute_cmb_per_bus(system, model, demand_duals, flow_duals, [1])
        @test length(cmb_records) == 2

        cmo = compute_cmo_from_cmb(cmb_records, system)
        @test length(cmo) == 2
        @test haskey(cmo, (SubmarketId(1), 1))
        @test haskey(cmo, (SubmarketId(2), 1))
    end

    @testset "topology consistency" begin
        system = build_3bus_network()
        model = DcNetworkModel(system)

        for branch_idx in 1:n_branches(model)
            row = ptdf_row(model, branch_idx)
            @test length(row) == n_buses(model)
        end

        for bus_pos in 1:n_buses(model)
            col = ptdf_column(model, bus_pos)
            @test length(col) == n_branches(model)
        end
    end

    @testset "flow constraints enumeration" begin
        system = build_3bus_network()
        keys = all_flow_constraints(system)

        @test length(keys) == 6  # 3 branches × 2 periods
        @test count(k -> k.period == 1, keys) == 3
        @test count(k -> k.period == 2, keys) == 3
    end

    @testset "constant load shift" begin
        system = build_3bus_network()
        model = DcNetworkModel(system)

        # Each bus contributes a load shift based on PTDF coefficients
        shift_b1 = constant_load_shift(system, model, 1, 1)
        shift_b2 = constant_load_shift(system, model, 1, 2)

        # Both shifts should be finite values
        @test isfinite(shift_b1)
        @test isfinite(shift_b2)
    end
end
