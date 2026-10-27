using Test
using JuMP
using HiGHS
using LabDessem.Model

@testset "ModelConfig" begin
    @testset "default values" begin
        config = ModelConfig()
        @test config.thermal_uc_enabled == true
        @test config.hydro_uc_enabled == false
        @test config.optimizer_constructor == HiGHS.Optimizer
    end

    @testset "custom values" begin
        config = ModelConfig(thermal_uc_enabled=false, hydro_uc_enabled=true)
        @test config.thermal_uc_enabled == false
        @test config.hydro_uc_enabled == true
    end
end

@testset "ModelContainer" begin
    @testset "creation with default config" begin
        container = ModelContainer()
        @test container.model isa JuMP.Model
        @test container.config.thermal_uc_enabled == true
        @test container.index_sets === nothing
    end

    @testset "creation with custom config" begin
        config = ModelConfig(thermal_uc_enabled=false)
        container = ModelContainer(config)
        @test container.model isa JuMP.Model
        @test container.config.thermal_uc_enabled == false
    end

    @testset "solver is attached" begin
        container = ModelContainer()
        @test JuMP.solver_name(container.model) == "HiGHS"
    end

    @testset "custom optimizer constructor" begin
        config = ModelConfig(optimizer_constructor=HiGHS.Optimizer)
        container = ModelContainer(config)
        @test JuMP.solver_name(container.model) == "HiGHS"
    end

    @testset "index_sets is mutable" begin
        container = ModelContainer()
        @test container.index_sets === nothing
        container.index_sets = "placeholder"
        @test container.index_sets == "placeholder"
    end
end
