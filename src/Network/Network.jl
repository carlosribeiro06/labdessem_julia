"""
    Network

DC power flow network analysis for LabDessem.
Provides PTDF computation, flow analysis, violation detection,
and marginal cost (CMB/CMO) extraction.
"""
module Network

using LinearAlgebra
import ..Core as LDCore
using ..Core: BusId, BranchId, SubmarketId, System, Bus, Branch
using ..Core: StudyHorizon, Submarket, ThermalPlant, HydroPlant
using ..Core: PumpingPlant, RenewablePlant, InterchangeLimit
using ..Core: ResidualCost, FutureCostCut, OperationalLimit, InflowHistoryRow

include("errors.jl")
include("types.jl")
include("topology.jl")
include("model.jl")
include("flow.jl")
include("constraints.jl")
include("duals.jl")

# Errors
export NetworkError, NoReferenceBusError, SingularMatrixError
export DimensionMismatchError, NoBranchesError

# Types - Enums
export ConstraintSense, LessThanOrEqual, GreaterThanOrEqual, Equal

# Types - Flow results
export FlowViolation, LineFlowResult, AddedFlowCutLineResult

# Types - Constraints
export NetworkTerm, NetworkConstraint
export FlowCutKey, FlowCutMapping

# Types - Duals
export CmbRecord

# Topology
export find_reference_bus, build_non_slack_bus_mapping
export build_incidence_matrix, build_susceptance_matrix
export build_branch_susceptance_diag, compute_ptdf

# Model
export DcNetworkModel
export ptdf_row, ptdf_coefficient, ptdf_column, position_of_bus
export n_branches, n_buses, reference_bus

# Flow
export compute_line_flows, detect_flow_violations
export all_flow_constraints, constant_load_shift
export round_to_digits

# Constraints
export GeneratorEntry, PumpingEntry, FlowCutInput
export add_thermal!, add_hydro!, add_renewable!, add_pumping!
export build_flow_cut_terms

# Duals
export extract_flow_duals, compute_cmb_per_bus, compute_cmo_from_cmb

end
