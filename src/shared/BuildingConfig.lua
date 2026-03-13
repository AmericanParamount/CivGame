-- BuildingConfig ModuleScript
-- Location: ReplicatedStorage > Modules > BuildingConfig

local BuildingConfig = {}

BuildingConfig.INSERT_RANGE = 8
BuildingConfig.MATERIAL_SEARCH_RADIUS = 20

BuildingConfig.Categories = {
	{ Key = "All", DisplayName = "All", Icon = "rbxassetid://6031071050" },
	{ Key = "Structures", DisplayName = "Structures", Icon = "rbxassetid://6031071050" },
	{ Key = "Defenses", DisplayName = "Defenses", Icon = "rbxassetid://6031071050" },
	{ Key = "Crafting", DisplayName = "Crafting", Icon = "rbxassetid://6031071050" },
	{ Key = "Farming", DisplayName = "Farming", Icon = "rbxassetid://6031071050" },
	{ Key = "Decorations", DisplayName = "Decorations", Icon = "rbxassetid://6031071050" },
	{ Key = "Misc", DisplayName = "Misc.", Icon = "rbxassetid://6031071050" },
}

BuildingConfig.Buildings = {
	TownHall = { DisplayName = "Town Hall", Description = "The heart of your civilization. Required to found a settlement.", Category = "Structures", FootprintX = 12, FootprintZ = 12, FootprintY = 10, Cost = { Log = 5, Stone = 5 }, MinAge = 16, Unique = true },
	WoodenHut = { DisplayName = "Wooden Hut", Description = "A simple shelter. Provides housing for your people.", Category = "Structures", FootprintX = 8, FootprintZ = 8, FootprintY = 8, Cost = { Log = 3 }, MinAge = 12 },
	StoneHouse = { DisplayName = "Stone House", Description = "A sturdy dwelling made of stone.", Category = "Structures", FootprintX = 10, FootprintZ = 10, FootprintY = 9, Cost = { Log = 2, Stone = 5 }, MinAge = 16, RequiredRole = "Engineer" },
	Longhouse = { DisplayName = "Longhouse", Description = "A large communal hall for feasts and gatherings.", Category = "Structures", FootprintX = 16, FootprintZ = 8, FootprintY = 8, Cost = { Log = 8 }, MinAge = 18, RequiredRole = "Engineer" },
	StorageHut = { DisplayName = "Storage Hut", Description = "Extra space to store resources.", Category = "Structures", FootprintX = 6, FootprintZ = 6, FootprintY = 6, Cost = { Log = 3, Stone = 1 }, MinAge = 12 },
	WoodenWall = { DisplayName = "Wooden Wall", Description = "A basic wooden palisade.", Category = "Defenses", FootprintX = 8, FootprintZ = 2, FootprintY = 6, Cost = { Log = 2 }, MinAge = 10 },
	StoneWall = { DisplayName = "Stone Wall", Description = "A reinforced stone wall.", Category = "Defenses", FootprintX = 8, FootprintZ = 2, FootprintY = 6, Cost = { Stone = 3 }, MinAge = 14 },
	WoodenGate = { DisplayName = "Wooden Gate", Description = "A gate that can be opened and closed.", Category = "Defenses", FootprintX = 6, FootprintZ = 2, FootprintY = 7, Cost = { Log = 3, Stone = 1 }, MinAge = 14 },
	WatchTower = { DisplayName = "Watch Tower", Description = "A tall lookout tower.", Category = "Defenses", FootprintX = 6, FootprintZ = 6, FootprintY = 14, Cost = { Log = 4, Stone = 3 }, MinAge = 16, RequiredRole = "Engineer" },
	Campfire = { DisplayName = "Campfire", Description = "A simple fire pit. Cook food and stay warm.", Category = "Crafting", FootprintX = 4, FootprintZ = 4, FootprintY = 3, Cost = { Log = 2 } },
	Workbench = { DisplayName = "Workbench", Description = "A crafting station for tools and basic items.", Category = "Crafting", FootprintX = 4, FootprintZ = 3, FootprintY = 4, Cost = { Log = 2, Stone = 1 }, MinAge = 10 },
	Forge = { DisplayName = "Forge", Description = "Smelt ores and craft metal tools and weapons.", Category = "Crafting", FootprintX = 6, FootprintZ = 5, FootprintY = 6, Cost = { Log = 3, Stone = 5 }, MinAge = 16, RequiredRole = "Engineer" },
	Kiln = { DisplayName = "Kiln", Description = "Fire clay into bricks and pottery.", Category = "Crafting", FootprintX = 4, FootprintZ = 4, FootprintY = 5, Cost = { Stone = 4, Log = 1 }, MinAge = 14 },
	FarmPlot = { DisplayName = "Farm Plot", Description = "Tilled land for growing crops.", Category = "Farming", FootprintX = 8, FootprintZ = 8, FootprintY = 1, AllowedTerrain = { "FertilePlains", "Grassland" }, Cost = { Log = 1 }, MinAge = 8 },
	Well = { DisplayName = "Well", Description = "A water source for your settlement.", Category = "Farming", FootprintX = 4, FootprintZ = 4, FootprintY = 4, Cost = { Stone = 3, Log = 1 }, MinAge = 12 },
	Silo = { DisplayName = "Silo", Description = "Stores harvested crops.", Category = "Farming", FootprintX = 5, FootprintZ = 5, FootprintY = 8, Cost = { Log = 3, Stone = 2 }, MinAge = 14 },
	WoodenSign = { DisplayName = "Wooden Sign", Description = "A signpost. Mark locations and leave messages.", Category = "Decorations", FootprintX = 2, FootprintZ = 1, FootprintY = 4, Cost = { Log = 1 } },
	WoodenFence = { DisplayName = "Wooden Fence", Description = "A short decorative fence.", Category = "Decorations", FootprintX = 8, FootprintZ = 1, FootprintY = 3, Cost = { Log = 1 } },
	Chest = { DisplayName = "Chest", Description = "Personal storage. Keep your valuables safe.", Category = "Decorations", FootprintX = 3, FootprintZ = 2, FootprintY = 3, Cost = { Log = 1 }, MinAge = 8 },
	Torch = { DisplayName = "Torch", Description = "A standing torch. Lights up the area at night.", Category = "Decorations", FootprintX = 2, FootprintZ = 2, FootprintY = 5, Cost = { Log = 1 } },
	Dock = { DisplayName = "Dock", Description = "A wooden platform over water.", Category = "Misc", FootprintX = 8, FootprintZ = 12, FootprintY = 3, AllowedTerrain = { "SandyShore", "Riverbank" }, Cost = { Log = 5 }, MinAge = 16, RequiredRole = "Engineer" },
	Bridge = { DisplayName = "Bridge", Description = "A wooden crossing over water or gaps.", Category = "Misc", FootprintX = 4, FootprintZ = 12, FootprintY = 2, Cost = { Log = 4, Stone = 2 }, MinAge = 14, RequiredRole = "Engineer" },
}

function BuildingConfig.GetBuilding(buildingName) return BuildingConfig.Buildings[buildingName] end

function BuildingConfig.GetFootprint(buildingName)
	local b = BuildingConfig.Buildings[buildingName]; if b then return b.FootprintX, b.FootprintZ end; return 4, 4
end

function BuildingConfig.GetAllNames()
	local names = {}; for name in pairs(BuildingConfig.Buildings) do table.insert(names, name) end
	table.sort(names); return names
end

function BuildingConfig.GetNamesByCategory(category)
	if category == "All" then return BuildingConfig.GetAllNames() end
	local names = {}
	for name, data in pairs(BuildingConfig.Buildings) do if data.Category == category then table.insert(names, name) end end
	table.sort(names); return names
end

function BuildingConfig.GetCostString(buildingName)
	local b = BuildingConfig.Buildings[buildingName]; if not b or not b.Cost then return "Free" end
	local parts = {}; for item, count in pairs(b.Cost) do table.insert(parts, count .. "x " .. item) end
	if #parts == 0 then return "Free" end; table.sort(parts); return table.concat(parts, ", ")
end

function BuildingConfig.GetRequirementString(buildingName)
	local b = BuildingConfig.Buildings[buildingName]; if not b then return "" end
	local parts = {}
	if b.MinAge then table.insert(parts, "Age " .. b.MinAge .. "+") end
	if b.RequiredRole then table.insert(parts, b.RequiredRole) end
	if #parts == 0 then return "None" end; return table.concat(parts, " | ")
end

return BuildingConfig
