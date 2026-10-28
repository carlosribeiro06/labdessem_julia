using Test
using Polyhedra
using CDDLib
using LabDessem.FPHA

@testset "Polyhedra.jl Integration" begin
    @testset "Package loading" begin
        @test CDDLib.Library isa DataType
    end

    @testset "Tetrahedron convex hull" begin
        points = [
            [0.0, 0.0, 0.0],
            [1.0, 0.0, 0.0],
            [0.0, 1.0, 0.0],
            [0.0, 0.0, 1.0]
        ]

        lib = CDDLib.Library()
        vrep_obj = Polyhedra.vrep(points)
        poly = polyhedron(vrep_obj, lib)
        hrep_obj = hrep(poly)

        hs = collect(halfspaces(hrep_obj))
        @test length(hs) == 4
    end

    @testset "Cube convex hull" begin
        points = [
            [0.0, 0.0, 0.0],
            [1.0, 0.0, 0.0],
            [0.0, 1.0, 0.0],
            [1.0, 1.0, 0.0],
            [0.0, 0.0, 1.0],
            [1.0, 0.0, 1.0],
            [0.0, 1.0, 1.0],
            [1.0, 1.0, 1.0]
        ]

        lib = CDDLib.Library()
        vrep_obj = Polyhedra.vrep(points)
        poly = polyhedron(vrep_obj, lib)
        hrep_obj = hrep(poly)

        hs = collect(halfspaces(hrep_obj))
        @test length(hs) == 6
    end

    @testset "Halfspace extraction" begin
        points = [[0.0, 0.0, 0.0], [1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]]
        lib = CDDLib.Library()
        vrep_obj = Polyhedra.vrep(points)
        poly = polyhedron(vrep_obj, lib)
        hrep_obj = hrep(poly)

        for h in halfspaces(hrep_obj)
            @test length(h.a) == 3
            @test h.β isa Real
        end
    end
end

@testset "Convex Hull Wrapper" begin
    @testset "Tetrahedron returns 4 facets" begin
        points = [
            (0.0, 0.0, 0.0),
            (1.0, 0.0, 0.0),
            (0.0, 1.0, 0.0),
            (0.0, 0.0, 1.0)
        ]
        facets = convex_hull_3d(points, "TEST")
        @test length(facets) == 4
    end

    @testset "Cube returns 6 facets" begin
        points = [
            (0.0, 0.0, 0.0),
            (1.0, 0.0, 0.0),
            (0.0, 1.0, 0.0),
            (1.0, 1.0, 0.0),
            (0.0, 0.0, 1.0),
            (1.0, 0.0, 1.0),
            (0.0, 1.0, 1.0),
            (1.0, 1.0, 1.0)
        ]
        facets = convex_hull_3d(points, "TEST")
        @test length(facets) == 6
    end

    @testset "Shuffled input produces same facet count" begin
        points1 = [
            (0.0, 0.0, 0.0),
            (1.0, 0.0, 0.0),
            (0.0, 1.0, 0.0),
            (0.0, 0.0, 1.0)
        ]
        points2 = [
            (0.0, 0.0, 1.0),
            (0.0, 0.0, 0.0),
            (1.0, 0.0, 0.0),
            (0.0, 1.0, 0.0)
        ]
        facets1 = convex_hull_3d(points1, "TEST1")
        facets2 = convex_hull_3d(points2, "TEST2")
        @test length(facets1) == length(facets2)
    end

    @testset "Degenerate input throws error" begin
        points = [
            (0.0, 0.0, 0.0),
            (1.0, 0.0, 0.0),
            (0.0, 1.0, 0.0)
        ]
        @test_throws DegenerateCloudError convex_hull_3d(points, "TEST")
    end

    @testset "Hyperplane3d struct" begin
        h = Hyperplane3d((1.0, 0.0, 0.0), -1.0)
        @test h.normal == (1.0, 0.0, 0.0)
        @test h.offset == -1.0
    end
end

@testset "Upper Envelope Extraction" begin
    @testset "Unit cube upper envelope" begin
        points = [
            (0.0, 0.0, 0.0),
            (1.0, 0.0, 0.0),
            (0.0, 1.0, 0.0),
            (1.0, 1.0, 0.0),
            (0.0, 0.0, 1.0),
            (1.0, 0.0, 1.0),
            (0.0, 1.0, 1.0),
            (1.0, 1.0, 1.0)
        ]
        planes = convex_hull_upper_envelope(points, "CUBE")
        @test length(planes) >= 1
        for p in planes
            @test p isa RawPlane
            @test p.gamma_s == 0.0
        end
    end

    @testset "Tetrahedron upper envelope" begin
        points = [
            (0.0, 0.0, 0.0),
            (1.0, 0.0, 0.0),
            (0.0, 1.0, 0.0),
            (0.0, 0.0, 1.0)
        ]
        planes = convex_hull_upper_envelope(points, "TETRA")
        @test !isempty(planes)
    end

    @testset "extract_upper_envelope from Hyperplane3d" begin
        hyperplanes = [
            Hyperplane3d((0.0, 0.0, 1.0), 1.0),
            Hyperplane3d((0.0, 0.0, -1.0), 0.0),
            Hyperplane3d((1.0, 0.0, 0.0), -1.0),
        ]
        planes = extract_upper_envelope(hyperplanes)
        @test length(planes) == 1
        @test planes[1].gamma_0 ≈ 1.0 atol=1e-10
    end

    @testset "Type stability" begin
        points = [
            (0.0, 0.0, 0.0),
            (1.0, 0.0, 0.0),
            (0.0, 1.0, 0.0),
            (0.0, 0.0, 1.0)
        ]
        @test @inferred(convex_hull_3d(points, "TEST")) isa Vector{Hyperplane3d}
    end
end
