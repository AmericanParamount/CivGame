-- BuildingPlacement_Server Script
-- Location: ServerScriptService > BuildingPlacement_Server
-- Blueprint system with age/role validation and sound effects.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local TerrainConfig = require(Modules:WaitForChild("TerrainConfig"))
local TerrainIdentifier = require(Modules:WaitForChild("TerrainIdentifier"))
local BuildingConfig = require(Modules:WaitForChild("BuildingConfig"))

local Events = ReplicatedStorage:WaitForChild("Events")
local PlaceBuildingEvent = Events:WaitForChild("PlaceBuilding")

local InsertResourceEvent = Instance.new("RemoteEvent")
InsertResourceEvent.Name = "InsertResourceIntoBlueprint"
InsertResourceEvent.Parent = Events

local PLACE_RANGE = 30
local INSERT_RANGE = BuildingConfig.INSERT_RANGE
local BLUEPRINT_TRANSPARENCY = 0.7
local BLUEPRINT_COLOR = Color3.fromRGB(80, 160, 220)

local SOUNDS = {
	BlueprintPlace = "rbxassetid://9114074523",
	ResourceInsert = "rbxassetid://9114074523",
	BuildComplete  = "rbxassetid://5853940685",
}

local buildingsFolder = workspace:FindFirstChild("Buildings")
if not buildingsFolder then
	buildingsFolder = Instance.new("Folder")
	buildingsFolder.Name = "Buildings"; buildingsFolder.Parent = workspace
end

local function getBottomOffset(model)
	local lowestY = math.huge
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			local by = part.Position.Y - part.Size.Y / 2
			if by < lowestY then lowestY = by end
		end
	end
	return model:GetPivot().Position.Y - lowestY
end

local function placeOnGround(model, x, groundY, z, rotation)
	rotation = rotation or 0
	if model:IsA("Model") then
		model:PivotTo(CFrame.new(x, groundY + getBottomOffset(model), z) * CFrame.Angles(0, rotation, 0))
	elseif model:IsA("BasePart") then
		model.Position = Vector3.new(x, groundY + model.Size.Y / 2, z)
		model.CFrame = model.CFrame * CFrame.Angles(0, rotation, 0)
	end
end

local function anchorAndCollide(model)
	if model:IsA("Model") then
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then p.Anchored = true; p.CanCollide = true end
		end
	elseif model:IsA("BasePart") then model.Anchored = true; model.CanCollide = true end
end

local function isAreaClear(position, config, playerCharacter)
	local footprint = Vector3.new(config.FootprintX, config.FootprintY or 8, config.FootprintZ)
	local checkPos = CFrame.new(position + Vector3.new(0, footprint.Y / 2, 0))
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	local il = {}
	local tf = workspace:FindFirstChild("Map"); if tf then table.insert(il, tf) end
	if playerCharacter then table.insert(il, playerCharacter) end
	local pk = workspace:FindFirstChild("Pickups"); if pk then table.insert(il, pk) end
	op.FilterDescendantsInstances = il
	local parts = workspace:GetPartBoundsInBox(checkPos, footprint, op)
	for _, part in ipairs(parts) do
		if part.CanCollide and part.Transparency < 1 then return false end
	end
	return true
end

local function playSoundOnModel(model, soundId, volume)
	volume = volume or 0.7
	local target = nil
	if model:IsA("Model") and model.PrimaryPart then target = model.PrimaryPart
	elseif model:IsA("Model") then
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then target = p; break end
		end
	elseif model:IsA("BasePart") then target = model end
	if not target then return end
	local s = Instance.new("Sound")
	s.SoundId = soundId; s.Volume = volume
	s.RollOffMaxDistance = 60; s.RollOffMinDistance = 10
	s.Parent = target; s:Play()
	s.Ended:Connect(function() s:Destroy() end)
	task.delay(5, function() if s.Parent then s:Destroy() end end)
end

local function getPlayerAge(playerObj)
	local character = playerObj.Character
	if not character then return 0 end
	local ageVal = character:FindFirstChild("Age")
	if ageVal and ageVal:IsA("IntValue") then return ageVal.Value end
	if ageVal and ageVal:IsA("NumberValue") then return math.floor(ageVal.Value) end
	return 99
end

local function getPlayerRole(playerObj)
	return nil
end

local function canPlayerBuild(playerObj, buildingName)
	local config = BuildingConfig.GetBuilding(buildingName)
	if not config then return false end
	if config.MinAge then
		local age = getPlayerAge(playerObj)
		if age < config.MinAge then return false end
	end
	if config.RequiredRole then
		local role = getPlayerRole(playerObj)
		if role ~= config.RequiredRole then return false end
	end
	return true
end

local function getModelTemplate(buildingName)
	local repModels = ReplicatedStorage:FindFirstChild("Models")
	if repModels then
		local bf = repModels:FindFirstChild("Buildings")
		if bf then return bf:FindFirstChild(buildingName) end
	end
	return nil
end

function updateBlueprintBillboard(bp)
	local pf = bp:FindFirstChild("ResourceProgress"); if not pf then return end
	local bb = bp:FindFirstChild("ProgressBillboard"); if not bb then return end
	local pl = bb:FindFirstChild("ProgressLabel"); if not pl then return end
	local parts = {}; local allMet = true
	local resources = {}
	for _, v in ipairs(pf:GetChildren()) do
		if v:IsA("IntValue") and string.find(v.Name, "_Needed") then
			resources[string.gsub(v.Name, "_Needed", "")] = true
		end
	end
	for ct in pairs(resources) do
		local cur = pf:FindFirstChild(ct .. "_Current")
		local need = pf:FindFirstChild(ct .. "_Needed")
		if cur and need then
			table.insert(parts, ct .. ": " .. cur.Value .. "/" .. need.Value)
			if cur.Value < need.Value then allMet = false end
		end
	end
	table.sort(parts)
	pl.Text = table.concat(parts, "  |  ")
	pl.TextColor3 = allMet and Color3.fromRGB(80, 200, 80) or Color3.fromRGB(200, 190, 170)
	return allMet
end

local function createBlueprint(buildingName, position, rotation, playerObj)
	local config = BuildingConfig.GetBuilding(buildingName)
	if not config then return nil end
	local model = nil
	local template = getModelTemplate(buildingName)
	if template then
		model = template:Clone()
		if model:IsA("Model") and not model.PrimaryPart then
			for _, p in ipairs(model:GetDescendants()) do
				if p:IsA("BasePart") then model.PrimaryPart = p; break end
			end
		end
	else
		model = Instance.new("Model"); model.Name = buildingName
		local body = Instance.new("Part")
		body.Name = "Base"
		body.Size = Vector3.new(config.FootprintX, config.FootprintY or 6, config.FootprintZ)
		body.Anchored = true; body.CanCollide = true; body.CastShadow = false
		body.Material = Enum.Material.SmoothPlastic; body.Parent = model
		model.PrimaryPart = body
	end
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Transparency = BLUEPRINT_TRANSPARENCY; p.Color = BLUEPRINT_COLOR
			p.Anchored = true; p.CanCollide = false; p.CastShadow = false
		end
	end
	placeOnGround(model, position.X, position.Y, position.Z, rotation)
	Instance.new("StringValue", model).Name = "BuildingType"
	model.BuildingType.Value = buildingName
	Instance.new("StringValue", model).Name = "BlueprintStatus"
	model.BlueprintStatus.Value = "InProgress"
	Instance.new("StringValue", model).Name = "Owner"
	model.Owner.Value = playerObj.Name
	Instance.new("IntValue", model).Name = "OwnerId"
	model.OwnerId.Value = playerObj.UserId
	Instance.new("NumberValue", model).Name = "Rotation"
	model.Rotation.Value = rotation
	Instance.new("Vector3Value", model).Name = "GroundPosition"
	model.GroundPosition.Value = position
	local pf = Instance.new("Folder"); pf.Name = "ResourceProgress"; pf.Parent = model
	if config.Cost then
		for carryType, needed in pairs(config.Cost) do
			local cv = Instance.new("IntValue"); cv.Name = carryType .. "_Current"; cv.Value = 0; cv.Parent = pf
			local nv = Instance.new("IntValue"); nv.Name = carryType .. "_Needed"; nv.Value = needed; nv.Parent = pf
		end
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "ProgressBillboard"
	bb.Size = UDim2.new(0, 200, 0, 50)
	bb.StudsOffset = Vector3.new(0, (config.FootprintY or 6) + 2, 0)
	bb.AlwaysOnTop = false; bb.MaxDistance = 40; bb.Parent = model
	local nl = Instance.new("TextLabel"); nl.Name = "NameLabel"
	nl.Size = UDim2.new(1, 0, 0, 18); nl.BackgroundTransparency = 1
	nl.Text = config.DisplayName .. " (Blueprint)"
	nl.TextColor3 = Color3.fromRGB(80, 160, 220); nl.TextStrokeTransparency = 0.3
	nl.TextSize = 14; nl.Font = Enum.Font.GothamBold; nl.Parent = bb
	local pl = Instance.new("TextLabel"); pl.Name = "ProgressLabel"
	pl.Size = UDim2.new(1, 0, 0, 14); pl.Position = UDim2.new(0, 0, 0, 18)
	pl.BackgroundTransparency = 1; pl.TextColor3 = Color3.fromRGB(200, 190, 170)
	pl.TextStrokeTransparency = 0.3; pl.TextSize = 12; pl.Font = Enum.Font.Gotham
	pl.Parent = bb
	local hl = Instance.new("TextLabel"); hl.Name = "HintLabel"
	hl.Size = UDim2.new(1, 0, 0, 12); hl.Position = UDim2.new(0, 0, 0, 34)
	hl.BackgroundTransparency = 1; hl.Text = "[C] Insert resource while carrying"
	hl.TextColor3 = Color3.fromRGB(150, 145, 135); hl.TextStrokeTransparency = 0.3
	hl.TextSize = 10; hl.Font = Enum.Font.Gotham; hl.Parent = bb
	model.Parent = buildingsFolder
	updateBlueprintBillboard(model)
	playSoundOnModel(model, SOUNDS.BlueprintPlace, 0.5)
	print(string.format("[BUILD] %s placed blueprint for %s", playerObj.Name, config.DisplayName))
	return model
end

local function isBlueprintComplete(bp)
	local pf = bp:FindFirstChild("ResourceProgress"); if not pf then return true end
	local resources = {}
	for _, v in ipairs(pf:GetChildren()) do
		if v:IsA("IntValue") and string.find(v.Name, "_Needed") then
			resources[string.gsub(v.Name, "_Needed", "")] = true
		end
	end
	for ct in pairs(resources) do
		local cur = pf:FindFirstChild(ct .. "_Current")
		local need = pf:FindFirstChild(ct .. "_Needed")
		if cur and need and cur.Value < need.Value then return false end
	end
	return true
end

local function finishBlueprint(bp)
	local btVal = bp:FindFirstChild("BuildingType"); if not btVal then return end
	local buildingName = btVal.Value
	local config = BuildingConfig.GetBuilding(buildingName); if not config then return end
	local rotation = (bp:FindFirstChild("Rotation") or {}).Value or 0
	local groundPos = (bp:FindFirstChild("GroundPosition") or {}).Value or bp:GetPivot().Position
	local ownerName = (bp:FindFirstChild("Owner") or {}).Value or "Unknown"
	local ownerId = (bp:FindFirstChild("OwnerId") or {}).Value or 0
	playSoundOnModel(bp, SOUNDS.BuildComplete, 1.0)
	task.wait(0.3)
	bp:Destroy()
	local model = nil
	local template = getModelTemplate(buildingName)
	if template then
		model = template:Clone()
		if model:IsA("Model") and not model.PrimaryPart then
			for _, p in ipairs(model:GetDescendants()) do
				if p:IsA("BasePart") then model.PrimaryPart = p; break end
			end
		end
	else
		model = Instance.new("Model"); model.Name = buildingName
		local body = Instance.new("Part"); body.Name = "Base"
		body.Size = Vector3.new(config.FootprintX, config.FootprintY or 6, config.FootprintZ)
		body.Material = Enum.Material.WoodPlanks; body.Color = Color3.fromRGB(139, 105, 65)
		body.Parent = model; model.PrimaryPart = body
	end
	anchorAndCollide(model)
	placeOnGround(model, groundPos.X, groundPos.Y, groundPos.Z, rotation)
	Instance.new("StringValue", model).Name = "BuildingType"; model.BuildingType.Value = buildingName
	Instance.new("StringValue", model).Name = "Owner"; model.Owner.Value = ownerName
	Instance.new("IntValue", model).Name = "OwnerId"; model.OwnerId.Value = ownerId
	model.Parent = buildingsFolder
	print(string.format("[BUILD] Blueprint completed: %s by %s", config.DisplayName, ownerName))
end

PlaceBuildingEvent.OnServerEvent:Connect(function(playerObj, buildingName, position, rotation)
	if type(buildingName) ~= "string" then return end
	if typeof(position) ~= "Vector3" then return end
	if type(rotation) ~= "number" then return end
	local config = BuildingConfig.GetBuilding(buildingName)
	if not config then return end
	if not canPlayerBuild(playerObj, buildingName) then
		warn(playerObj.Name .. " failed age/role check for " .. buildingName)
		return
	end
	rotation = rotation % (math.pi * 2)
	local character = playerObj.Character; if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart"); if not root then return end
	if (root.Position - position).Magnitude > PLACE_RANGE then return end
	if config.AllowedTerrain then
		local terrainType = TerrainIdentifier.GetTerrainAtPosition(position)
		if not terrainType then return end
		local allowed = false
		for _, t in ipairs(config.AllowedTerrain) do
			if t == terrainType then allowed = true; break end
		end
		if not allowed then return end
	else
		local footprint = Vector3.new(config.FootprintX, 0, config.FootprintZ)
		if not TerrainIdentifier.CheckBuildingArea(position, footprint, rotation) then return end
	end
	if not isAreaClear(position, config, character) then return end
	createBlueprint(buildingName, position, rotation, playerObj)
end)

InsertResourceEvent.OnServerEvent:Connect(function(playerObj)
	local character = playerObj.Character; if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart"); if not root then return end
	local carriedItem, carryType = nil, nil
	for _, child in ipairs(character:GetChildren()) do
		local ct = child:FindFirstChild("CarryType")
		if ct and ct:IsA("StringValue") then
			carriedItem = child; carryType = ct.Value; break
		end
	end
	if not carriedItem or not carryType then return end
	local nearestBP, nearestDist = nil, INSERT_RANGE
	for _, bld in ipairs(buildingsFolder:GetChildren()) do
		local status = bld:FindFirstChild("BlueprintStatus")
		if status and status:IsA("StringValue") and status.Value == "InProgress" then
			local pos
			if bld:IsA("Model") and bld.PrimaryPart then pos = bld.PrimaryPart.Position
			elseif bld:IsA("Model") then pos = bld:GetPivot().Position end
			if pos then
				local d = (root.Position - pos).Magnitude
				if d < nearestDist then nearestBP = bld; nearestDist = d end
			end
		end
	end
	if not nearestBP then return end
	local pf = nearestBP:FindFirstChild("ResourceProgress"); if not pf then return end
	local curV = pf:FindFirstChild(carryType .. "_Current")
	local needV = pf:FindFirstChild(carryType .. "_Needed")
	if not curV or not needV then return end
	if curV.Value >= needV.Value then return end
	local mp = carriedItem:IsA("Model") and carriedItem.PrimaryPart or carriedItem
	if mp then local w = mp:FindFirstChild("CarryWeld"); if w then w:Destroy() end end
	carriedItem:Destroy()
	local hum = character:FindFirstChildOfClass("Humanoid")
	if hum then hum.WalkSpeed = 16 end
	local cse = Events:FindFirstChild("CarryStateChanged")
	if cse then cse:FireClient(playerObj, false, nil, false, 0) end
	curV.Value = curV.Value + 1
	playSoundOnModel(nearestBP, SOUNDS.ResourceInsert, 0.6)
	updateBlueprintBillboard(nearestBP)
	print(string.format("[BUILD] %s inserted %s (%d/%d)", playerObj.Name, carryType, curV.Value, needV.Value))
	if isBlueprintComplete(nearestBP) then
		task.delay(0.5, function()
			if nearestBP and nearestBP.Parent then finishBlueprint(nearestBP) end
		end)
	end
end)

print("Building placement system loaded")
