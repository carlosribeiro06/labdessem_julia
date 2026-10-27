using Test
using LabDessem
using LabDessem.IO

@testset "IO Module" begin
    @testset "Module loads" begin
        @test isdefined(LabDessem, :IO)
    end
    
    include("test_common.jl")
    include("test_study_config.jl")
    include("readers/test_horizon.jl")
    include("readers/test_submarket.jl")
    include("readers/test_thermal.jl")
    include("readers/test_hydro.jl")
    include("readers/test_network.jl")
    include("readers/test_pumping.jl")
end
