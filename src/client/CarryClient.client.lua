-- CarryClient LocalScript
-- Location: StarterPlayerScripts > CarryClient
-- Parchment UI. E = pickup OR hold E over water to drink.
-- Q = drop. Click = plant. R/V/T/G/C placement controls.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local TerrainConfig = require(Modules:WaitForChild("TerrainConfig"))
local TerrainIdentifier = require(Modules:WaitForChild("TerrainIdentifier"))

local Events = ReplicatedStorage:WaitForChild("Events")
local PickupEvent = Events:WaitForChild("PickupCarryItem", 15)
local DropCarryEvent = Events:WaitForChild("DropCarryItem", 15)
local CarryStateEvent = Events:WaitForChild("CarryStateChanged", 15)
local PlaceSaplingEvent = Events:WaitForChild("PlaceSapling", 15)
local InsertResourceEvent = Events:WaitForChild("InsertResourceIntoBlueprint", 15)
local DrinkWaterEvent = Events:WaitForChild("DrinkWater", 15)

if not PickupEvent or not DropCarryEvent or not CarryStateEvent then warn("[CARRY] Missing events!"); return end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

local UI = { ToolbarPanel = "rbxassetid://84324990884668", Tooltip = "rbxassetid://106526935100610" }
local PT = { TextDark = Color3.fromRGB(62,48,32), TextMedium = Color3.fromRGB(100,80,55), TextLight = Color3.fromRGB(140,120,85), Gold = Color3.fromRGB(180,145,55), GoldDim = Color3.fromRGB(140,112,50), WaterBlue = Color3.fromRGB(45,130,190) }

local CARRY_ANIM_ID = "rbxassetid://122185740653253"
local DRINK_ANIM_ID = "rbxassetid://0"
local PICKUP_RANGE = 5
local isCarrying, isPlantable, carryVariant, carryTrack = false, false, 1, nil
local ghostModel, ghostValid, ghostRotation = nil, false, 0
local SNAP_STEP, FREEFORM_SPEED, freeformMode, holdingR = math.rad(15), math.rad(120), false, false
local gridEnabled, GRID_SIZE, GRID_SIZES, gridSizeIndex = false, 4, {1,2,4,8,16,32}, 3
local gridLines, gridFolder = {}, nil
local GHOST_TRANSPARENCY, VALID_COLOR, INVALID_COLOR = 0.5, Color3.fromRGB(80,200,80), Color3.fromRGB(200,80,80)
local PLANTABLE_TERRAINS = { Grassland=true, FertilePlains=true, ForestFloor=true, Wetland=true, IslandGround=true }
local TREE_FOOTPRINTS = { [1]=Vector3.new(10,12,10), [2]=Vector3.new(12,14,12) }
local DEFAULT_TREE_FOOTPRINT = Vector3.new(10,12,10)
local terrainFolder = workspace:FindFirstChild("Map")
local rayParams = RaycastParams.new(); rayParams.FilterType = Enum.RaycastFilterType.Include
if terrainFolder then rayParams.FilterDescendantsInstances = {terrainFolder} end
local overlapParams = OverlapParams.new(); overlapParams.FilterType = Enum.RaycastFilterType.Exclude
local PLANT_SOUND_ID, INSERT_SOUND_ID = "rbxassetid://9114074523", "rbxassetid://9114074523"
local isDrinking, drinkProgress, DRINK_DURATION, WATER_HOVER_RANGE = false, 0, 2.0, 8
local drinkTrack, savedWalkSpeed, holdingE, hoveringWater = nil, 16, false, false

local function updateOverlapFilter()
	local il = {}
	if terrainFolder then table.insert(il, terrainFolder) end
	if ghostModel then table.insert(il, ghostModel) end
	if player.Character then table.insert(il, player.Character) end
	local p = workspace:FindFirstChild("Pickups"); if p then table.insert(il, p) end
	overlapParams.FilterDescendantsInstances = il
end

-- =============================================
-- UI (created before connections)
-- =============================================
local gui = Instance.new("ScreenGui"); gui.Name = "CarryHUD"; gui.ResetOnSpawn = false; gui.Parent = playerGui

local carryBg = Instance.new("ImageLabel"); carryBg.Name = "CarryIndicator"
carryBg.Size = UDim2.new(0,400,0,40); carryBg.Position = UDim2.new(0.5,-200,0,55)
carryBg.BackgroundTransparency = 1; carryBg.Image = UI.Tooltip; carryBg.ScaleType = Enum.ScaleType.Stretch
carryBg.Visible = false; carryBg.Parent = gui
local label = Instance.new("TextLabel"); label.Size = UDim2.new(1,0,1,-6)
label.BackgroundTransparency = 1; label.Text = ""; label.TextColor3 = PT.TextDark
label.TextSize = 13; label.Font = Enum.Font.GothamBold; label.Parent = carryBg

local wGui = Instance.new("ScreenGui"); wGui.Name = "WaterCursorGui"; wGui.ResetOnSpawn = false; wGui.Parent = playerGui
local wFrame = Instance.new("ImageLabel"); wFrame.Name = "WaterPrompt"
wFrame.Size = UDim2.new(0,160,0,55); wFrame.BackgroundTransparency = 1
wFrame.Image = UI.Tooltip; wFrame.ScaleType = Enum.ScaleType.Stretch; wFrame.Visible = false; wFrame.Parent = wGui
local wText = Instance.new("TextLabel"); wText.Size = UDim2.new(1,0,0,18); wText.Position = UDim2.new(0,0,0,8)
wText.BackgroundTransparency = 1; wText.Text = "[Hold E] Drink"; wText.TextColor3 = PT.WaterBlue
wText.TextSize = 12; wText.Font = Enum.Font.GothamBold; wText.Parent = wFrame
local dBarBg = Instance.new("Frame"); dBarBg.Size = UDim2.new(0.8,0,0,8); dBarBg.Position = UDim2.new(0.1,0,0,30)
dBarBg.BackgroundColor3 = Color3.fromRGB(180,170,150); dBarBg.BackgroundTransparency = 0.3
dBarBg.BorderSizePixel = 0; dBarBg.Visible = false; dBarBg.Parent = wFrame
Instance.new("UICorner", dBarBg).CornerRadius = UDim.new(0,3)
local dBarFill = Instance.new("Frame"); dBarFill.Size = UDim2.new(0,0,1,0)
dBarFill.BackgroundColor3 = PT.WaterBlue; dBarFill.BorderSizePixel = 0; dBarFill.Parent = dBarBg
Instance.new("UICorner", dBarFill).CornerRadius = UDim.new(0,3)

-- =============================================
-- WATER
-- =============================================
local function isPartInWaterFolder(part)
	if not part then return false end
	local wf = workspace:FindFirstChild("Water"); if not wf then return false end
	local c = part; while c do if c == wf then return true end; c = c.Parent end; return false
end
local function isMouseOverWater()
	local ch = player.Character; if not ch then return false end
	local root = ch:FindFirstChild("HumanoidRootPart"); if not root then return false end
	local t = mouse.Target; if not t or not isPartInWaterFolder(t) then return false end
	local hp = mouse.Hit and mouse.Hit.Position; if not hp then return false end
	return (root.Position - hp).Magnitude <= WATER_HOVER_RANGE
end

local function startDrinking()
	if isDrinking or isCarrying then return end; isDrinking = true; drinkProgress = 0
	local ch = player.Character; if ch then local h = ch:FindFirstChildOfClass("Humanoid")
		if h then savedWalkSpeed = h.WalkSpeed; h.WalkSpeed = 0 end end
	if DRINK_ANIM_ID ~= "rbxassetid://0" then
		local ch2 = player.Character; if ch2 then local hum = ch2:FindFirstChildOfClass("Humanoid"); if hum then
			local anim = Instance.new("Animation"); anim.AnimationId = DRINK_ANIM_ID
			local an = hum:FindFirstChildOfClass("Animator"); if not an then an = Instance.new("Animator"); an.Parent = hum end
			drinkTrack = an:LoadAnimation(anim); drinkTrack.Priority = Enum.AnimationPriority.Action; drinkTrack.Looped = true; drinkTrack:Play(0.3)
		end end
	end
	wText.Text = "Drinking..."; dBarBg.Visible = true; dBarFill.Size = UDim2.new(0,0,1,0)
end
local function cancelDrinking()
	if not isDrinking then return end; isDrinking = false; drinkProgress = 0
	local ch = player.Character; if ch then local h = ch:FindFirstChildOfClass("Humanoid"); if h then h.WalkSpeed = savedWalkSpeed end end
	if drinkTrack and drinkTrack.IsPlaying then drinkTrack:Stop(0.3) end; drinkTrack = nil
	dBarBg.Visible = false; dBarFill.Size = UDim2.new(0,0,1,0); wText.Text = "[Hold E] Drink"
end
local function completeDrinking()
	if not isDrinking then return end; isDrinking = false; drinkProgress = 0
	local ch = player.Character; if ch then local h = ch:FindFirstChildOfClass("Humanoid"); if h then h.WalkSpeed = savedWalkSpeed end end
	if drinkTrack and drinkTrack.IsPlaying then drinkTrack:Stop(0.3) end; drinkTrack = nil
	dBarBg.Visible = false; dBarFill.Size = UDim2.new(0,0,1,0); wText.Text = "[Hold E] Drink"
	if DrinkWaterEvent then DrinkWaterEvent:FireServer() end
end

-- =============================================
-- GRID / ANIM / GHOST / SOUNDS / CARRY FIND
-- =============================================
local function snapToGrid(pos) if not gridEnabled then return pos end; return Vector3.new(math.round(pos.X/GRID_SIZE)*GRID_SIZE, pos.Y, math.round(pos.Z/GRID_SIZE)*GRID_SIZE) end
local function showGrid()
	if gridFolder then return end; gridFolder = Instance.new("Folder"); gridFolder.Name = "SaplingGrid"; gridFolder.Parent = workspace
	local ch = player.Character; if not ch then return end; local root = ch:FindFirstChild("HumanoidRootPart"); if not root then return end
	local center = snapToGrid(root.Position); local hr = 40
	for x = -hr,hr,GRID_SIZE do local l = Instance.new("Part"); l.Size = Vector3.new(0.1,0.05,hr*2); l.Position = Vector3.new(center.X+x,center.Y-1,center.Z)
		l.Anchored = true; l.CanCollide = false; l.CastShadow = false; l.Material = Enum.Material.Neon; l.Color = Color3.new(1,1,1); l.Transparency = 0.7; l.Parent = gridFolder; table.insert(gridLines, l) end
	for z = -hr,hr,GRID_SIZE do local l = Instance.new("Part"); l.Size = Vector3.new(hr*2,0.05,0.1); l.Position = Vector3.new(center.X,center.Y-1,center.Z+z)
		l.Anchored = true; l.CanCollide = false; l.CastShadow = false; l.Material = Enum.Material.Neon; l.Color = Color3.new(1,1,1); l.Transparency = 0.7; l.Parent = gridFolder; table.insert(gridLines, l) end
end
local function hideGrid() gridLines = {}; if gridFolder then gridFolder:Destroy(); gridFolder = nil end end
local function refreshGrid() hideGrid(); if gridEnabled then showGrid() end end

local function loadCarryAnim()
	local ch = player.Character; if not ch then return end; local hum = ch:FindFirstChildOfClass("Humanoid"); if not hum then return end
	local an = hum:FindFirstChildOfClass("Animator"); if not an then an = Instance.new("Animator"); an.Parent = hum end
	local anim = Instance.new("Animation"); anim.AnimationId = CARRY_ANIM_ID
	carryTrack = an:LoadAnimation(anim); carryTrack.Priority = Enum.AnimationPriority.Movement; carryTrack.Looped = true
end
player.CharacterAdded:Connect(function(c) c:WaitForChild("Humanoid"); task.wait(0.5); carryTrack = nil; drinkTrack = nil; loadCarryAnim()
	isCarrying = false; isPlantable = false; isDrinking = false; destroyGhost(); hideGrid(); hideToolbar() end)
if player.Character then task.spawn(function() task.wait(0.5); loadCarryAnim() end) end
local function startCarryAnim() if not carryTrack then loadCarryAnim() end; if carryTrack then carryTrack:Play(0.2) end end
local function stopCarryAnim() if carryTrack and carryTrack.IsPlaying then carryTrack:Stop(0.2) end end

-- Toolbar
local toolbarGui, rotationBtn, gridBtn, gridSizeLabel = nil,nil,nil,nil
local function updateToolbarUI()
	if rotationBtn then if freeformMode then rotationBtn.Text = "[T] Free"; rotationBtn.BackgroundColor3 = Color3.fromRGB(130,175,120)
		else rotationBtn.Text = "[T] 15° Snap"; rotationBtn.BackgroundColor3 = Color3.fromRGB(180,170,150) end end
	if gridBtn then if gridEnabled then gridBtn.Text = "[G] Grid ON"; gridBtn.BackgroundColor3 = Color3.fromRGB(130,175,120)
		else gridBtn.Text = "[G] Grid OFF"; gridBtn.BackgroundColor3 = Color3.fromRGB(180,170,150) end end
	if gridSizeLabel then gridSizeLabel.Text = GRID_SIZE.." st" end
end
local function showToolbar()
	if toolbarGui then return end; toolbarGui = Instance.new("ScreenGui"); toolbarGui.Name = "SaplingToolbar"; toolbarGui.ResetOnSpawn = false; toolbarGui.Parent = playerGui
	local panel = Instance.new("Frame"); panel.Size = UDim2.new(0,160,0,220); panel.Position = UDim2.new(1,-170,0.5,-110)
	panel.BackgroundTransparency = 1; panel.BorderSizePixel = 0; panel.Parent = toolbarGui
	local bg = Instance.new("ImageLabel"); bg.Size = UDim2.new(1,0,1,0); bg.BackgroundTransparency = 1; bg.Image = UI.ToolbarPanel; bg.ScaleType = Enum.ScaleType.Stretch; bg.ZIndex = 0; bg.Parent = panel
	local pad = Instance.new("UIPadding", panel); pad.PaddingTop = UDim.new(0,12); pad.PaddingBottom = UDim.new(0,12); pad.PaddingLeft = UDim.new(0,12); pad.PaddingRight = UDim.new(0,12)
	Instance.new("UIListLayout", panel).SortOrder = Enum.SortOrder.LayoutOrder; panel:FindFirstChildOfClass("UIListLayout").Padding = UDim.new(0,5)
	local ti = Instance.new("TextLabel"); ti.Size = UDim2.new(1,0,0,16); ti.BackgroundTransparency = 1; ti.Text = "TOOLS"; ti.TextColor3 = PT.TextDark; ti.TextSize = 12; ti.Font = Enum.Font.GothamBold; ti.LayoutOrder = 0; ti.Parent = panel
	rotationBtn = Instance.new("TextButton"); rotationBtn.Size = UDim2.new(1,0,0,26); rotationBtn.TextColor3 = PT.TextDark; rotationBtn.TextSize = 10; rotationBtn.Font = Enum.Font.GothamBold; rotationBtn.LayoutOrder = 1; rotationBtn.Parent = panel; Instance.new("UICorner", rotationBtn).CornerRadius = UDim.new(0,4)
	rotationBtn.MouseButton1Click:Connect(function() freeformMode = not freeformMode; updateToolbarUI() end)
	local rb = Instance.new("TextButton"); rb.Size = UDim2.new(1,0,0,20); rb.BackgroundColor3 = Color3.fromRGB(195,140,130); rb.TextColor3 = PT.TextDark; rb.TextSize = 9; rb.Font = Enum.Font.GothamBold; rb.Text = "[V] Reset"; rb.LayoutOrder = 2; rb.Parent = panel; Instance.new("UICorner", rb).CornerRadius = UDim.new(0,4)
	rb.MouseButton1Click:Connect(function() ghostRotation = 0 end)
	local s1 = Instance.new("Frame"); s1.Size = UDim2.new(1,0,0,1); s1.BackgroundColor3 = PT.GoldDim; s1.BackgroundTransparency = 0.5; s1.BorderSizePixel = 0; s1.LayoutOrder = 3; s1.Parent = panel
	gridBtn = Instance.new("TextButton"); gridBtn.Size = UDim2.new(1,0,0,26); gridBtn.TextColor3 = PT.TextDark; gridBtn.TextSize = 10; gridBtn.Font = Enum.Font.GothamBold; gridBtn.LayoutOrder = 4; gridBtn.Parent = panel; Instance.new("UICorner", gridBtn).CornerRadius = UDim.new(0,4)
	gridBtn.MouseButton1Click:Connect(function() gridEnabled = not gridEnabled; if gridEnabled then showGrid() else hideGrid() end; updateToolbarUI() end)
	local sr = Instance.new("Frame"); sr.Size = UDim2.new(1,0,0,26); sr.BackgroundTransparency = 1; sr.LayoutOrder = 5; sr.Parent = panel
	local mb = Instance.new("TextButton"); mb.Size = UDim2.new(0,26,1,0); mb.BackgroundColor3 = Color3.fromRGB(180,170,150); mb.TextColor3 = PT.TextDark; mb.TextSize = 14; mb.Font = Enum.Font.GothamBold; mb.Text = "-"; mb.Parent = sr; Instance.new("UICorner", mb).CornerRadius = UDim.new(0,4)
	gridSizeLabel = Instance.new("TextLabel"); gridSizeLabel.Size = UDim2.new(1,-60,1,0); gridSizeLabel.Position = UDim2.new(0,30,0,0); gridSizeLabel.BackgroundTransparency = 1; gridSizeLabel.TextColor3 = PT.TextDark; gridSizeLabel.TextSize = 10; gridSizeLabel.Font = Enum.Font.GothamBold; gridSizeLabel.Parent = sr
	local pb = Instance.new("TextButton"); pb.Size = UDim2.new(0,26,1,0); pb.Position = UDim2.new(1,-26,0,0); pb.BackgroundColor3 = Color3.fromRGB(180,170,150); pb.TextColor3 = PT.TextDark; pb.TextSize = 14; pb.Font = Enum.Font.GothamBold; pb.Text = "+"; pb.Parent = sr; Instance.new("UICorner", pb).CornerRadius = UDim.new(0,4)
	mb.MouseButton1Click:Connect(function() if gridSizeIndex > 1 then gridSizeIndex -= 1; GRID_SIZE = GRID_SIZES[gridSizeIndex]; refreshGrid(); updateToolbarUI() end end)
	pb.MouseButton1Click:Connect(function() if gridSizeIndex < #GRID_SIZES then gridSizeIndex += 1; GRID_SIZE = GRID_SIZES[gridSizeIndex]; refreshGrid(); updateToolbarUI() end end)
	local ht = Instance.new("TextLabel"); ht.Size = UDim2.new(1,0,0,40); ht.BackgroundTransparency = 1; ht.Text = "R = Rotate | V = Reset\nT = Mode | G = Grid"; ht.TextColor3 = PT.TextLight; ht.TextSize = 9; ht.Font = Enum.Font.Gotham; ht.TextYAlignment = Enum.TextYAlignment.Top; ht.LayoutOrder = 7; ht.Parent = panel
	updateToolbarUI()
end
function hideToolbar() if toolbarGui then toolbarGui:Destroy(); toolbarGui = nil; rotationBtn = nil; gridBtn = nil; gridSizeLabel = nil end end

-- Ghost
local function isAreaClear(pos, var)
	local fp = TREE_FOOTPRINTS[var] or DEFAULT_TREE_FOOTPRINT; updateOverlapFilter()
	local parts = workspace:GetPartBoundsInBox(CFrame.new(pos + Vector3.new(0,fp.Y/2,0)), fp, overlapParams)
	for _, p in ipairs(parts) do if p.CanCollide and p.Transparency < 1 then return false end end; return true
end
local function getGhostBottomOffset()
	if not ghostModel then return 0 end; local ly = math.huge
	for _, p in ipairs(ghostModel:GetDescendants()) do if p:IsA("BasePart") then local by = p.Position.Y - p.Size.Y/2; if by < ly then ly = by end end end
	return ghostModel:GetPivot().Position.Y - ly
end
local function createGhost(var)
	if ghostModel then ghostModel:Destroy(); ghostModel = nil end; var = var or 1
	local src = nil; local rm = ReplicatedStorage:FindFirstChild("Models")
	if rm then local sf = rm:FindFirstChild("Saplings"); if sf then src = sf:FindFirstChild("Sapling"..var) or sf:FindFirstChild("Sapling") end end
	if src then ghostModel = src:Clone(); ghostModel.Name = "SaplingGhost"
		for _, p in ipairs(ghostModel:GetDescendants()) do if p:IsA("BasePart") then p.Transparency = GHOST_TRANSPARENCY; p.Color = VALID_COLOR; p.Anchored = true; p.CanCollide = false; p.CastShadow = false end end
		if ghostModel:IsA("Model") and not ghostModel.PrimaryPart then for _, p in ipairs(ghostModel:GetDescendants()) do if p:IsA("BasePart") then ghostModel.PrimaryPart = p; break end end end
	else ghostModel = Instance.new("Model"); ghostModel.Name = "SaplingGhost"
		local tr = Instance.new("Part"); tr.Name = "Trunk"; tr.Size = Vector3.new(0.8,2.5,0.8); tr.Color = VALID_COLOR; tr.Material = Enum.Material.SmoothPlastic; tr.Anchored = true; tr.CanCollide = false; tr.CastShadow = false; tr.Transparency = GHOST_TRANSPARENCY; tr.Parent = ghostModel
		local lv = Instance.new("Part"); lv.Name = "Leaves"; lv.Size = Vector3.new(2.5,2,2.5); lv.Shape = Enum.PartType.Ball; lv.Color = VALID_COLOR; lv.Material = Enum.Material.SmoothPlastic; lv.Anchored = true; lv.CanCollide = false; lv.CastShadow = false; lv.Transparency = GHOST_TRANSPARENCY; lv.Position = tr.Position + Vector3.new(0,2,0); lv.Parent = ghostModel
		ghostModel.PrimaryPart = tr
	end; ghostModel.Parent = workspace
end
function destroyGhost() if ghostModel then ghostModel:Destroy(); ghostModel = nil end end
local function updateGhostColor(v) if not ghostModel then return end; local c = v and VALID_COLOR or INVALID_COLOR; for _, p in ipairs(ghostModel:GetDescendants()) do if p:IsA("BasePart") then p.Color = c end end end
local function getMouseTerrainPosition() local r = camera:ViewportPointToRay(mouse.X, mouse.Y); local res = workspace:Raycast(r.Origin, r.Direction*500, rayParams); return res and res.Position or nil end
local function updateGhost()
	if not isCarrying or not isPlantable or not ghostModel then return end
	local hp = getMouseTerrainPosition(); if not hp then ghostValid = false; updateGhostColor(false); return end
	hp = snapToGrid(hp); local bo = getGhostBottomOffset()
	ghostModel:PivotTo(CFrame.new(hp.X, hp.Y+bo, hp.Z) * CFrame.Angles(0, ghostRotation, 0))
	local tt = TerrainIdentifier.GetTerrainAtPosition(hp)
	if not tt or not PLANTABLE_TERRAINS[tt] then ghostValid = false; updateGhostColor(false); return end
	if not isAreaClear(hp, carryVariant) then ghostValid = false; updateGhostColor(false); return end
	ghostValid = true; updateGhostColor(true)
end

local function playSound(id) local ch = player.Character; if not ch then return end; local root = ch:FindFirstChild("HumanoidRootPart"); if not root then return end
	local s = Instance.new("Sound"); s.SoundId = id; s.Volume = 0.6; s.Parent = root; s:Play(); s.Ended:Connect(function() s:Destroy() end); task.delay(3, function() if s.Parent then s:Destroy() end end) end
local function findNearbyCarryItem()
	local ch = player.Character; if not ch then return nil end; local root = ch:FindFirstChild("HumanoidRootPart"); if not root then return nil end
	local pf = workspace:FindFirstChild("Pickups"); if not pf then return nil end; local cl, cd = nil, PICKUP_RANGE
	for _, item in ipairs(pf:GetChildren()) do if item:FindFirstChild("CarryType") then local pos
		if item:IsA("Model") and item.PrimaryPart then pos = item.PrimaryPart.Position elseif item:IsA("BasePart") then pos = item.Position end
		if pos then local d = (root.Position-pos).Magnitude; if d < cd then cl = item; cd = d end end end end; return cl
end

-- Input
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.E then
		if isDrinking or isCarrying then return end
		local item = findNearbyCarryItem(); if item then PickupEvent:FireServer(item); return end
		holdingE = true; if hoveringWater then startDrinking() end
	end
	if input.KeyCode == Enum.KeyCode.Q then if isCarrying then DropCarryEvent:FireServer() end end
	if input.KeyCode == Enum.KeyCode.R then if isCarrying and isPlantable then if freeformMode then holdingR = true else ghostRotation += SNAP_STEP; if ghostRotation >= math.pi*2 then ghostRotation = 0 end end end end
	if input.KeyCode == Enum.KeyCode.V then if isCarrying and isPlantable then ghostRotation = 0 end end
	if input.KeyCode == Enum.KeyCode.T then if isCarrying and isPlantable then freeformMode = not freeformMode; updateToolbarUI() end end
	if input.KeyCode == Enum.KeyCode.G then if isCarrying and isPlantable then gridEnabled = not gridEnabled; if gridEnabled then showGrid() else hideGrid() end; updateToolbarUI() end end
	if input.KeyCode == Enum.KeyCode.C then if isCarrying and InsertResourceEvent then playSound(INSERT_SOUND_ID); InsertResourceEvent:FireServer() end end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.R then holdingR = false end
	if input.KeyCode == Enum.KeyCode.E then holdingE = false; if isDrinking then cancelDrinking() end end
end)
mouse.Button1Down:Connect(function()
	if not isCarrying or not isPlantable or not ghostValid or not PlaceSaplingEvent then return end
	local hp = getMouseTerrainPosition(); if not hp then return end; hp = snapToGrid(hp); playSound(PLANT_SOUND_ID); PlaceSaplingEvent:FireServer(hp, ghostRotation)
end)

-- Render
local gridUpdateTimer = 0
RunService.RenderStepped:Connect(function(dt)
	if isCarrying and isPlantable then
		if freeformMode and holdingR then ghostRotation += FREEFORM_SPEED*dt; if ghostRotation >= math.pi*2 then ghostRotation -= math.pi*2 end end
		updateGhost()
		if gridEnabled then gridUpdateTimer += dt; if gridUpdateTimer >= 0.5 then gridUpdateTimer = 0; hideGrid(); showGrid() end end
	end
	if not isCarrying and not isDrinking then
		hoveringWater = isMouseOverWater()
		if hoveringWater then wFrame.Visible = true; wFrame.Position = UDim2.new(0, mouse.X+16, 0, mouse.Y-10) else wFrame.Visible = false end
	elseif isDrinking then wFrame.Visible = true; if not isMouseOverWater() then cancelDrinking() end
	else hoveringWater = false; wFrame.Visible = false end
	if isDrinking then drinkProgress += dt; local r = math.clamp(drinkProgress/DRINK_DURATION,0,1); dBarFill.Size = UDim2.new(r,0,1,0); if r >= 1 then completeDrinking() end end
end)

-- Server state
CarryStateEvent.OnClientEvent:Connect(function(carrying, itemType, plantable, variant)
	isCarrying = carrying; isPlantable = plantable or false; carryVariant = variant or 1
	if carrying then startCarryAnim(); if isPlantable then ghostRotation = 0; holdingR = false; createGhost(carryVariant); showToolbar(); if gridEnabled then showGrid() end end
		wFrame.Visible = false; if isDrinking then cancelDrinking() end
	else stopCarryAnim(); isPlantable = false; destroyGhost(); hideGrid(); hideToolbar() end
	local cb = player:FindFirstChild("CombatCarryBinding"); if cb then cb:Fire(carrying) end
end)
CarryStateEvent.OnClientEvent:Connect(function(carrying, itemType, plantable)
	if carrying and itemType then
		label.Text = plantable and (itemType..": [Click] Plant  [R] Rotate  [C] Build  [Q] Drop") or (itemType..": [C] Insert  [Q] Drop")
		carryBg.Visible = true
	else carryBg.Visible = false end
end)
player.CharacterAdded:Connect(function() isCarrying = false; isPlantable = false; isDrinking = false; carryTrack = nil; drinkTrack = nil; holdingE = false
	destroyGhost(); hideGrid(); hideToolbar(); wFrame.Visible = false; dBarBg.Visible = false end)

print("[CARRY CLIENT] Carry client loaded")
