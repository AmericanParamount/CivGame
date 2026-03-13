-- CarrySystem_Server Script
-- Location: ServerScriptService > CarrySystem_Server
-- Carrying, dropping, planting. Auto-clears if item destroyed externally.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local TerrainConfig = require(Modules:WaitForChild("TerrainConfig"))
local TerrainIdentifier = require(Modules:WaitForChild("TerrainIdentifier"))

local Events = ReplicatedStorage:WaitForChild("Events")

local PickupEvent = Instance.new("RemoteEvent"); PickupEvent.Name = "PickupCarryItem"; PickupEvent.Parent = Events
local DropCarryEvent = Instance.new("RemoteEvent"); DropCarryEvent.Name = "DropCarryItem"; DropCarryEvent.Parent = Events
local CarryStateEvent = Instance.new("RemoteEvent"); CarryStateEvent.Name = "CarryStateChanged"; CarryStateEvent.Parent = Events
local PlaceSaplingEvent = Instance.new("RemoteEvent"); PlaceSaplingEvent.Name = "PlaceSapling"; PlaceSaplingEvent.Parent = Events
print("[CARRY] Events created")

local carrying = {}
local PICKUP_RANGE = 7
local TREE_FOOTPRINTS = { [1] = Vector3.new(10,12,10), [2] = Vector3.new(12,14,12) }
local DEFAULT_TREE_FOOTPRINT = Vector3.new(10,12,10)

local CARRY_ITEMS = {
	Log = { DisplayName = "Log", SlowMultiplier = 0.6, HoldOffset = CFrame.new(0, 3, 0) * CFrame.Angles(0, math.rad(90), 0), DefaultSize = Vector3.new(2,2,6), DefaultColor = Color3.fromRGB(120,80,40), DefaultMaterial = Enum.Material.WoodPlanks, Plantable = false },
	Stone = { DisplayName = "Stone", SlowMultiplier = 0.5, HoldOffset = CFrame.new(0,2.5,0), DefaultSize = Vector3.new(3,2.5,3), DefaultColor = Color3.fromRGB(140,135,125), DefaultMaterial = Enum.Material.Slate, Plantable = false },
	IronOre = { DisplayName = "Iron Ore", SlowMultiplier = 0.45, HoldOffset = CFrame.new(0,2.5,0), DefaultSize = Vector3.new(2.5,2,2.5), DefaultColor = Color3.fromRGB(120,85,60), DefaultMaterial = Enum.Material.Slate, Plantable = false },
	CopperOre = { DisplayName = "Copper Ore", SlowMultiplier = 0.45, HoldOffset = CFrame.new(0,2.5,0), DefaultSize = Vector3.new(2.5,2,2.5), DefaultColor = Color3.fromRGB(140,110,70), DefaultMaterial = Enum.Material.Slate, Plantable = false },
	Sapling = { DisplayName = "Sapling", SlowMultiplier = 0.8, HoldOffset = CFrame.new(0,2.5,0), DefaultSize = Vector3.new(1,3,1), DefaultColor = Color3.fromRGB(90,65,35), DefaultMaterial = Enum.Material.WoodPlanks, Plantable = true, GrowTime = 120, PlantableTerrains = {"Grassland","FertilePlains","ForestFloor","Wetland","IslandGround"} },
}

local function prepareModel(model)
	if not model:IsA("Model") then return end
	if not model.PrimaryPart then
		for _, part in ipairs(model:GetDescendants()) do if part:IsA("BasePart") then model.PrimaryPart = part; break end end
	end
	if model.PrimaryPart then
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") and part ~= model.PrimaryPart then
				part.Anchored = false; part.CanCollide = false
				local hasWeld = false
				for _, child in ipairs(part:GetChildren()) do if child:IsA("WeldConstraint") or child:IsA("Weld") then hasWeld = true; break end end
				if not hasWeld then local w = Instance.new("WeldConstraint"); w.Part0 = model.PrimaryPart; w.Part1 = part; w.Parent = part end
			end
		end
		model.PrimaryPart.Anchored = false; model.PrimaryPart.CanCollide = true
	end
end

local function getBottomOffset(model)
	local lowestY = math.huge
	for _, part in ipairs(model:GetDescendants()) do if part:IsA("BasePart") then local by = part.Position.Y - part.Size.Y/2; if by < lowestY then lowestY = by end end end
	return model:GetPivot().Position.Y - lowestY
end

local function placeOnGround(model, x, groundY, z, rotation)
	rotation = rotation or 0
	if model:IsA("Model") then model:PivotTo(CFrame.new(x, groundY + getBottomOffset(model), z) * CFrame.Angles(0, rotation, 0))
	elseif model:IsA("BasePart") then model.Position = Vector3.new(x, groundY + model.Size.Y/2, z); model.CFrame = model.CFrame * CFrame.Angles(0, rotation, 0) end
end

local function anchorAndCollide(model)
	if model:IsA("Model") then for _, p in ipairs(model:GetDescendants()) do if p:IsA("BasePart") then p.Anchored = true; p.CanCollide = true end end
	elseif model:IsA("BasePart") then model.Anchored = true; model.CanCollide = true end
end

local function isAreaClear(position, variant, playerCharacter)
	local footprint = TREE_FOOTPRINTS[variant] or DEFAULT_TREE_FOOTPRINT
	local checkPos = CFrame.new(position + Vector3.new(0, footprint.Y/2, 0))
	local op = OverlapParams.new(); op.FilterType = Enum.RaycastFilterType.Exclude
	local il = {}; local tf = workspace:FindFirstChild("Map"); if tf then table.insert(il, tf) end
	if playerCharacter then table.insert(il, playerCharacter) end
	local pk = workspace:FindFirstChild("Pickups"); if pk then table.insert(il, pk) end
	op.FilterDescendantsInstances = il
	local parts = workspace:GetPartBoundsInBox(checkPos, footprint, op)
	for _, part in ipairs(parts) do if part.CanCollide and part.Transparency < 1 then return false end end; return true
end

local function clearCarryState(userId)
	local cd = carrying[userId]; if not cd then return end
	if cd.DestroyConn then cd.DestroyConn:Disconnect() end
	local plr = Players:GetPlayerByUserId(userId)
	if plr then
		local character = plr.Character
		if character then local hum = character:FindFirstChildOfClass("Humanoid"); if hum then hum.WalkSpeed = 16 end end
		CarryStateEvent:FireClient(plr, false, nil, false, 0)
	end
	carrying[userId] = nil
end

local function createCarryModel(itemType)
	local config = CARRY_ITEMS[itemType]; if not config then return nil end
	local mf = ServerStorage:FindFirstChild("CarryModels")
	if mf then local t = mf:FindFirstChild(itemType); if t then local c = t:Clone(); prepareModel(c); return c end end
	local part = Instance.new("Part"); part.Name = itemType; part.Size = config.DefaultSize
	part.Color = config.DefaultColor; part.Material = config.DefaultMaterial; part.Anchored = false; part.CanCollide = true; return part
end

local function createSaplingModel(variant)
	local variantName = "Sapling" .. tostring(variant)
	local repModels = ReplicatedStorage:FindFirstChild("Models")
	if repModels then local sf = repModels:FindFirstChild("Saplings"); if sf then
		local t = sf:FindFirstChild(variantName) or sf:FindFirstChild("Sapling")
		if t then local c = t:Clone(); prepareModel(c); return c end
	end end
	local mf = ServerStorage:FindFirstChild("CarryModels")
	if mf then local t = mf:FindFirstChild("Sapling"); if t then local c = t:Clone(); prepareModel(c); return c end end
	local model = Instance.new("Model"); model.Name = "Sapling"
	local trunk = Instance.new("Part"); trunk.Name = "Trunk"; trunk.Size = Vector3.new(0.6,2,0.6)
	trunk.Color = Color3.fromRGB(90,65,35); trunk.Material = Enum.Material.WoodPlanks; trunk.Anchored = false; trunk.CanCollide = true; trunk.Parent = model
	local leaves = Instance.new("Part"); leaves.Name = "Leaves"; leaves.Size = Vector3.new(2,1.5,2)
	leaves.Shape = Enum.PartType.Ball; leaves.Color = Color3.fromRGB(60,130,50); leaves.Material = Enum.Material.SmoothPlastic
	leaves.Anchored = false; leaves.CanCollide = false; leaves.Position = trunk.Position + Vector3.new(0,1.5,0); leaves.Parent = model
	local w = Instance.new("WeldConstraint"); w.Part0 = trunk; w.Part1 = leaves; w.Parent = leaves
	model.PrimaryPart = trunk; return model
end

local function spawnCarryItem(itemType, position, count)
	local config = CARRY_ITEMS[itemType]; if not config then return end
	local pf = workspace:FindFirstChild("Pickups"); if not pf then pf = Instance.new("Folder"); pf.Name = "Pickups"; pf.Parent = workspace end
	for i = 1, (count or 1) do
		local item = createCarryModel(itemType); if not item then continue end
		local tv = Instance.new("StringValue"); tv.Name = "CarryType"; tv.Value = itemType; tv.Parent = item
		local bb = Instance.new("BillboardGui"); bb.Size = UDim2.new(0,100,0,25); bb.StudsOffset = Vector3.new(0,2,0); bb.AlwaysOnTop = false; bb.MaxDistance = 25; bb.Parent = item
		local lb = Instance.new("TextLabel"); lb.Size = UDim2.new(1,0,1,0); lb.BackgroundTransparency = 1
		lb.Text = "[E] " .. config.DisplayName; lb.TextColor3 = Color3.fromRGB(255,255,200); lb.TextStrokeTransparency = 0.5; lb.TextSize = 13; lb.Font = Enum.Font.GothamBold; lb.Parent = bb
		local offset = Vector3.new(math.random(-3,3), 3, math.random(-3,3))
		if item:IsA("Model") and item.PrimaryPart then item:PivotTo(CFrame.new(position + offset))
		elseif item:IsA("BasePart") then item.Position = position + offset end
		item.Parent = pf; task.delay(600, function() if item.Parent then item:Destroy() end end)
	end
end

local function spawnSaplingCarryItem(position, variant)
	variant = variant or 1
	local pf = workspace:FindFirstChild("Pickups"); if not pf then pf = Instance.new("Folder"); pf.Name = "Pickups"; pf.Parent = workspace end
	local item = createSaplingModel(variant); if not item then return end
	local tv = Instance.new("StringValue"); tv.Name = "CarryType"; tv.Value = "Sapling"; tv.Parent = item
	local vv = Instance.new("IntValue"); vv.Name = "Variant"; vv.Value = variant; vv.Parent = item
	local bb = Instance.new("BillboardGui"); bb.Size = UDim2.new(0,100,0,25); bb.StudsOffset = Vector3.new(0,2,0); bb.AlwaysOnTop = false; bb.MaxDistance = 25; bb.Parent = item
	local lb = Instance.new("TextLabel"); lb.Size = UDim2.new(1,0,1,0); lb.BackgroundTransparency = 1
	lb.Text = "[E] Sapling"; lb.TextColor3 = Color3.fromRGB(255,255,200); lb.TextStrokeTransparency = 0.5; lb.TextSize = 13; lb.Font = Enum.Font.GothamBold; lb.Parent = bb
	local offset = Vector3.new(math.random(-3,3), 3, math.random(-3,3))
	if item:IsA("Model") and item.PrimaryPart then item:PivotTo(CFrame.new(position + offset))
	elseif item:IsA("BasePart") then item.Position = position + offset end
	item.Parent = pf; task.delay(600, function() if item.Parent then item:Destroy() end end)
end

local sf = Instance.new("BindableFunction"); sf.Name = "SpawnCarryItem"
sf.OnInvoke = function(it, pos, ct) spawnCarryItem(it, pos, ct); return true end; sf.Parent = Events
local ssf = Instance.new("BindableFunction"); ssf.Name = "SpawnSaplingCarryItem"
ssf.OnInvoke = function(pos, var) spawnSaplingCarryItem(pos, var); return true end; ssf.Parent = Events
print("[CARRY] Spawn functions registered")

local function dropCarriedItem(plr)
	local cd = carrying[plr.UserId]; if not cd then return end
	local item = cd.Item; local config = cd.Config
	if cd.DestroyConn then cd.DestroyConn:Disconnect() end
	if not item or not item.Parent then carrying[plr.UserId] = nil; CarryStateEvent:FireClient(plr, false, nil, false, 0); return end
	local character = plr.Character; local root = character and character:FindFirstChild("HumanoidRootPart")
	local dropPos
	if root then dropPos = root.Position + root.CFrame.LookVector * 4 + Vector3.new(0, 0.5, 0)
	else dropPos = item:IsA("BasePart") and item.Position or item:GetPivot().Position end
	local mp = item:IsA("Model") and item.PrimaryPart or item
	local weld = mp:FindFirstChild("CarryWeld"); if weld then weld:Destroy() end
	if item:IsA("Model") then for _, p in ipairs(item:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = true end end
	elseif item:IsA("BasePart") then item.CanCollide = true end
	local pf = workspace:FindFirstChild("Pickups"); if not pf then pf = Instance.new("Folder"); pf.Name = "Pickups"; pf.Parent = workspace end
	if item:IsA("Model") and item.PrimaryPart then item:PivotTo(CFrame.new(dropPos))
	elseif item:IsA("BasePart") then item.Position = dropPos end
	item.Parent = pf
	local bb = Instance.new("BillboardGui"); bb.Size = UDim2.new(0,100,0,25); bb.StudsOffset = Vector3.new(0,2,0); bb.AlwaysOnTop = false; bb.MaxDistance = 25; bb.Parent = item
	local lb = Instance.new("TextLabel"); lb.Size = UDim2.new(1,0,1,0); lb.BackgroundTransparency = 1
	lb.Text = "[E] " .. config.DisplayName; lb.TextColor3 = Color3.fromRGB(255,255,200); lb.TextStrokeTransparency = 0.5; lb.TextSize = 13; lb.Font = Enum.Font.GothamBold; lb.Parent = bb
	if character then local hum = character:FindFirstChildOfClass("Humanoid"); if hum then hum.WalkSpeed = 16 end end
	carrying[plr.UserId] = nil; CarryStateEvent:FireClient(plr, false, nil, false, 0)
end

local function plantSapling(plr, targetPosition, rotation)
	rotation = rotation or 0; local cd = carrying[plr.UserId]; if not cd then return end
	if cd.ItemType ~= "Sapling" then return end; local config = cd.Config
	if not config.Plantable then return end
	local character = plr.Character; if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart"); if not root then return end
	if (root.Position - targetPosition).Magnitude > 20 then return end
	local terrainType = TerrainIdentifier.GetTerrainAtPosition(targetPosition); if not terrainType then return end
	local allowed = false
	for _, t in ipairs(config.PlantableTerrains) do if t == terrainType then allowed = true; break end end
	if not allowed then return end
	local variant = cd.Variant or 1
	if not isAreaClear(targetPosition, variant, character) then return end
	if cd.DestroyConn then cd.DestroyConn:Disconnect() end
	local item = cd.Item
	if item and item.Parent then
		local mp = item:IsA("Model") and item.PrimaryPart or item
		local weld = mp:FindFirstChild("CarryWeld"); if weld then weld:Destroy() end; item:Destroy()
	end
	local hum = character:FindFirstChildOfClass("Humanoid"); if hum then hum.WalkSpeed = 16 end
	carrying[plr.UserId] = nil; CarryStateEvent:FireClient(plr, false, nil, false, 0)
	local rf = workspace:FindFirstChild("Resources"); if not rf then rf = Instance.new("Folder"); rf.Name = "Resources"; rf.Parent = workspace end
	local variantName = "Sapling" .. tostring(variant); local plantedSapling = nil
	local resourceModels = ServerStorage:FindFirstChild("ResourceModels")
	if resourceModels then
		local template = resourceModels:FindFirstChild(variantName) or resourceModels:FindFirstChild("Sapling")
		if template then
			plantedSapling = template:Clone()
			if plantedSapling:IsA("Model") and not plantedSapling.PrimaryPart then
				for _, p in ipairs(plantedSapling:GetDescendants()) do if p:IsA("BasePart") then plantedSapling.PrimaryPart = p; break end end
			end
			anchorAndCollide(plantedSapling); placeOnGround(plantedSapling, targetPosition.X, targetPosition.Y, targetPosition.Z, rotation)
		end
	end
	if not plantedSapling then
		plantedSapling = Instance.new("Model"); plantedSapling.Name = "PlantedSapling"
		local trunk = Instance.new("Part"); trunk.Name = "Trunk"; trunk.Size = Vector3.new(0.8,2.5,0.8)
		trunk.Color = Color3.fromRGB(90,65,35); trunk.Material = Enum.Material.WoodPlanks; trunk.Anchored = true; trunk.CanCollide = true
		trunk.Position = targetPosition + Vector3.new(0,1.25,0); trunk.Parent = plantedSapling
		local leaves = Instance.new("Part"); leaves.Name = "Leaves"; leaves.Size = Vector3.new(2.5,2,2.5)
		leaves.Shape = Enum.PartType.Ball; leaves.Color = Color3.fromRGB(60,130,50); leaves.Material = Enum.Material.SmoothPlastic
		leaves.Anchored = true; leaves.CanCollide = true; leaves.Position = trunk.Position + Vector3.new(0,2,0); leaves.Parent = plantedSapling
		plantedSapling.PrimaryPart = trunk
		if rotation ~= 0 then plantedSapling:PivotTo(plantedSapling:GetPivot() * CFrame.Angles(0, rotation, 0)) end
	end
	local rt = Instance.new("StringValue"); rt.Name = "ResourceType"; rt.Value = "PlantedSapling"; rt.Parent = plantedSapling
	local vt = Instance.new("IntValue"); vt.Name = "Variant"; vt.Value = variant; vt.Parent = plantedSapling
	plantedSapling.Parent = rf
	task.delay(config.GrowTime or 120, function()
		if not plantedSapling or not plantedSapling.Parent then return end
		local treeVariantName = "Tree" .. tostring(variant); local fullTree = nil
		if resourceModels then
			local template = resourceModels:FindFirstChild(treeVariantName) or resourceModels:FindFirstChild("Tree")
			if template then
				fullTree = template:Clone()
				if fullTree:IsA("Model") and not fullTree.PrimaryPart then
					for _, p in ipairs(fullTree:GetDescendants()) do if p:IsA("BasePart") then fullTree.PrimaryPart = p; break end end
				end
			end
		end
		if not fullTree then
			fullTree = Instance.new("Model"); fullTree.Name = "Tree"
			local bt = Instance.new("Part"); bt.Name = "Trunk"; bt.Size = Vector3.new(2,8,2)
			bt.Color = Color3.fromRGB(100,70,40); bt.Material = Enum.Material.WoodPlanks; bt.Anchored = true; bt.CanCollide = true; bt.Parent = fullTree
			local bl = Instance.new("Part"); bl.Name = "Leaves"; bl.Size = Vector3.new(8,6,8)
			bl.Shape = Enum.PartType.Ball; bl.Color = Color3.fromRGB(50,120,45); bl.Material = Enum.Material.SmoothPlastic; bl.Anchored = true; bl.CanCollide = true; bl.Parent = fullTree
			fullTree.PrimaryPart = bt
		end
		local groundY = targetPosition.Y; local sapPos = plantedSapling:GetPivot().Position
		plantedSapling:Destroy(); anchorAndCollide(fullTree)
		placeOnGround(fullTree, sapPos.X, groundY, sapPos.Z, rotation)
		local tv = Instance.new("StringValue"); tv.Name = "ResourceType"; tv.Value = "Tree"; tv.Parent = fullTree
		local vTag = Instance.new("IntValue"); vTag.Name = "Variant"; vTag.Value = variant; vTag.Parent = fullTree
		fullTree.Parent = rf
	end)
end

PlaceSaplingEvent.OnServerEvent:Connect(function(plr, targetPosition, rotation)
	if typeof(targetPosition) ~= "Vector3" then return end
	rotation = type(rotation) == "number" and rotation or 0
	plantSapling(plr, targetPosition, rotation)
end)

PickupEvent.OnServerEvent:Connect(function(plr, targetItem)
	if not plr.Character then return end; if not targetItem or not targetItem.Parent then return end
	if carrying[plr.UserId] then return end
	local ctv = targetItem:FindFirstChild("CarryType"); if not ctv then return end
	local itemType = ctv.Value; local config = CARRY_ITEMS[itemType]; if not config then return end
	local root = plr.Character:FindFirstChild("HumanoidRootPart"); if not root then return end
	local itemPos
	if targetItem:IsA("Model") and targetItem.PrimaryPart then itemPos = targetItem.PrimaryPart.Position
	elseif targetItem:IsA("BasePart") then itemPos = targetItem.Position else return end
	if (root.Position - itemPos).Magnitude > PICKUP_RANGE then return end
	local head = plr.Character:FindFirstChild("Head"); if not head then return end
	local bb = targetItem:FindFirstChildOfClass("BillboardGui"); if bb then bb:Destroy() end
	if targetItem:IsA("Model") then
		for _, p in ipairs(targetItem:GetDescendants()) do if p:IsA("BasePart") then p.Anchored = false; p.CanCollide = false; p.Massless = true end end
	elseif targetItem:IsA("BasePart") then targetItem.Anchored = false; targetItem.CanCollide = false; targetItem.Massless = true end
	local mp = targetItem:IsA("Model") and targetItem.PrimaryPart or targetItem
	mp.CFrame = head.CFrame * config.HoldOffset
	local weld = Instance.new("WeldConstraint"); weld.Name = "CarryWeld"; weld.Part0 = head; weld.Part1 = mp; weld.Parent = mp
	targetItem.Parent = plr.Character
	local hum = plr.Character:FindFirstChildOfClass("Humanoid"); if hum then hum.WalkSpeed = hum.WalkSpeed * config.SlowMultiplier end
	local variant = 1; local vv = targetItem:FindFirstChild("Variant"); if vv and vv:IsA("IntValue") then variant = vv.Value end
	local destroyConn = targetItem.AncestryChanged:Connect(function(_, newParent)
		if newParent == nil then task.defer(function() clearCarryState(plr.UserId) end) end
	end)
	carrying[plr.UserId] = { Item = targetItem, ItemType = itemType, Config = config, Variant = variant, DestroyConn = destroyConn }
	CarryStateEvent:FireClient(plr, true, itemType, config.Plantable or false, variant)
end)

DropCarryEvent.OnServerEvent:Connect(function(plr) dropCarriedItem(plr) end)

Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid").Died:Connect(function()
			if carrying[plr.UserId] then dropCarriedItem(plr) end
		end)
	end)
end)

Players.PlayerRemoving:Connect(function(plr)
	if carrying[plr.UserId] then
		if carrying[plr.UserId].DestroyConn then carrying[plr.UserId].DestroyConn:Disconnect() end
		local item = carrying[plr.UserId].Item; if item and item.Parent then item:Destroy() end
		carrying[plr.UserId] = nil
	end
end)

print("[CARRY] Carry system loaded")
