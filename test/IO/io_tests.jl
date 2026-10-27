using Test
using LabDessem
using LabDessem.IO

@testset "IO Module" begin
    @testset "Module loads" begin
        @test isdefined(LabDessem, :IO)
    end
end
