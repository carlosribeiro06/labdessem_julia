Base.@kwdef struct VhaRow
    volume_hm3::Float64
    height_m::Float64
    area_km2::Float64
end

struct ForebayTable
    rows::Vector{VhaRow}
    hydro_name::String

    function ForebayTable(rows::Vector{VhaRow}, hydro_name::String)
        isempty(rows) && throw(InsufficientPointsError(hydro_name, 0))
        sorted = sort(rows, by=r -> r.volume_hm3)
        for i in 1:(length(sorted)-1)
            if abs(sorted[i].volume_hm3 - sorted[i+1].volume_hm3) < 1e-9
                throw(DuplicateVolumeError(hydro_name, sorted[i].volume_hm3))
            end
        end
        new(sorted, hydro_name)
    end
end

v_min(table::ForebayTable)::Float64 = table.rows[1].volume_hm3
v_max(table::ForebayTable)::Float64 = table.rows[end].volume_hm3
hydro_name(table::ForebayTable)::String = table.hydro_name

function interpolate(table::ForebayTable, volume_hm3::Float64)::Float64
    n = length(table.rows)
    n == 1 && return table.rows[1].height_m

    v = clamp(volume_hm3, v_min(table), v_max(table))

    volumes = [r.volume_hm3 for r in table.rows]
    idx = searchsortedlast(volumes, v)
    idx = clamp(idx, 1, n - 1)

    r0, r1 = table.rows[idx], table.rows[idx+1]
    t = (v - r0.volume_hm3) / (r1.volume_hm3 - r0.volume_hm3)
    r0.height_m + t * (r1.height_m - r0.height_m)
end
