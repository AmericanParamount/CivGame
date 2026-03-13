-- ItemConfig ModuleScript
-- Location: ReplicatedStorage > Modules > ItemConfig
-- Defines every item in the game.
local ItemConfig = {}
ItemConfig.Items = {
	-- === RESOURCES ===
	Wood = {
		DisplayName = "Wood",
		Category = "Resource",
		MaxStack = 50,
		Description = "Basic building material from trees",
	},
	Stone = {
		DisplayName = "Stone",
		Category = "Resource",
		MaxStack = 50,
		Description = "Hard building material from rocks",
	},
	Clay = {
		DisplayName = "Clay",
		Category = "Resource",
		MaxStack = 30,
		Description = "Soft material for pottery and bricks",
	},
	Iron = {
		DisplayName = "Iron Ore",
		Category = "Resource",
		MaxStack = 30,
		Description = "Raw metal ore for smelting",
	},
	Copper = {
		DisplayName = "Copper Ore",
		Category = "Resource",
		MaxStack = 30,
		Description = "Raw copper ore for bronze making",
	},
	Reeds = {
		DisplayName = "Reeds",
		Category = "Resource",
		MaxStack = 30,
		Description = "Plant material from wetlands",
	},
	Sapling = {
		DisplayName = "Sapling",
		Category = "Resource",
		MaxStack = 10,
		Description = "A young tree sapling. Can be planted to grow a new tree.",
	},
	-- === FOOD ===
	Berries = {
		DisplayName = "Berries",
		Category = "Food",
		MaxStack = 20,
		HungerRestore = 15,
		ThirstRestore = 5,
		Description = "Wild berries, restores a little hunger",
	},
	Mushrooms = {
		DisplayName = "Mushrooms",
		Category = "Food",
		MaxStack = 20,
		HungerRestore = 10,
		ThirstRestore = 0,
		Description = "Forest mushrooms",
	},
	RawMeat = {
		DisplayName = "Raw Meat",
		Category = "Food",
		MaxStack = 10,
		HungerRestore = 8,
		ThirstRestore = 0,
		Description = "Uncooked meat, not very nourishing",
	},
	CookedMeat = {
		DisplayName = "Cooked Meat",
		Category = "Food",
		MaxStack = 10,
		HungerRestore = 35,
		ThirstRestore = 0,
		Description = "Well cooked meat, very filling",
	},
	Fish = {
		DisplayName = "Fish",
		Category = "Food",
		MaxStack = 10,
		HungerRestore = 20,
		ThirstRestore = 5,
		Description = "Fresh caught fish",
	},
	Herbs = {
		DisplayName = "Herbs",
		Category = "Food",
		MaxStack = 20,
		HungerRestore = 5,
		ThirstRestore = 0,
		HealthRestore = 10,
		Description = "Medicinal herbs, restores health",
	},
	-- === TOOLS ===
	StoneAxe = {
		DisplayName = "Stone Axe",
		Category = "Tool",
		MaxStack = 1,
		ToolType = "Axe",
		GatherSpeed = 1.5,
		Durability = 50,
		Description = "A crude axe for chopping trees",
	},
	StonePickaxe = {
		DisplayName = "Stone Pickaxe",
		Category = "Tool",
		MaxStack = 1,
		ToolType = "Pickaxe",
		GatherSpeed = 1.5,
		Durability = 50,
		Description = "A crude pickaxe for mining stone",
	},
	WoodSpear = {
		DisplayName = "Wooden Spear",
		Category = "Tool",
		MaxStack = 1,
		ToolType = "Weapon",
		Damage = 15,
		Durability = 30,
		Description = "A sharpened wooden spear",
	},
}
function ItemConfig.GetItem(itemName: string)
	return ItemConfig.Items[itemName]
end
function ItemConfig.GetMaxStack(itemName: string): number
	local item = ItemConfig.Items[itemName]
	return item and item.MaxStack or 1
end
function ItemConfig.IsFood(itemName: string): boolean
	local item = ItemConfig.Items[itemName]
	return item and item.Category == "Food"
end
function ItemConfig.IsTool(itemName: string): boolean
	local item = ItemConfig.Items[itemName]
	return item and item.Category == "Tool"
end
function ItemConfig.GetFoodValues(itemName: string)
	local item = ItemConfig.Items[itemName]
	if not item or item.Category ~= "Food" then return nil end
	return {
		Hunger = item.HungerRestore or 0,
		Thirst = item.ThirstRestore or 0,
		Health = item.HealthRestore or 0,
	}
end
function ItemConfig.IsValidItem(itemName: string): boolean
	return ItemConfig.Items[itemName] ~= nil
end
return ItemConfig
