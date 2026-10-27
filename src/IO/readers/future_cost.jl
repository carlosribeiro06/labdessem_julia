# Future cost cut reader: OPER_FCF.bin (FlatBuffers binary format).
#
# NOTE: The FCF file uses FlatBuffers binary format which requires careful binary parsing.
# This implementation provides a stub that returns empty cuts when the file doesn't exist.
# Full FlatBuffers parsing will be implemented when needed for SDDP coupling.

function read_future_cost_cuts(path::String)::Vector{LDCore.FutureCostCut}
    !isfile(path) && return LDCore.FutureCostCut[]
    
    # TODO: Implement FlatBuffers binary parsing
    # For now, log a warning and return empty to avoid blocking study loading
    @warn "FCF binary parsing not yet implemented, returning empty cuts" path
    return LDCore.FutureCostCut[]
end
