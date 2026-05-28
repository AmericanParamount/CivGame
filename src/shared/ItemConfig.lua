-- ItemConfig ModuleScript
-- Location: ReplicatedStorage > Modules > ItemConfig
-- Defines every item in the game.
local ItemConfig = {}
ItemConfig.Items = {
	-- === RESOURCES ===
	Stone = {
		DisplayName = "Stone",
		Category = "Resource",
		MaxStack = 1,
		Description = "Hard building material from rocks",
	},
	Reeds = {
		DisplayName = "Reeds",
		Category = "Resource",
		MaxStack = 1,
		Description = "Plant material from wetlands",
	},
	Sapling = {
		DisplayName = "Sapling",
		Category = "Resource",
		MaxStack = 1,
		Description = "A young tree sapling. Can be planted to grow a new tree.",
	},
	Sticks = {
		DisplayName = "Stick",
		Category = "Resource",
		MaxStack = 1,
		Description = "A small branch, useful for kindling and crafting",
	},
	-- === FOOD ===
	Berries = {
		DisplayName = "Berries",
		Category = "Food",
		MaxStack = 1,
		HungerRestore = 15,
		ThirstRestore = 5,
		Description = "Wild berries, restores a little hunger",
	},
	Mushrooms = {
		DisplayName = "Mushrooms",
		Category = "Food",
		MaxStack = 1,
		HungerRestore = 10,
		ThirstRestore = 0,
		Description = "Forest mushrooms",
	},
	Fish = {
		DisplayName = "Fish",
		Category = "Food",
		MaxStack = 1,
		HungerRestore = 20,
		ThirstRestore = 5,
		Description = "Fresh caught fish",
	},
	Herbs = {
		DisplayName = "Herbs",
		Category = "Food",
		MaxStack = 1,
		HungerRestore = 5,
		ThirstRestore = 0,
		HealthRestore = 10,
		Description = "Medicinal herbs, restores health",
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
