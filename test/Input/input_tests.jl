using Test
using LabDessem
using LabDessem.Input

@testset "Input Module" begin
    @testset "Module loads" begin
        @test isdefined(LabDessem, :Input)
    end
    
    include("test_common.jl")
    include("test_study_config.jl")
    include("readers/test_horizon.jl")
    include("readers/test_submarket.jl")
    include("readers/test_thermal.jl")
    include("readers/test_hydro.jl")
    include("readers/test_network.jl")
    include("readers/test_pumping.jl")
    include("readers/test_renewable.jl")
    include("readers/test_limits.jl")
    include("readers/test_future_cost.jl")
    include("readers/test_inflow_history.jl")
    include("test_integration.jl")
end
