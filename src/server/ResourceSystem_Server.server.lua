-- ResourceSystem_Server Script
-- Location: ServerScriptService > ResourceSystem_Server
-- Resources, gathering, water drinking (E hold), eating (click).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local ItemConfig = require(Modules:WaitForChild("ItemConfig"))
local InventoryManager = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("InventoryManager"))

local Events = ReplicatedStorage:WaitForChild("Events")

local HIT_RANGE = 5

local function ensureEvent(name)
	local event = Events:FindFirstChild(name)
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = Events
	end
	return event
end

local HitResourceEvent = ensureEvent("HitResource")
local EatEvent = ensureEvent("EatItem")
local DrinkWaterEvent = ensureEvent("DrinkWater")
local SelectSlotEvent = ensureEvent("SelectSlot")
local DropItemEvent = ensureEvent("DropItem")
local SwapSlotsEvent = ensureEvent("SwapSlots")

local SpawnCarryFunc = nil
task.spawn(function()
	local func = Events:WaitForChild("SpawnCarryItem", 10)
	if func then SpawnCarryFunc = func; print("[RESOURCE] Connected to carry system")
	else warn("[RESOURCE] SpawnCarryItem not found!") end
end)

local SpawnSaplingFunc = nil
task.spawn(function()
	local func = Events:WaitForChild("SpawnSaplingCarryItem", 10)
	if func then SpawnSaplingFunc = func; print("[RESOURCE] Connected to sapling carry spawner") end
end)

local HydrateFunc = nil
task.spawn(function()
	local func = Events:WaitForChild("HydratePlayer", 10)
	if func then
		HydrateFunc = func
		print("[RESOURCE] Connected to hydration system")
	else
		warn("[RESOURCE] HydratePlayer NOT FOUND — drinking will not work!")
	end
end)

local CARRY_DEFAULTS = {
	Log = { Size = Vector3.new(2, 2, 6), Color = Color3.fromRGB(120, 80, 40), Material = Enum.Material.WoodPlanks },
	Stone = { Size = Vector3.new(3, 2.5, 3), Color = Color3.fromRGB(140, 135, 125), Material = Enum.Material.Slate },
	IronOre = { Size = Vector3.new(2.5, 2, 2.5), Color = Color3.fromRGB(120, 85, 60), Material = Enum.Material.Slate },
	CopperOre = { Size = Vector3.new(2.5, 2, 2.5), Color = Color3.fromRGB(140, 110, 70), Material = Enum.Material.Slate },
}

local function fallbackSpawnCarry(itemType, position, count)
	local pf = workspace:FindFirstChild("Pickups")
	if not pf then pf = Instance.new("Folder"); pf.Name = "Pickups"; pf.Parent = workspace end
	local defaults = CARRY_DEFAULTS[itemType]
	if not defaults then return end
	for i = 1, (count or 1) do
		local item = nil
		local mf = ServerStorage:FindFirstChild("CarryModels")
		if mf then
			local t = mf:FindFirstChild(itemType)
			if t then
				item = t:Clone()
				for _, p in ipairs(item:GetDescendants()) do
					if p:IsA("BasePart") then p.Anchored = false; p.CanCollide = true end
				end
			end
		end
		if not item then
			item = Instance.new("Part"); item.Name = itemType
			item.Size = defaults.Size; item.Color = defaults.Color
			item.Material = defaults.Material; item.Anchored = false; item.CanCollide = true
		end
		local tv = Instance.new("StringValue"); tv.Name = "CarryType"; tv.Value = itemType; tv.Parent = item
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.new(0, 100, 0, 25); bb.StudsOffset = Vector3.new(0, 2, 0)
		bb.AlwaysOnTop = false; bb.MaxDistance = 25; bb.Parent = item
		local lb = Instance.new("TextLabel")
		lb.Size = UDim2.new(1, 0, 1, 0); lb.BackgroundTransparency = 1
		lb.Text = "[E] " .. itemType; lb.TextColor3 = Color3.fromRGB(255, 255, 200)
		lb.TextStrokeTransparency = 0.5; lb.TextSize = 13; lb.Font = Enum.Font.GothamBold; lb.Parent = bb
		local offset = Vector3.new(math.random(-3, 3), 3, math.random(-3, 3))
		if item:IsA("Model") and item.PrimaryPart then item:PivotTo(CFrame.new(position + offset))
		elseif item:IsA("BasePart") then item.Position = position + offset end
		item.Parent = pf
	end
end

local function spawnCarryItems(itemType, position, count)
	if SpawnCarryFunc then
		local ok = pcall(function() SpawnCarryFunc:Invoke(itemType, position, count) end)
		if not ok then fallbackSpawnCarry(itemType, position, count) end
	else
		fallbackSpawnCarry(itemType, position, count)
	end
end

local function spawnSaplingCarry(position, variant)
	if SpawnSaplingFunc then
		pcall(function() SpawnSaplingFunc:Invoke(position, variant) end)
	else
		spawnCarryItems("Sapling", position, 1)
	end
end

local RESOURCE_NODES = {
	Tree = {
		MaxHealth = 5, HitCooldown = 0.6, HandDamage = 1,
		ToolBonus = "Axe", ToolDamage = 2,
		Drops = {
			{ Type = "carry", CarryItem = "Log", Min = 1, Max = 1 },
			{ Type = "inventory", Item = "Sticks", Min = 1, Max = 2 },
		},
		DropsSapling = true, NoRespawn = true,
	},
	PlantedSapling = {
		MaxHealth = 1, HitCooldown = 0.5, HandDamage = 1,
		Drops = {}, DropsSapling = true, NoRespawn = true,
	},
	Rock = {
		MaxHealth = 4, HitCooldown = 0.8, HandDamage = 1,
		ToolBonus = "Pickaxe", ToolDamage = 2,
		Drops = { { Type = "carry", CarryItem = "Stone", Min = 1, Max = 1 } },
		RespawnTime = 180, RemnantModel = "Rock", RemnantYOffset = -0.5,
	},
	IronDeposit = {
		MaxHealth = 6, HitCooldown = 0.8, HandDamage = 0,
		ToolBonus = "Pickaxe", ToolDamage = 1,
		Drops = { { Type = "carry", CarryItem = "IronOre", Min = 1, Max = 2 } },
		RespawnTime = 300, RemnantModel = "IronDeposit", RemnantYOffset = -0.5,
	},
	CopperDeposit = {
		MaxHealth = 6, HitCooldown = 0.8, HandDamage = 0,
		ToolBonus = "Pickaxe", ToolDamage = 1,
		Drops = { { Type = "carry", CarryItem = "CopperOre", Min = 1, Max = 2 } },
		RespawnTime = 300, RemnantModel = "CopperDeposit", RemnantYOffset = -0.5,
	},
	BerryBush = {
		MaxHealth = 1, HitCooldown = 0.5, HandDamage = 1,
		Drops = { { Type = "inventory", Item = "Berries", Min = 2, Max = 5 } },
		RespawnTime = 90,
	},
	MushroomPatch = {
		MaxHealth = 1, HitCooldown = 0.5, HandDamage = 1,
		Drops = { { Type = "inventory", Item = "Mushrooms", Min = 1, Max = 3 } },
		RespawnTime = 90,
	},
	ReedPatch = {
		MaxHealth = 2, HitCooldown = 0.5, HandDamage = 1,
		Drops = { { Type = "inventory", Item = "Reeds", Min = 2, Max = 4 } },
		RespawnTime = 120,
	},
	ClayDeposit = {
		MaxHealth = 4, HitCooldown = 0.7, HandDamage = 1,
		ToolBonus = "Pickaxe", ToolDamage = 2,
		Drops = { { Type = "carry", CarryItem = "Stone", Min = 1, Max = 1 } },
		RespawnTime = 180, RemnantModel = "ClayDeposit", RemnantYOffset = -0.5,
	},
	HerbPatch = {
		MaxHealth = 1, HitCooldown = 0.5, HandDamage = 1,
		Drops = { { Type = "inventory", Item = "Herbs", Min = 1, Max = 2 } },
		RespawnTime = 120,
	},
	FishingSpot = {
		MaxHealth = 1, HitCooldown = 0.5, HandDamage = 1,
		Drops = { { Type = "inventory", Item = "Fish", Min = 1, Max = 2 } },
		RespawnTime = 120,
	},
	FlintNode = {
		MaxHealth = 1, HitCooldown = 0.5, HandDamage = 1,
		Drops = { { Type = "inventory", Item = "Flint", Min = 1, Max = 3 } },
		RespawnTime = 150,
	},
	RiverClayBank = {
		MaxHealth = 2, HitCooldown = 0.6, HandDamage = 1,
		Drops = { { Type = "inventory", Item = "RiverClay", Min = 2, Max = 4 } },
		RespawnTime = 180,
	},
}

local nodeStates = {}
local playerHitCooldowns = {}
local activeRemnants = {}
local playerDrinkCooldowns = {}

local DRINK_RANGE = 14
local DRINK_COOLDOWN = 3
local DRINK_THIRST_RESTORE = 30
local DRINK_SOUND_ID = "rbxassetid://257001402"

local function isPlayerNearWater(player)
	local character = player.Character
	if not character then return false end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local playerPos = root.Position
	local waterFolder = workspace:FindFirstChild("Water")
	if waterFolder then
		for _, waterPart in ipairs(waterFolder:GetDescendants()) do
			if waterPart:IsA("BasePart") then
				local halfSize = waterPart.Size / 2
				local rel = waterPart.CFrame:PointToObjectSpace(playerPos)
				local clamped = Vector3.new(
					math.clamp(rel.X, -halfSize.X, halfSize.X),
					math.clamp(rel.Y, -halfSize.Y, halfSize.Y),
					math.clamp(rel.Z, -halfSize.Z, halfSize.Z)
				)
				local closest = waterPart.CFrame:PointToWorldSpace(clamped)
				local dist = (playerPos - closest).Magnitude
				if dist <= DRINK_RANGE then return true end
			end
		end
	end
	local buildingsFolder = workspace:FindFirstChild("Buildings")
	if buildingsFolder then
		for _, building in ipairs(buildingsFolder:GetChildren()) do
			local bt = building:FindFirstChild("BuildingType")
			if bt and bt:IsA("StringValue") and bt.Value == "Well" then
				local status = building:FindFirstChild("BlueprintStatus")
				if not status then
					local pos
					if building:IsA("Model") and building.PrimaryPart then pos = building.PrimaryPart.Position
					elseif building:IsA("Model") then pos = building:GetPivot().Position end
					if pos and (playerPos - pos).Magnitude <= DRINK_RANGE then return true end
				end
			end
		end
	end
	return false
end

local function tryDrinkWater(player)
	local now = tick()
	local lastDrink = playerDrinkCooldowns[player.UserId] or 0
	if now - lastDrink < DRINK_COOLDOWN then
		print("[WATER] " .. player.Name .. " drink on cooldown")
		return false
	end
	local nearWater = isPlayerNearWater(player)
	if not nearWater then
		print("[WATER] " .. player.Name .. " not near water")
		return false
	end
	playerDrinkCooldowns[player.UserId] = now
	if HydrateFunc then
		local ok, err = pcall(function() HydrateFunc:Invoke(player, DRINK_THIRST_RESTORE) end)
		if ok then
			print(string.format("[WATER] %s drank water (+%d thirst)", player.Name, DRINK_THIRST_RESTORE))
		else
			warn("[WATER] HydrateFunc failed: " .. tostring(err))
		end
	else
		warn("[WATER] HydrateFunc is nil — cannot hydrate!")
	end
	local character = player.Character
	if character then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			local s = Instance.new("Sound")
			s.SoundId = DRINK_SOUND_ID; s.Volume = 0.5
			s.RollOffMaxDistance = 30; s.Parent = root
			s:Play()
			s.Ended:Connect(function() s:Destroy() end)
			task.delay(3, function() if s.Parent then s:Destroy() end end)
		end
	end
	return true
end

local function getNodeType(node)
	local tv = node:FindFirstChild("ResourceType")
	if tv and tv:IsA("StringValue") then return tv.Value end
	return nil
end

local function getNodeVariant(node)
	local vv = node:FindFirstChild("Variant")
	if vv and vv:IsA("IntValue") then return vv.Value end
	if vv and vv:IsA("StringValue") then return tonumber(vv.Value) or 1 end
	return 1
end

local function findNodeRoot(part)
	local c = part
	for _ = 1, 5 do
		if not c then return nil end
		if c:FindFirstChild("ResourceType") then return c end
		c = c.Parent
	end
	return nil
end

local function getNodeState(node, nodeType)
	if not nodeStates[node] then
		local config = RESOURCE_NODES[nodeType]
		nodeStates[node] = { Health = config and config.MaxHealth or 3, Destroyed = false }
	end
	return nodeStates[node]
end

local function hideNode(node)
	if node:IsA("Model") then
		for _, p in ipairs(node:GetDescendants()) do
			if p:IsA("BasePart") then p.Transparency = 1; p.CanCollide = false
			elseif p:IsA("Texture") or p:IsA("Decal") or p:IsA("SurfaceGui") then p.Transparency = 1 end
		end
	elseif node:IsA("BasePart") then node.Transparency = 1; node.CanCollide = false end
end

local function showNode(node)
	if node:IsA("Model") then
		for _, p in ipairs(node:GetDescendants()) do
			if p:IsA("BasePart") then p.Transparency = 0; p.CanCollide = true
			elseif p:IsA("Texture") or p:IsA("Decal") or p:IsA("SurfaceGui") then p.Transparency = 0 end
		end
	elseif node:IsA("BasePart") then node.Transparency = 0; node.CanCollide = true end
end

local function spawnRemnant(node, nodeType, config)
	local pos
	if node:IsA("Model") and node.PrimaryPart then pos = node.PrimaryPart.Position
	elseif node:IsA("BasePart") then pos = node.Position
	else return nil end
	pos = pos + Vector3.new(0, config.RemnantYOffset or 0, 0)
	local remnant = nil
	if config.RemnantModel then
		local rf = ServerStorage:FindFirstChild("ResourceRemnants")
		if rf then
			local t = rf:FindFirstChild(config.RemnantModel)
			if t then
				remnant = t:Clone()
				if remnant:IsA("Model") and remnant.PrimaryPart then remnant:PivotTo(CFrame.new(pos))
				elseif remnant:IsA("BasePart") then remnant.Position = pos end
			end
		end
	end
	if not remnant then
		remnant = Instance.new("Part"); remnant.Name = "Remnant_" .. nodeType
		remnant.Size = Vector3.new(3, 1, 3); remnant.Position = pos + Vector3.new(0, 0.5, 0)
		remnant.Anchored = true; remnant.CanCollide = true
		remnant.Color = Color3.fromRGB(100, 95, 85); remnant.Material = Enum.Material.Slate
	end
	if remnant:IsA("Model") then
		for _, p in ipairs(remnant:GetDescendants()) do if p:IsA("BasePart") then p.Anchored = true end end
	elseif remnant:IsA("BasePart") then remnant.Anchored = true end
	remnant.Parent = node.Parent or workspace
	activeRemnants[node] = remnant
	return remnant
end

local function removeRemnant(node)
	local r = activeRemnants[node]; if r and r.Parent then r:Destroy() end
	activeRemnants[node] = nil
end

local function destroyNode(node, nodeType, config, player)
	local state = nodeStates[node]; if state then state.Destroyed = true end
	local dropPos
	if node:IsA("Model") and node.PrimaryPart then dropPos = node.PrimaryPart.Position
	elseif node:IsA("BasePart") then dropPos = node.Position
	else return end
	hideNode(node)
	local variant = getNodeVariant(node)
	local drops = config.Drops
	if config.VariantDrops and config.VariantDrops[variant] then drops = config.VariantDrops[variant] end
	for _, drop in ipairs(drops) do
		local amount = math.random(drop.Min, drop.Max)
		if drop.Type == "carry" then spawnCarryItems(drop.CarryItem, dropPos, amount)
		elseif drop.Type == "inventory" then
			InventoryManager.AddItem(player, drop.Item, amount)
			print(string.format("[GATHER] %s received %dx %s", player.Name, amount, drop.Item))
		end
	end
	if config.DropsSapling then spawnSaplingCarry(dropPos, variant) end
	if config.RemnantModel then spawnRemnant(node, nodeType, config) end
	if config.NoRespawn then
		task.delay(1, function()
			removeRemnant(node); if node.Parent then node:Destroy() end; nodeStates[node] = nil
		end)
	else
		task.delay(config.RespawnTime or 180, function()
			removeRemnant(node)
			if node.Parent then showNode(node); nodeStates[node] = nil end
		end)
	end
end

HitResourceEvent.OnServerEvent:Connect(function(player, hitPart)
	if not player.Character then return end
	if not hitPart or not hitPart.Parent then return end
	local root = player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local now = tick()
	local lastHit = playerHitCooldowns[player.UserId] or 0
	if now - lastHit < 0.4 then return end
	playerHitCooldowns[player.UserId] = now
	local node = findNodeRoot(hitPart); if not node then return end
	local nodeType = getNodeType(node); if not nodeType then return end
	local config = RESOURCE_NODES[nodeType]; if not config then return end
	local nodePos
	if node:IsA("Model") and node.PrimaryPart then nodePos = node.PrimaryPart.Position
	elseif node:IsA("BasePart") then nodePos = node.Position
	else return end
	if (root.Position - nodePos).Magnitude > HIT_RANGE then return end
	local state = getNodeState(node, nodeType); if state.Destroyed then return end
	local damage = config.HandDamage or 1
	local selectedItem = InventoryManager.GetSelectedItem(player)
	if selectedItem and config.ToolBonus then
		local itemData = ItemConfig.GetItem(selectedItem)
		if itemData and itemData.ToolType == config.ToolBonus then damage = config.ToolDamage or 2 end
	end
	if damage <= 0 then return end
	state.Health = state.Health - damage
	if node:IsA("Model") and node.PrimaryPart then
		local part = node.PrimaryPart; local cf = part.CFrame
		task.spawn(function()
			part.CFrame = cf * CFrame.new(math.random(-1, 1) * 0.2, 0, math.random(-1, 1) * 0.2)
			task.wait(0.1); if part.Parent then part.CFrame = cf end
		end)
	end
	if state.Health <= 0 then
		destroyNode(node, nodeType, config, player)
		print(string.format("[RESOURCE] %s destroyed a %s (variant %d)", player.Name, nodeType, getNodeVariant(node)))
	end
end)

EatEvent.OnServerEvent:Connect(function(player)
	local used = InventoryManager.UseSelectedItem(player)
	if used then print(string.format("[EAT] %s ate from hotbar", player.Name)) end
end)

DrinkWaterEvent.OnServerEvent:Connect(function(player)
	local result = tryDrinkWater(player)
	if not result then
		print("[WATER] Drink failed for " .. player.Name)
	end
end)

SelectSlotEvent.OnServerEvent:Connect(function(player, slotIndex)
	if type(slotIndex) ~= "number" then return end
	InventoryManager.SetSelectedSlot(player, slotIndex)
end)

DropItemEvent.OnServerEvent:Connect(function(player, slotIndex, count)
	if type(slotIndex) ~= "number" then return end
	if type(count) ~= "number" then return end
	InventoryManager.DropItem(player, slotIndex, math.max(1, math.floor(count)))
end)

SwapSlotsEvent.OnServerEvent:Connect(function(player, slotA, slotB)
	if type(slotA) ~= "number" or type(slotB) ~= "number" then return end
	InventoryManager.SwapSlots(player, slotA, slotB)
end)

Players.PlayerAdded:Connect(function(player)
	InventoryManager.InitPlayer(player)
	player.CharacterAdded:Connect(function()
		task.wait(1)
		InventoryManager.ClearInventory(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	playerHitCooldowns[player.UserId] = nil
	playerDrinkCooldowns[player.UserId] = nil
	InventoryManager.RemovePlayer(player)
end)

print("Resource system loaded")
