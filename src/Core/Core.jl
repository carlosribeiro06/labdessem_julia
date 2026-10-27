module Core

include("types.jl")
include("entities.jl")
include("validation.jl")

# Type aliases
export SubmarketId, BusId, BranchId
export ThermalPlantId, ThermalUnitId
export HydroPlantId, HydroGroupId, HydroUnitId
export PumpingPlantId, RenewablePlantId

# Enums and values
export TurbineType, Francis, Kaplan, Unknown
export OperationalLimitVariable
export Generation, Spillage, Volume, Defluence, Turbining, Diversion, Pumping

# Thermal entities
export ThermalInitialCondition, ThermalUnit, ThermalPlant

# Hydro entities
export HydroInitialCondition, HydroUnit, HydroGroup
export Reservoir, HydroFphaSegment, HydroPlant
export turbine_alpha

# Network entities
export Submarket, Bus, Branch

# Other plants
export PumpingPlant, RenewablePlant

# System entities
export InterchangeLimit, ResidualCost, FutureCostCut, StudyHorizon

# Operational limits
export OperationalLimitTarget
export ThermalPlantTarget, ThermalUnitTarget
export HydroPlantTarget, HydroUnitTarget
export PumpingPlantTarget
export OperationalLimit

# Supporting types
export InflowHistoryRow, EngMaxBounds

# Container
export System

# Functions
export validate!

end
