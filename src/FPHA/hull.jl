using Polyhedra
using CDDLib

const EPS_NZ = 1e-9

struct Hyperplane3d
    normal::NTuple{3,Float64}
    offset::Float64
end

function convex_hull_3d(points::Vector{NTuple{3,Float64}}, hydro_name::String)::Vector{Hyperplane3d}
    n = length(points)
    n < 4 && throw(DegenerateCloudError(hydro_name, n))

    for p in points
        for c in p
            isfinite(c) || throw(HullComputationError(hydro_name, "non-finite coordinate"))
        end
    end

    sorted = sort(points)

    point_vecs = [[p[1], p[2], p[3]] for p in sorted]

    lib = CDDLib.Library()
    vrep_obj = Polyhedra.vrep(point_vecs)
    poly = polyhedron(vrep_obj, lib)

    local hrep_obj
    try
        hrep_obj = hrep(poly)
    catch e
        throw(HullComputationError(hydro_name, string(e)))
    end

    facets = Hyperplane3d[]
    for h in halfspaces(hrep_obj)
        a = h.a
        push!(facets, Hyperplane3d((a[1], a[2], a[3]), h.β))
    end

    isempty(facets) && throw(DegenerateCloudError(hydro_name, n))

    sort!(facets, by=f -> (f.normal[1], f.normal[2], f.normal[3], f.offset))
    facets
end

function extract_upper_envelope(planes::Vector{Hyperplane3d})::Vector{RawPlane}
    result = RawPlane[]
    for p in planes
        nz = p.normal[3]
        nz > EPS_NZ || continue
        push!(result, RawPlane(
            gamma_0=-p.offset / nz,
            gamma_v=-p.normal[1] / nz,
            gamma_q=-p.normal[2] / nz,
            gamma_s=0.0
        ))
    end
    sort!(result, by=r -> (r.gamma_0, r.gamma_v, r.gamma_q))
    result
end

function convex_hull_upper_envelope(points::Vector{NTuple{3,Float64}}, hydro_name::String)::Vector{RawPlane}
    facets = convex_hull_3d(points, hydro_name)
    extract_upper_envelope(facets)
end
