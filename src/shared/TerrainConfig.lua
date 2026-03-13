-- TerrainConfig ModuleScript
-- Location: ReplicatedStorage > Modules > TerrainConfig

local TerrainConfig = {}

TerrainConfig.Types = {
	Grassland = { DisplayName = "Grassland", Fertility = 0.5, SpeedMultiplier = 1.0, CanBuild = true, CanFarm = true, ResourceSpawns = {"Wood", "Berries"} },
	FertilePlains = { DisplayName = "Fertile Plains", Fertility = 0.85, SpeedMultiplier = 1.0, CanBuild = true, CanFarm = true, ResourceSpawns = {"Wood", "Berries", "Herbs"} },
	ForestFloor = { DisplayName = "Forest", Fertility = 0.4, SpeedMultiplier = 1.0, CanBuild = true, CanFarm = true, ResourceSpawns = {"Wood", "Berries", "Mushrooms"} },
	Wetland = { DisplayName = "Wetland", Fertility = 0.75, SpeedMultiplier = 0.7, CanBuild = false, CanFarm = true, ResourceSpawns = {"Reeds", "Herbs"} },
	SandyShore = { DisplayName = "Shore", Fertility = 0.0, SpeedMultiplier = 0.9, CanBuild = true, CanFarm = false, ResourceSpawns = {"Fish"} },
	DryScrubland = { DisplayName = "Scrubland", Fertility = 0.2, SpeedMultiplier = 1.0, CanBuild = true, CanFarm = true, ResourceSpawns = {"Clay", "Stone"} },
	RockyGround = { DisplayName = "Rocky Ground", Fertility = 0.0, SpeedMultiplier = 0.9, CanBuild = true, CanFarm = false, ResourceSpawns = {"Stone", "Iron", "Copper"} },
	RockyHighlands = { DisplayName = "Highlands", Fertility = 0.0, SpeedMultiplier = 0.85, CanBuild = true, CanFarm = false, ResourceSpawns = {"Stone", "Iron", "Copper", "Gold"} },
	Riverbank = { DisplayName = "Riverbank", Fertility = 1.0, SpeedMultiplier = 0.9, CanBuild = true, CanFarm = true, ResourceSpawns = {"Clay", "Reeds", "Fish"} },
	IslandGround = { DisplayName = "Island", Fertility = 0.15, SpeedMultiplier = 1.0, CanBuild = true, CanFarm = true, ResourceSpawns = {"Stone"} },
	ShallowWater = { DisplayName = "Shallow Water", Fertility = 0.0, SpeedMultiplier = 0.3, CanBuild = false, CanFarm = false, ResourceSpawns = {"Fish"} },
	DeepWater = { DisplayName = "Deep Water", Fertility = 0.0, SpeedMultiplier = 0.0, CanBuild = false, CanFarm = false, ResourceSpawns = {"Fish"} },
}

function TerrainConfig.IsValidType(typeName) return TerrainConfig.Types[typeName] ~= nil end
function TerrainConfig.GetProperty(typeName, property, default)
	local d = TerrainConfig.Types[typeName]; if d and d[property] ~= nil then return d[property] end; return default
end
function TerrainConfig.GetTypeData(typeName) return TerrainConfig.Types[typeName] end
function TerrainConfig.GetFertility(typeName) return TerrainConfig.GetProperty(typeName, "Fertility", 0) end
function TerrainConfig.GetSpeed(typeName) return TerrainConfig.GetProperty(typeName, "SpeedMultiplier", 1.0) end
function TerrainConfig.CanBuildOn(typeName) return TerrainConfig.GetProperty(typeName, "CanBuild", false) end
function TerrainConfig.CanFarmOn(typeName) return TerrainConfig.GetProperty(typeName, "CanFarm", false) end

return TerrainConfig
