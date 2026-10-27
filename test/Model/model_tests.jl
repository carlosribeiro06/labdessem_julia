using Test

@testset "Model" begin
    include("test_model_container.jl")
    include("test_indexing.jl")
    include("test_variables.jl")
end
