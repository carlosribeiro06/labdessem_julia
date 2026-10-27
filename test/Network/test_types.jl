using Test
using LabDessem.Core
using LabDessem.Network

@testset "Network Types" begin
    @testset "ConstraintSense enum" begin
        @test LessThanOrEqual isa ConstraintSense
        @test GreaterThanOrEqual isa ConstraintSense
        @test Equal isa ConstraintSense
        @test instances(ConstraintSense) == (LessThanOrEqual, GreaterThanOrEqual, Equal)
    end

    @testset "FlowViolation" begin
        v = FlowViolation(
            branch_id=BranchId(1),
            branch_name="L1",
            period=1,
            flow_mw=100.0,
            limit_mw=90.0
        )
        @test v.branch_id == BranchId(1)
        @test v.branch_name == "L1"
        @test v.period == 1
        @test v.flow_mw == 100.0
        @test v.limit_mw == 90.0
    end

    @testset "LineFlowResult" begin
        r = LineFlowResult(
            branch_id=BranchId(1),
            branch_name="L1",
            from_bus_name="Bus1",
            to_bus_name="Bus2",
            period=1,
            flow_mw=50.0,
            limit_mw=100.0
        )
        @test r.branch_id == BranchId(1)
        @test r.from_bus_name == "Bus1"
        @test r.to_bus_name == "Bus2"
    end

    @testset "AddedFlowCutLineResult" begin
        r = AddedFlowCutLineResult(
            branch_id=BranchId(1),
            branch_name="L1",
            from_bus_id=BusId(1),
            to_bus_id=BusId(2),
            flow_mw=50.0,
            limit_mw=100.0
        )
        @test r.from_bus_id == BusId(1)
        @test r.to_bus_id == BusId(2)
    end

    @testset "NetworkTerm" begin
        t = NetworkTerm(variable_name="x", coefficient=2.5)
        @test t.variable_name == "x"
        @test t.coefficient == 2.5
    end

    @testset "NetworkConstraint" begin
        terms = [
            NetworkTerm(variable_name="x", coefficient=1.0),
            NetworkTerm(variable_name="y", coefficient=-1.0)
        ]
        c = NetworkConstraint(
            name="flow_limit",
            terms=terms,
            sense=LessThanOrEqual,
            rhs=100.0
        )
        @test c.name == "flow_limit"
        @test length(c.terms) == 2
        @test c.sense == LessThanOrEqual
        @test c.rhs == 100.0
    end

    @testset "FlowCutKey" begin
        k = FlowCutKey(branch_idx=1, period=2)
        @test k.branch_idx == 1
        @test k.period == 2
    end

    @testset "FlowCutMapping" begin
        m = FlowCutMapping()
        @test isempty(m.indices)

        m2 = FlowCutMapping(indices=Dict((1, 1) => (0, 1)))
        @test m2.indices[(1, 1)] == (0, 1)
    end

    @testset "CmbRecord" begin
        r = CmbRecord(
            bus_id=BusId(1),
            period=1,
            cmb=50.0,
            submarket_id=SubmarketId(1)
        )
        @test r.bus_id == BusId(1)
        @test r.cmb == 50.0
        @test r.submarket_id == SubmarketId(1)
    end
end
