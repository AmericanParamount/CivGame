-- BuildingPlacement LocalScript
-- Location: StarterPlayerScripts > BuildingPlacement
-- Dark teal + gold build menu (unified with HUD aesthetic). 2-column layout.
-- B = toggle. R/T/G/V placement controls.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local TerrainConfig = require(Modules:WaitForChild("TerrainConfig"))
local TerrainIdentifier = require(Modules:WaitForChild("TerrainIdentifier"))
local BuildingConfig = require(Modules:WaitForChild("BuildingConfig"))

local Events = ReplicatedStorage:WaitForChild("Events")
local PlaceBuildingEvent = Events:WaitForChild("PlaceBuilding")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

local SOUNDS = {
	MenuOpen      = "rbxassetid://97861038165143",
	MenuClose     = "rbxassetid://110059957735733",
	CategoryClick = "rbxassetid://76353543802706",
	TileClick     = "rbxassetid://88442833509532",
	TileHover     = "rbxassetid://139800881181209",
	PlaceClick    = "rbxassetid://77117485112690",
	LockedClick   = "rbxassetid://87519554692663",
}

-- =============================================
-- PALETTE (unified with CharacterHUD / InventoryClient)
-- =============================================
local C = {
	Panel      = Color3.fromRGB(15, 30, 30),
	PanelTop   = Color3.fromRGB(18, 36, 36),
	PanelBot   = Color3.fromRGB(12, 24, 24),
	SlotTop    = Color3.fromRGB(22, 40, 40),
	SlotBot    = Color3.fromRGB(14, 30, 30),
	SlotHover  = Color3.fromRGB(28, 48, 48),
	Gold       = Color3.fromRGB(184, 148, 62),
	GoldDim    = Color3.fromRGB(107, 90, 42),
	GoldTxt    = Color3.fromRGB(212, 184, 106),
	GoldWarm   = Color3.fromRGB(212, 170, 74),
	GoldBright = Color3.fromRGB(232, 196, 82),
	Label      = Color3.fromRGB(138, 154, 138),
	Key        = Color3.fromRGB(90, 106, 90),
	Danger     = Color3.fromRGB(160, 64, 40),
	Green      = Color3.fromRGB(70, 150, 65),
	IconBg     = Color3.fromRGB(14, 28, 28),
}

-- =============================================
-- TWEEN CONFIGS
-- =============================================
local tweenOpen    = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local tweenClose   = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local tweenHoverIn = TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local tweenHoverOut= TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local tweenSlide   = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local tweenFade    = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- =============================================
-- UI SOUND PLAYER
-- =============================================
local function playUISound(soundId, volume)
	local s = Instance.new("Sound")
	s.SoundId = soundId
	s.Volume = volume or 0.4
	s.PlayOnRemove = false
	s.Parent = SoundService
	s:Play()
	s.Ended:Connect(function() s:Destroy() end)
	task.delay(3, function() if s.Parent then s:Destroy() end end)
end

-- =============================================
-- PLACEMENT STATE
-- =============================================
local isPlacing = false
local currentBuildingName = nil
local ghostModel = nil
local currentRotation = 0
local canPlace = false
local menuOpen = false

local SNAP_STEP = math.rad(15)
local FREEFORM_SPEED = math.rad(120)
local freeformMode = false
local holdingR = false

local gridEnabled = false
local GRID_SIZE = 4
local GRID_SIZES = {1, 2, 4, 8, 16, 32}
local gridSizeIndex = 3
local gridLines = {}
local gridFolder = nil

local VALID_COLOR = Color3.fromRGB(80, 200, 80)
local INVALID_COLOR = Color3.fromRGB(200, 80, 80)
local GHOST_TRANSPARENCY = 0.5

local terrainFolder = workspace:FindFirstChild("Map")
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
if terrainFolder then rayParams.FilterDescendantsInstances = {terrainFolder} end

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude

local menuGui = nil
local currentCategory = "All"
local selectedBuilding = nil
local searchText = ""
local gridContainer = nil
local detailStrip = nil
local categoryButtons = {}
local catIndicators = {}
local viewportConnections = {}

-- =============================================
-- HELPERS
-- =============================================
local function updateOverlapFilter()
	local il = {}
	if terrainFolder then table.insert(il, terrainFolder) end
	if ghostModel then table.insert(il, ghostModel) end
	if player.Character then table.insert(il, player.Character) end
	local p = workspace:FindFirstChild("Pickups"); if p then table.insert(il, p) end
	overlapParams.FilterDescendantsInstances = il
end

local function getGhostBottomOffset()
	if not ghostModel then return 0 end
	local ly = math.huge
	for _, p in ipairs(ghostModel:GetDescendants()) do
		if p:IsA("BasePart") then local by = p.Position.Y - p.Size.Y/2; if by < ly then ly = by end end
	end
	return ghostModel:GetPivot().Position.Y - ly
end

local function getMouseTerrainPosition()
	local r = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local res = workspace:Raycast(r.Origin, r.Direction * 500, rayParams)
	return res and res.Position or nil
end

local function snapToGrid(pos)
	if not gridEnabled then return pos end
	return Vector3.new(math.round(pos.X/GRID_SIZE)*GRID_SIZE, pos.Y, math.round(pos.Z/GRID_SIZE)*GRID_SIZE)
end

local function isAreaClear(position, buildingName)
	local config = BuildingConfig.GetBuilding(buildingName); if not config then return false end
	local fp = Vector3.new(config.FootprintX, config.FootprintY or 8, config.FootprintZ)
	updateOverlapFilter()
	local parts = workspace:GetPartBoundsInBox(CFrame.new(position + Vector3.new(0,fp.Y/2,0)), fp, overlapParams)
	for _, part in ipairs(parts) do if part.CanCollide and part.Transparency < 1 then return false end end
	return true
end

local function getPlayerAge()
	local c = player.Character; if not c then return 0 end
	local a = c:FindFirstChild("Age")
	if a and a:IsA("IntValue") then return a.Value end
	if a and a:IsA("NumberValue") then return math.floor(a.Value) end
	return 99
end
local function getPlayerRole() return nil end

local function canPlayerBuild(bn)
	local config = BuildingConfig.GetBuilding(bn); if not config then return false, "Unknown" end
	local age = getPlayerAge()
	if config.MinAge and age < config.MinAge then return false, "Age "..config.MinAge.."+" end
	if config.RequiredRole then
		if getPlayerRole() ~= config.RequiredRole then return false, config.RequiredRole.." required" end
	end
	return true, nil
end

-- =============================================
-- GRID (world-space placement grid)
-- =============================================
local function showGrid()
	if gridFolder then return end
	gridFolder = Instance.new("Folder"); gridFolder.Name = "PlacementGrid"; gridFolder.Parent = workspace
	local c = player.Character; if not c then return end
	local root = c:FindFirstChild("HumanoidRootPart"); if not root then return end
	local center = snapToGrid(root.Position); local hr = 40
	for x = -hr, hr, GRID_SIZE do
		local l = Instance.new("Part"); l.Size = Vector3.new(0.1,0.05,hr*2)
		l.Position = Vector3.new(center.X+x, center.Y-1, center.Z)
		l.Anchored = true; l.CanCollide = false; l.CastShadow = false
		l.Material = Enum.Material.Neon; l.Color = Color3.new(1,1,1); l.Transparency = 0.7
		l.Parent = gridFolder; table.insert(gridLines, l)
	end
	for z = -hr, hr, GRID_SIZE do
		local l = Instance.new("Part"); l.Size = Vector3.new(hr*2,0.05,0.1)
		l.Position = Vector3.new(center.X, center.Y-1, center.Z+z)
		l.Anchored = true; l.CanCollide = false; l.CastShadow = false
		l.Material = Enum.Material.Neon; l.Color = Color3.new(1,1,1); l.Transparency = 0.7
		l.Parent = gridFolder; table.insert(gridLines, l)
	end
end
local function hideGrid() gridLines = {}; if gridFolder then gridFolder:Destroy(); gridFolder = nil end end
local function refreshGrid() hideGrid(); if gridEnabled then showGrid() end end

-- =============================================
-- GHOST MODEL
-- =============================================
local function createGhost(bn)
	if ghostModel then ghostModel:Destroy(); ghostModel = nil end
	local src = nil; local rm = ReplicatedStorage:FindFirstChild("Models")
	if rm then local bf = rm:FindFirstChild("Buildings"); if bf then src = bf:FindFirstChild(bn) end end
	if src then
		ghostModel = src:Clone(); ghostModel.Name = "BuildingGhost"
		for _, p in ipairs(ghostModel:GetDescendants()) do
			if p:IsA("BasePart") then p.Transparency = GHOST_TRANSPARENCY; p.Color = VALID_COLOR; p.Anchored = true; p.CanCollide = false; p.CastShadow = false end
		end
		if ghostModel:IsA("Model") and not ghostModel.PrimaryPart then
			for _, p in ipairs(ghostModel:GetDescendants()) do if p:IsA("BasePart") then ghostModel.PrimaryPart = p; break end end
		end
	else
		local config = BuildingConfig.GetBuilding(bn); if not config then return end
		ghostModel = Instance.new("Model"); ghostModel.Name = "BuildingGhost"
		local body = Instance.new("Part"); body.Name = "GhostBody"
		body.Size = Vector3.new(config.FootprintX, config.FootprintY or 6, config.FootprintZ)
		body.Anchored = true; body.CanCollide = false; body.CastShadow = false
		body.Material = Enum.Material.SmoothPlastic; body.Transparency = GHOST_TRANSPARENCY; body.Color = VALID_COLOR
		body.Parent = ghostModel; ghostModel.PrimaryPart = body
	end
	ghostModel.Parent = workspace
end
local function destroyGhost() if ghostModel then ghostModel:Destroy(); ghostModel = nil end end
local function updateGhostColor(c) if not ghostModel then return end; for _, p in ipairs(ghostModel:GetDescendants()) do if p:IsA("BasePart") then p.Color = c end end end

local function updateGhost()
	if not isPlacing or not ghostModel then return end
	local hp = getMouseTerrainPosition(); if not hp then canPlace = false; updateGhostColor(INVALID_COLOR); return end
	hp = snapToGrid(hp); local bo = getGhostBottomOffset()
	ghostModel:PivotTo(CFrame.new(hp.X, hp.Y+bo, hp.Z) * CFrame.Angles(0, currentRotation, 0))
	local config = BuildingConfig.GetBuilding(currentBuildingName)
	if config and config.AllowedTerrain then
		local tt = TerrainIdentifier.GetTerrainAtPosition(hp); local ok = false
		for _, t in ipairs(config.AllowedTerrain) do if t == tt then ok = true; break end end
		if not ok then canPlace = false; updateGhostColor(INVALID_COLOR); return end
	else
		local fp = Vector3.new(config.FootprintX, 0, config.FootprintZ)
		if not TerrainIdentifier.CheckBuildingArea(hp, fp, currentRotation) then canPlace = false; updateGhostColor(INVALID_COLOR); return end
	end
	if not isAreaClear(hp, currentBuildingName) then canPlace = false; updateGhostColor(INVALID_COLOR); return end
	canPlace = true; updateGhostColor(VALID_COLOR)
end

local function cleanupViewportConnections()
	for _, conn in ipairs(viewportConnections) do
		if conn.Connected then conn:Disconnect() end
	end
	viewportConnections = {}
end

-- =============================================
-- VIEWPORT PREVIEW HELPER
-- =============================================
local function createViewportPreview(parent, buildingName, size)
	local config = BuildingConfig.GetBuilding(buildingName)
	local vpf = Instance.new("ViewportFrame")
	vpf.Size = size or UDim2.new(1, -8, 1, -28)
	vpf.Position = UDim2.new(0.5, 0, 0.5, -6)
	vpf.AnchorPoint = Vector2.new(0.5, 0.5)
	vpf.BackgroundTransparency = 1
	vpf.Ambient = Color3.fromRGB(140, 140, 130)
	vpf.LightColor = Color3.fromRGB(255, 250, 240)
	vpf.LightDirection = Vector3.new(-1, -1, -1)
	vpf.ZIndex = 2; vpf.Parent = parent

	local previewModel = nil
	local repModels = ReplicatedStorage:FindFirstChild("Models")
	if repModels then
		local bf = repModels:FindFirstChild("Buildings")
		if bf then
			local src = bf:FindFirstChild(buildingName)
			if src then previewModel = src:Clone(); previewModel.Parent = vpf end
		end
	end
	if not previewModel then
		previewModel = Instance.new("Model")
		local box = Instance.new("Part")
		box.Size = Vector3.new(config.FootprintX or 4, config.FootprintY or 4, config.FootprintZ or 4)
		box.Color = Color3.fromRGB(180, 140, 80)
		box.Material = Enum.Material.WoodPlanks; box.Anchored = true
		box.Parent = previewModel; previewModel.PrimaryPart = box
		previewModel.Parent = vpf
	end

	local vpCam = Instance.new("Camera"); vpf.CurrentCamera = vpCam; vpCam.Parent = vpf
	local modelCF, modelSize = previewModel:GetBoundingBox()
	local maxDim = math.max(modelSize.X, modelSize.Y, modelSize.Z)
	local camDist = maxDim * 1.6
	local center = modelCF.Position
	local angle = math.rad(35)
	vpCam.CFrame = CFrame.new(
		center + Vector3.new(math.cos(angle) * camDist * 0.8, camDist * 0.5, math.sin(angle) * camDist * 0.8),
		center
	)
	return vpf
end

-- =============================================
-- BUILD MENU — DETAIL STRIP (bottom overlay)
-- =============================================
local SIDEBAR_W = 85
local STRIP_H = 90

local function updateDetailStrip()
	if not detailStrip then return end
	for _, ch in ipairs(detailStrip:GetChildren()) do
		if not ch:IsA("UICorner") and ch.Name ~= "StripDivider" then ch:Destroy() end
	end

	if not selectedBuilding then
		TweenService:Create(detailStrip, tweenSlide, {Size = UDim2.new(1, -2, 0, 0)}):Play()
		if gridContainer then
			TweenService:Create(gridContainer, tweenSlide, {Size = UDim2.new(1, -(SIDEBAR_W + 16 + 8), 1, -68)}):Play()
		end
		return
	end

	local config = BuildingConfig.GetBuilding(selectedBuilding); if not config then return end
	local cb, lr = canPlayerBuild(selectedBuilding)

	TweenService:Create(detailStrip, tweenSlide, {Size = UDim2.new(1, -2, 0, STRIP_H)}):Play()
	if gridContainer then
		TweenService:Create(gridContainer, tweenSlide, {Size = UDim2.new(1, -(SIDEBAR_W + 16 + 8), 1, -68 - STRIP_H - 4)}):Play()
	end

	-- Solid gold top border (high visibility)
	local div = Instance.new("Frame")
	div.Name = "StripDivider"
	div.Size = UDim2.new(1, 0, 0, 2)
	div.Position = UDim2.new(0, 0, 0, 0)
	div.BackgroundColor3 = C.Gold
	div.BackgroundTransparency = 0
	div.BorderSizePixel = 0
	div.ZIndex = 6
	div.Parent = detailStrip

	-- Strip inner background (brighter than panel for contrast)
	local stripBg = Instance.new("Frame")
	stripBg.Size = UDim2.new(1, 0, 1, -2)
	stripBg.Position = UDim2.new(0, 0, 0, 2)
	stripBg.BackgroundColor3 = Color3.fromRGB(28, 50, 50)
	stripBg.BorderSizePixel = 0
	stripBg.ZIndex = 5
	stripBg.Parent = detailStrip
	Instance.new("UICorner", stripBg).CornerRadius = UDim.new(0, 6)
	-- Subtle gradient for depth
	local stripGrad = Instance.new("UIGradient")
	stripGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 58, 58)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(22, 40, 40)),
	})
	stripGrad.Rotation = 90
	stripGrad.Parent = stripBg

	-- Viewport preview (left)
	local vpWrap = Instance.new("Frame")
	vpWrap.Size = UDim2.new(0, 66, 0, 66)
	vpWrap.Position = UDim2.new(0, 12, 0.5, -31)
	vpWrap.BackgroundColor3 = C.IconBg
	vpWrap.BorderSizePixel = 0
	vpWrap.ZIndex = 6
	vpWrap.Parent = detailStrip
	Instance.new("UICorner", vpWrap).CornerRadius = UDim.new(0, 6)
	local vpStroke = Instance.new("UIStroke"); vpStroke.Color = C.GoldDim; vpStroke.Thickness = 1; vpStroke.Parent = vpWrap
	local vpf = createViewportPreview(vpWrap, selectedBuilding, UDim2.new(1, -4, 1, -4))
	vpf.ZIndex = 7

	-- Info (middle) — larger text, brighter colors
	local infoX = 90
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -(infoX + 140), 0, 22)
	nameLabel.Position = UDim2.new(0, infoX, 0, 8)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = config.DisplayName
	nameLabel.TextColor3 = cb and C.GoldBright or C.Key
	nameLabel.TextSize = 16; nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.ZIndex = 6
	nameLabel.Parent = detailStrip

	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(1, -(infoX + 140), 0, 16)
	descLabel.Position = UDim2.new(0, infoX, 0, 30)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = config.Description or ""
	descLabel.TextColor3 = C.Label
	descLabel.TextSize = 11; descLabel.Font = Enum.Font.Gotham
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextTruncate = Enum.TextTruncate.AtEnd
	descLabel.ZIndex = 6
	descLabel.Parent = detailStrip

	local costLabel = Instance.new("TextLabel")
	costLabel.Size = UDim2.new(1, -(infoX + 140), 0, 16)
	costLabel.Position = UDim2.new(0, infoX, 0, 48)
	costLabel.BackgroundTransparency = 1
	costLabel.Text = "Cost: " .. BuildingConfig.GetCostString(selectedBuilding)
	costLabel.TextColor3 = C.GoldTxt
	costLabel.TextSize = 11; costLabel.Font = Enum.Font.GothamBold
	costLabel.TextXAlignment = Enum.TextXAlignment.Left
	costLabel.ZIndex = 6
	costLabel.Parent = detailStrip

	local reqLabel = Instance.new("TextLabel")
	reqLabel.Size = UDim2.new(1, -(infoX + 140), 0, 16)
	reqLabel.Position = UDim2.new(0, infoX, 0, 64)
	reqLabel.BackgroundTransparency = 1
	reqLabel.Text = "Requires: " .. BuildingConfig.GetRequirementString(selectedBuilding)
	reqLabel.TextColor3 = cb and C.Green or C.Danger
	reqLabel.TextSize = 11; reqLabel.Font = Enum.Font.GothamBold
	reqLabel.TextXAlignment = Enum.TextXAlignment.Left
	reqLabel.ZIndex = 6
	reqLabel.Parent = detailStrip

	-- Place button (right) with gold gradient
	local placeBtn = Instance.new("TextButton")
	placeBtn.Size = UDim2.new(0, 120, 0, 40)
	placeBtn.Position = UDim2.new(1, -130, 0.5, -20)
	placeBtn.BackgroundColor3 = cb and C.Gold or C.Key
	placeBtn.BorderSizePixel = 0
	placeBtn.TextColor3 = cb and C.Panel or C.Label
	placeBtn.TextSize = 14; placeBtn.Font = Enum.Font.GothamBold
	placeBtn.Text = cb and "PLACE" or "LOCKED"
	placeBtn.AutoButtonColor = cb
	placeBtn.ZIndex = 6
	placeBtn.Parent = detailStrip
	Instance.new("UICorner", placeBtn).CornerRadius = UDim.new(0, 6)
	if cb then
		local btnGrad = Instance.new("UIGradient")
		btnGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(212, 170, 74)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(154, 122, 48)),
		})
		btnGrad.Rotation = 90
		btnGrad.Parent = placeBtn
		local btnStroke = Instance.new("UIStroke")
		btnStroke.Color = C.GoldBright; btnStroke.Thickness = 1.5; btnStroke.Parent = placeBtn
	end

	if cb then
		placeBtn.MouseButton1Click:Connect(function()
			playUISound(SOUNDS.PlaceClick, 0.5)
			closeBuildMenu()
			startPlacement(selectedBuilding)
		end)
	else
		placeBtn.MouseButton1Click:Connect(function()
			playUISound(SOUNDS.LockedClick, 0.5)
		end)
	end
end

-- =============================================
-- BUILD MENU — GRID TILES
-- =============================================
local function populateGrid()
	if not gridContainer then return end
	cleanupViewportConnections()

	for _, ch in ipairs(gridContainer:GetChildren()) do
		if not ch:IsA("UIGridLayout") and not ch:IsA("UIPadding") then ch:Destroy() end
	end

	local names = BuildingConfig.GetNamesByCategory(currentCategory)
	if searchText ~= "" then
		local f = {}; local lo = string.lower(searchText)
		for _, n in ipairs(names) do
			local cfg = BuildingConfig.GetBuilding(n)
			if cfg and string.find(string.lower(cfg.DisplayName), lo, 1, true) then table.insert(f, n) end
		end
		names = f
	end

	for i, name in ipairs(names) do
		local config = BuildingConfig.GetBuilding(name); if not config then continue end
		local cb = canPlayerBuild(name)

		local tile = Instance.new("TextButton"); tile.Name = name
		tile.Size = UDim2.new(0, 1, 0, 1)
		tile.BackgroundColor3 = C.SlotTop
		tile.BorderSizePixel = 0
		tile.Text = ""
		tile.AutoButtonColor = false
		tile.LayoutOrder = i; tile.Parent = gridContainer
		Instance.new("UICorner", tile).CornerRadius = UDim.new(0, 7)

		local stroke = Instance.new("UIStroke"); stroke.Parent = tile
		stroke.Color = (name == selectedBuilding) and C.GoldWarm or C.GoldDim
		stroke.Thickness = (name == selectedBuilding) and 2 or 1
		stroke.Transparency = cb and 0 or 0.5

		if not cb then tile.BackgroundTransparency = 0.3 end

		-- Selected inner glow
		if name == selectedBuilding then
			local glow = Instance.new("Frame")
			glow.Size = UDim2.new(1, 0, 1, 0)
			glow.BackgroundColor3 = C.Gold
			glow.BackgroundTransparency = 0.92
			glow.BorderSizePixel = 0
			glow.ZIndex = 1
			glow.Parent = tile
			Instance.new("UICorner", glow).CornerRadius = UDim.new(0, 6)
		end

		-- 3D preview (static angle)
		createViewportPreview(tile, name)

		-- Name label at bottom
		local nl = Instance.new("TextLabel")
		nl.Size = UDim2.new(1, -8, 0, 18)
		nl.Position = UDim2.new(0, 4, 1, -22)
		nl.BackgroundTransparency = 1
		nl.Text = config.DisplayName
		nl.TextColor3 = cb and C.GoldTxt or C.Key
		nl.TextSize = 10; nl.Font = Enum.Font.GothamBold
		nl.TextXAlignment = Enum.TextXAlignment.Center
		nl.TextTruncate = Enum.TextTruncate.AtEnd
		nl.ZIndex = 3; nl.Parent = tile

		if not cb then
			local li = Instance.new("TextLabel")
			li.Size = UDim2.new(0, 18, 0, 18); li.Position = UDim2.new(1, -20, 0, 2)
			li.BackgroundTransparency = 1; li.Text = "🔒"; li.TextSize = 12
			li.ZIndex = 4; li.Parent = tile
		end

		-- Hover animation
		tile.MouseEnter:Connect(function()
			playUISound(SOUNDS.TileHover, 0.2)
			if name ~= selectedBuilding then
				TweenService:Create(tile, tweenHoverIn, {BackgroundColor3 = C.SlotHover}):Play()
				TweenService:Create(stroke, tweenHoverIn, {Color = C.Gold}):Play()
			end
		end)
		tile.MouseLeave:Connect(function()
			if name ~= selectedBuilding then
				TweenService:Create(tile, tweenHoverOut, {BackgroundColor3 = C.SlotTop}):Play()
				TweenService:Create(stroke, tweenHoverOut, {Color = C.GoldDim}):Play()
			end
		end)

		tile.MouseButton1Click:Connect(function()
			playUISound(SOUNDS.TileClick, 0.4)
			selectedBuilding = name
			populateGrid()
			updateDetailStrip()
		end)
	end

	local gl = gridContainer:FindFirstChildOfClass("UIGridLayout")
	if gl then gridContainer.CanvasSize = UDim2.new(0, 0, 0, gl.AbsoluteContentSize.Y + 16) end
end

local function updateCategoryHighlights()
	for key, btn in pairs(categoryButtons) do
		local ind = catIndicators[key]
		if key == currentCategory then
			TweenService:Create(btn, tweenFade, {BackgroundColor3 = C.SlotHover, BackgroundTransparency = 0}):Play()
			btn.TextColor3 = C.GoldTxt
			if ind then TweenService:Create(ind, tweenFade, {BackgroundTransparency = 0}):Play() end
		else
			TweenService:Create(btn, tweenFade, {BackgroundColor3 = C.SlotTop, BackgroundTransparency = 0.3}):Play()
			btn.TextColor3 = C.Label
			if ind then TweenService:Create(ind, tweenFade, {BackgroundTransparency = 1}):Play() end
		end
	end
end

-- =============================================
-- BUILD MENU — OPEN / CLOSE
-- =============================================
local function openBuildMenu()
	if menuOpen then closeBuildMenu(); return end
	if isPlacing then return end
	menuOpen = true; selectedBuilding = nil

	playUISound(SOUNDS.MenuOpen, 0.5)

	menuGui = Instance.new("ScreenGui"); menuGui.Name = "BuildMenu"; menuGui.ResetOnSpawn = false; menuGui.Parent = playerGui

	-- Main container (CanvasGroup for group fade)
	local main = Instance.new("CanvasGroup"); main.Name = "Main"
	main.Size = UDim2.new(0.5, 0, 0.6, 0)
	main.Position = UDim2.new(0.25, 0, 0.15, 0)
	main.BackgroundColor3 = C.Panel
	main.BorderSizePixel = 0
	main.Parent = menuGui
	Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

	local sizeC = Instance.new("UISizeConstraint"); sizeC.MinSize = Vector2.new(500, 340); sizeC.MaxSize = Vector2.new(780, 520); sizeC.Parent = main

	local outerStroke = Instance.new("UIStroke"); outerStroke.Color = C.GoldDim; outerStroke.Thickness = 2; outerStroke.Parent = main

	-- Gold highlight at top edge
	local topHL = Instance.new("Frame")
	topHL.Size = UDim2.new(1, -20, 0, 2); topHL.Position = UDim2.new(0, 10, 0, 0)
	topHL.BackgroundColor3 = C.Gold; topHL.BackgroundTransparency = 0.4; topHL.BorderSizePixel = 0; topHL.Parent = main

	-- === TOP BAR ===
	local topBar = Instance.new("TextButton"); topBar.Name = "TopBar"
	topBar.Size = UDim2.new(1, -16, 0, 36); topBar.Position = UDim2.new(0, 8, 0, 6)
	topBar.BackgroundColor3 = C.PanelTop; topBar.BackgroundTransparency = 0.5
	topBar.BorderSizePixel = 0; topBar.Text = ""; topBar.AutoButtonColor = false
	topBar.Parent = main
	Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 8)

	-- Drag
	local dragging = false; local dragStart, startPos

	topBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true; dragStart = input.Position; startPos = main.Position
		end
	end)
	topBar.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - dragStart
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)

	-- Title
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.new(0, 80, 1, 0); tl.Position = UDim2.new(0, 10, 0, 0)
	tl.BackgroundTransparency = 1; tl.Text = "BUILD"
	tl.TextColor3 = C.GoldTxt; tl.TextSize = 16; tl.Font = Enum.Font.GothamBold
	tl.TextXAlignment = Enum.TextXAlignment.Left; tl.Parent = topBar

	local dragHint = Instance.new("TextLabel")
	dragHint.Size = UDim2.new(0, 80, 0, 10); dragHint.Position = UDim2.new(0, 10, 1, -12)
	dragHint.BackgroundTransparency = 1; dragHint.Text = "drag to move"
	dragHint.TextColor3 = C.Key; dragHint.TextSize = 8; dragHint.Font = Enum.Font.Gotham
	dragHint.TextXAlignment = Enum.TextXAlignment.Left; dragHint.Parent = topBar

	-- Search box
	local sf = Instance.new("Frame")
	sf.Size = UDim2.new(0, 180, 0, 24); sf.Position = UDim2.new(0.5, -90, 0.5, -12)
	sf.BackgroundColor3 = C.IconBg; sf.BackgroundTransparency = 0.3; sf.BorderSizePixel = 0; sf.Parent = topBar
	Instance.new("UICorner", sf).CornerRadius = UDim.new(0, 6)
	local sfStroke = Instance.new("UIStroke"); sfStroke.Color = C.GoldDim; sfStroke.Thickness = 1; sfStroke.Parent = sf

	local sb = Instance.new("TextBox")
	sb.Size = UDim2.new(1, -8, 1, 0); sb.Position = UDim2.new(0, 4, 0, 0)
	sb.BackgroundTransparency = 1; sb.Text = ""
	sb.PlaceholderText = "Search..."; sb.PlaceholderColor3 = C.Key
	sb.TextColor3 = C.GoldTxt; sb.TextSize = 11; sb.Font = Enum.Font.Gotham
	sb.ClearTextOnFocus = false; sb.Parent = sf
	sb:GetPropertyChangedSignal("Text"):Connect(function() searchText = sb.Text; populateGrid() end)

	-- Close button
	local xBtn = Instance.new("TextButton")
	xBtn.Size = UDim2.new(0, 28, 0, 28); xBtn.Position = UDim2.new(1, -32, 0.5, -14)
	xBtn.BackgroundColor3 = C.Danger; xBtn.BorderSizePixel = 0
	xBtn.TextColor3 = Color3.new(1, 1, 1); xBtn.TextSize = 14; xBtn.Font = Enum.Font.GothamBold; xBtn.Text = "X"
	xBtn.Parent = topBar
	Instance.new("UICorner", xBtn).CornerRadius = UDim.new(0, 6)
	xBtn.MouseButton1Click:Connect(function() closeBuildMenu() end)

	-- === MEANDER DIVIDER (Greek key pattern) ===
	local meanderBar = Instance.new("Frame")
	meanderBar.Size = UDim2.new(1, -24, 0, 2)
	meanderBar.Position = UDim2.new(0, 12, 0, 43)
	meanderBar.BackgroundColor3 = C.Gold
	meanderBar.BackgroundTransparency = 0.7
	meanderBar.BorderSizePixel = 0
	meanderBar.Parent = main
	-- Dashed effect via UIGradient
	local meanderGrad = Instance.new("UIGradient")
	meanderGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1,1,1)),
		ColorSequenceKeypoint.new(1, Color3.new(1,1,1)),
	})
	meanderGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.46, 0),
		NumberSequenceKeypoint.new(0.47, 0.8),
		NumberSequenceKeypoint.new(0.53, 0.8),
		NumberSequenceKeypoint.new(0.54, 0),
		NumberSequenceKeypoint.new(1, 0),
	})
	meanderGrad.Parent = meanderBar

	-- === SIDEBAR ===
	local sidebar = Instance.new("ScrollingFrame")
	sidebar.Size = UDim2.new(0, SIDEBAR_W, 1, -68); sidebar.Position = UDim2.new(0, 8, 0, 46)
	sidebar.BackgroundColor3 = C.PanelTop; sidebar.BackgroundTransparency = 0.5
	sidebar.BorderSizePixel = 0; sidebar.ScrollBarThickness = 0
	sidebar.CanvasSize = UDim2.new(0, 0, 0, 0); sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sidebar.Parent = main
	Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 6)

	local sLayout = Instance.new("UIListLayout", sidebar); sLayout.SortOrder = Enum.SortOrder.LayoutOrder; sLayout.Padding = UDim.new(0, 2)
	local sPad = Instance.new("UIPadding", sidebar)
	sPad.PaddingTop = UDim.new(0, 4); sPad.PaddingBottom = UDim.new(0, 4)
	sPad.PaddingLeft = UDim.new(0, 4); sPad.PaddingRight = UDim.new(0, 4)

	categoryButtons = {}
	catIndicators = {}
	for i, cat in ipairs(BuildingConfig.Categories) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, 0, 0, 28)
		btn.BackgroundColor3 = C.SlotTop; btn.BackgroundTransparency = 0.3; btn.BorderSizePixel = 0
		btn.TextColor3 = C.Label; btn.TextSize = 11; btn.Font = Enum.Font.GothamBold
		btn.Text = cat.DisplayName; btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.AutoButtonColor = false; btn.LayoutOrder = i; btn.Parent = sidebar
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
		Instance.new("UIPadding", btn).PaddingLeft = UDim.new(0, 10)
		-- Gold left indicator bar
		local indicator = Instance.new("Frame")
		indicator.Size = UDim2.new(0, 3, 0.6, 0)
		indicator.Position = UDim2.new(0, 0, 0.2, 0)
		indicator.BackgroundColor3 = C.Gold
		indicator.BackgroundTransparency = 1
		indicator.BorderSizePixel = 0
		indicator.Parent = btn
		Instance.new("UICorner", indicator).CornerRadius = UDim.new(0, 2)
		catIndicators[cat.Key] = indicator
		categoryButtons[cat.Key] = btn
		btn.MouseButton1Click:Connect(function()
			playUISound(SOUNDS.CategoryClick, 0.35)
			currentCategory = cat.Key
			updateCategoryHighlights()
			populateGrid()
		end)
	end
	updateCategoryHighlights()

	-- === VERTICAL DIVIDER ===
	local vDiv = Instance.new("Frame")
	vDiv.Size = UDim2.new(0, 1, 1, -60)
	vDiv.Position = UDim2.new(0, SIDEBAR_W + 10, 0, 48)
	vDiv.BackgroundColor3 = C.GoldDim
	vDiv.BackgroundTransparency = 0.5
	vDiv.BorderSizePixel = 0
	vDiv.Parent = main
	local vDivGrad = Instance.new("UIGradient")
	vDivGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0),
		NumberSequenceKeypoint.new(0.85, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	vDivGrad.Rotation = 90
	vDivGrad.Parent = vDiv

	-- === CENTER GRID ===
	local GRID_X = SIDEBAR_W + 16
	gridContainer = Instance.new("ScrollingFrame")
	gridContainer.Size = UDim2.new(1, -(GRID_X + 8), 1, -68)
	gridContainer.Position = UDim2.new(0, GRID_X, 0, 46)
	gridContainer.BackgroundTransparency = 1; gridContainer.BorderSizePixel = 0
	gridContainer.ScrollBarThickness = 4; gridContainer.ScrollBarImageColor3 = C.GoldDim
	gridContainer.Parent = main

	local gLayout = Instance.new("UIGridLayout", gridContainer)
	gLayout.CellSize = UDim2.new(0, 100, 0, 100); gLayout.CellPadding = UDim2.new(0, 6, 0, 6)
	gLayout.SortOrder = Enum.SortOrder.LayoutOrder
	local gPad = Instance.new("UIPadding", gridContainer)
	gPad.PaddingTop = UDim.new(0, 4); gPad.PaddingLeft = UDim.new(0, 4); gPad.PaddingRight = UDim.new(0, 4)
	populateGrid()

	-- === HOTKEY HINTS BAR ===
	local hotkeyBar = Instance.new("Frame")
	hotkeyBar.Size = UDim2.new(1, 0, 0, 18)
	hotkeyBar.Position = UDim2.new(0, 0, 1, -18)
	hotkeyBar.BackgroundTransparency = 1
	hotkeyBar.BorderSizePixel = 0
	hotkeyBar.Parent = main

	local hotkeyLabel = Instance.new("TextLabel")
	hotkeyLabel.Size = UDim2.new(1, 0, 1, 0)
	hotkeyLabel.BackgroundTransparency = 1
	hotkeyLabel.Text = "[B] Menu    [R] Rotate    [T] Snap Mode    [G] Grid    [V] Reset"
	hotkeyLabel.TextColor3 = C.Key
	hotkeyLabel.TextSize = 9; hotkeyLabel.Font = Enum.Font.Gotham
	hotkeyLabel.Parent = hotkeyBar

	-- === DETAIL STRIP (bottom, starts collapsed) ===
	detailStrip = Instance.new("Frame"); detailStrip.Name = "DetailStrip"
	detailStrip.Size = UDim2.new(1, -2, 0, 0)
	detailStrip.Position = UDim2.new(0, 1, 1, -20)
	detailStrip.AnchorPoint = Vector2.new(0, 1)
	detailStrip.BackgroundColor3 = C.SlotTop; detailStrip.BorderSizePixel = 0
	detailStrip.ClipsDescendants = true; detailStrip.ZIndex = 5
	detailStrip.Parent = main
	Instance.new("UICorner", detailStrip).CornerRadius = UDim.new(0, 8)

	-- Open animation (fade in)
	main.GroupTransparency = 1
	TweenService:Create(main, tweenOpen, {GroupTransparency = 0}):Play()
end

function closeBuildMenu()
	playUISound(SOUNDS.MenuClose, 0.5)
	cleanupViewportConnections()

	if menuGui then
		local main = menuGui:FindFirstChild("Main")
		if main and main:IsA("CanvasGroup") then
			local t = TweenService:Create(main, tweenClose, {GroupTransparency = 1})
			t:Play()
			t.Completed:Connect(function()
				if menuGui then menuGui:Destroy(); menuGui = nil end
			end)
		else
			menuGui:Destroy(); menuGui = nil
		end
	end

	menuOpen = false; gridContainer = nil; detailStrip = nil; categoryButtons = {}; catIndicators = {}; searchText = ""
end

-- =============================================
-- TOOLBAR (dark teal, placement controls)
-- =============================================
local toolbarGui, rotationBtn, gridBtn, gridSizeLabel = nil, nil, nil, nil

local function updateToolbarUI()
	if rotationBtn then
		if freeformMode then
			rotationBtn.Text = "[T] Free"; rotationBtn.BackgroundColor3 = C.Green; rotationBtn.TextColor3 = Color3.new(1,1,1)
		else
			rotationBtn.Text = "[T] 15° Snap"; rotationBtn.BackgroundColor3 = C.SlotTop; rotationBtn.TextColor3 = C.GoldTxt
		end
	end
	if gridBtn then
		if gridEnabled then
			gridBtn.Text = "[G] Grid ON"; gridBtn.BackgroundColor3 = C.Green; gridBtn.TextColor3 = Color3.new(1,1,1)
		else
			gridBtn.Text = "[G] Grid OFF"; gridBtn.BackgroundColor3 = C.SlotTop; gridBtn.TextColor3 = C.GoldTxt
		end
	end
	if gridSizeLabel then gridSizeLabel.Text = GRID_SIZE .. " st" end
end

local function showToolbar()
	if toolbarGui then return end
	toolbarGui = Instance.new("ScreenGui"); toolbarGui.Name = "BuildToolbar"; toolbarGui.ResetOnSpawn = false; toolbarGui.Parent = playerGui

	local panel = Instance.new("CanvasGroup")
	panel.Size = UDim2.new(0, 150, 0, 210); panel.Position = UDim2.new(1, -160, 0.5, -105)
	panel.BackgroundColor3 = C.Panel; panel.BorderSizePixel = 0; panel.Parent = toolbarGui
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
	local tbStroke = Instance.new("UIStroke"); tbStroke.Color = C.GoldDim; tbStroke.Thickness = 1; tbStroke.Parent = panel

	local pad = Instance.new("UIPadding", panel)
	pad.PaddingTop = UDim.new(0, 10); pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 10); pad.PaddingRight = UDim.new(0, 10)
	local lay = Instance.new("UIListLayout", panel); lay.SortOrder = Enum.SortOrder.LayoutOrder; lay.Padding = UDim.new(0, 5)

	local ti = Instance.new("TextLabel"); ti.Size = UDim2.new(1, 0, 0, 16); ti.BackgroundTransparency = 1
	ti.Text = "TOOLS"; ti.TextColor3 = C.GoldTxt; ti.TextSize = 12; ti.Font = Enum.Font.GothamBold
	ti.LayoutOrder = 0; ti.Parent = panel

	rotationBtn = Instance.new("TextButton"); rotationBtn.Size = UDim2.new(1, 0, 0, 26); rotationBtn.BorderSizePixel = 0
	rotationBtn.TextSize = 10; rotationBtn.Font = Enum.Font.GothamBold; rotationBtn.LayoutOrder = 1; rotationBtn.Parent = panel
	Instance.new("UICorner", rotationBtn).CornerRadius = UDim.new(0, 4)
	rotationBtn.MouseButton1Click:Connect(function() freeformMode = not freeformMode; updateToolbarUI() end)

	local rb = Instance.new("TextButton"); rb.Size = UDim2.new(1, 0, 0, 20)
	rb.BackgroundColor3 = C.Danger; rb.BorderSizePixel = 0
	rb.TextColor3 = Color3.new(1, 1, 1); rb.TextSize = 9; rb.Font = Enum.Font.GothamBold; rb.Text = "[V] Reset"
	rb.LayoutOrder = 2; rb.Parent = panel
	Instance.new("UICorner", rb).CornerRadius = UDim.new(0, 4)
	rb.MouseButton1Click:Connect(function() currentRotation = 0 end)

	local s1 = Instance.new("Frame"); s1.Size = UDim2.new(1, 0, 0, 1); s1.BackgroundColor3 = C.GoldDim
	s1.BackgroundTransparency = 0.5; s1.BorderSizePixel = 0; s1.LayoutOrder = 3; s1.Parent = panel

	gridBtn = Instance.new("TextButton"); gridBtn.Size = UDim2.new(1, 0, 0, 26); gridBtn.BorderSizePixel = 0
	gridBtn.TextSize = 10; gridBtn.Font = Enum.Font.GothamBold; gridBtn.LayoutOrder = 4; gridBtn.Parent = panel
	Instance.new("UICorner", gridBtn).CornerRadius = UDim.new(0, 4)
	gridBtn.MouseButton1Click:Connect(function()
		gridEnabled = not gridEnabled; if gridEnabled then showGrid() else hideGrid() end; updateToolbarUI()
	end)

	local sr = Instance.new("Frame"); sr.Size = UDim2.new(1, 0, 0, 26); sr.BackgroundTransparency = 1; sr.LayoutOrder = 5; sr.Parent = panel

	local mb = Instance.new("TextButton"); mb.Size = UDim2.new(0, 26, 1, 0)
	mb.BackgroundColor3 = C.SlotTop; mb.BorderSizePixel = 0; mb.TextColor3 = C.GoldTxt
	mb.TextSize = 14; mb.Font = Enum.Font.GothamBold; mb.Text = "-"; mb.Parent = sr
	Instance.new("UICorner", mb).CornerRadius = UDim.new(0, 4)

	gridSizeLabel = Instance.new("TextLabel")
	gridSizeLabel.Size = UDim2.new(1, -60, 1, 0); gridSizeLabel.Position = UDim2.new(0, 30, 0, 0)
	gridSizeLabel.BackgroundTransparency = 1; gridSizeLabel.TextColor3 = C.GoldTxt
	gridSizeLabel.TextSize = 10; gridSizeLabel.Font = Enum.Font.GothamBold; gridSizeLabel.Parent = sr

	local pBtn = Instance.new("TextButton"); pBtn.Size = UDim2.new(0, 26, 1, 0); pBtn.Position = UDim2.new(1, -26, 0, 0)
	pBtn.BackgroundColor3 = C.SlotTop; pBtn.BorderSizePixel = 0; pBtn.TextColor3 = C.GoldTxt
	pBtn.TextSize = 14; pBtn.Font = Enum.Font.GothamBold; pBtn.Text = "+"; pBtn.Parent = sr
	Instance.new("UICorner", pBtn).CornerRadius = UDim.new(0, 4)

	mb.MouseButton1Click:Connect(function() if gridSizeIndex > 1 then gridSizeIndex -= 1; GRID_SIZE = GRID_SIZES[gridSizeIndex]; refreshGrid(); updateToolbarUI() end end)
	pBtn.MouseButton1Click:Connect(function() if gridSizeIndex < #GRID_SIZES then gridSizeIndex += 1; GRID_SIZE = GRID_SIZES[gridSizeIndex]; refreshGrid(); updateToolbarUI() end end)

	local ht = Instance.new("TextLabel"); ht.Size = UDim2.new(1, 0, 0, 36); ht.BackgroundTransparency = 1
	ht.Text = "R = Rotate | V = Reset\nT = Mode | G = Grid"; ht.TextColor3 = C.Key
	ht.TextSize = 9; ht.Font = Enum.Font.Gotham; ht.TextYAlignment = Enum.TextYAlignment.Top
	ht.LayoutOrder = 7; ht.Parent = panel
	updateToolbarUI()

	-- Fade in
	panel.GroupTransparency = 1
	TweenService:Create(panel, tweenOpen, {GroupTransparency = 0}):Play()
end

local function hideToolbar()
	if toolbarGui then toolbarGui:Destroy(); toolbarGui = nil; rotationBtn = nil; gridBtn = nil; gridSizeLabel = nil end
end

-- =============================================
-- PLACEMENT HUD (bottom bar)
-- =============================================
local placementGui = nil

function showPlacementHUD()
	if placementGui then placementGui:Destroy() end
	placementGui = Instance.new("ScreenGui"); placementGui.Name = "PlacementHUD"; placementGui.ResetOnSpawn = false; placementGui.Parent = playerGui

	local f = Instance.new("CanvasGroup")
	f.Size = UDim2.new(0, 380, 0, 48); f.Position = UDim2.new(0.5, -190, 1, -75)
	f.BackgroundColor3 = C.Panel; f.BorderSizePixel = 0; f.Parent = placementGui
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
	local hudStroke = Instance.new("UIStroke"); hudStroke.Color = C.GoldDim; hudStroke.Thickness = 1; hudStroke.Parent = f

	local config = BuildingConfig.GetBuilding(currentBuildingName)
	local dn = config and config.DisplayName or currentBuildingName

	local nl = Instance.new("TextLabel")
	nl.Size = UDim2.new(1, 0, 0, 18); nl.Position = UDim2.new(0, 0, 0, 5)
	nl.BackgroundTransparency = 1
	nl.Text = dn .. "  (" .. BuildingConfig.GetCostString(currentBuildingName) .. ")"
	nl.TextColor3 = C.GoldTxt; nl.TextSize = 12; nl.Font = Enum.Font.GothamBold; nl.Parent = f

	local cl = Instance.new("TextLabel")
	cl.Size = UDim2.new(1, 0, 0, 14); cl.Position = UDim2.new(0, 0, 0, 24)
	cl.BackgroundTransparency = 1; cl.Text = "[Click] Place  [R] Rotate  [V] Reset  [X] Cancel"
	cl.TextColor3 = C.Label; cl.TextSize = 10; cl.Font = Enum.Font.Gotham; cl.Parent = f

	-- Fade in
	f.GroupTransparency = 1
	TweenService:Create(f, tweenOpen, {GroupTransparency = 0}):Play()
end

function hidePlacementHUD() if placementGui then placementGui:Destroy(); placementGui = nil end end

-- =============================================
-- PLACEMENT FLOW
-- =============================================
function startPlacement(bn)
	if isPlacing then cancelPlacement() end
	local config = BuildingConfig.GetBuilding(bn); if not config then return end
	if not canPlayerBuild(bn) then return end
	currentBuildingName = bn; currentRotation = 0; isPlacing = true; canPlace = false; holdingR = false
	createGhost(bn); showPlacementHUD(); showToolbar(); if gridEnabled then showGrid() end
end

local function confirmPlacement()
	if not isPlacing or not canPlace then return end
	local hp = getMouseTerrainPosition(); if not hp then return end; hp = snapToGrid(hp)
	PlaceBuildingEvent:FireServer(currentBuildingName, hp, currentRotation)
	destroyGhost(); hideGrid(); hideToolbar(); hidePlacementHUD()
	isPlacing = false; canPlace = false; currentBuildingName = nil
end

function cancelPlacement()
	destroyGhost(); hideGrid(); hideToolbar(); hidePlacementHUD()
	isPlacing = false; canPlace = false; currentBuildingName = nil
end

-- =============================================
-- INPUT
-- =============================================
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if isPlacing then
		if input.KeyCode == Enum.KeyCode.R then
			if freeformMode then holdingR = true
			else currentRotation += SNAP_STEP; if currentRotation >= math.pi*2 then currentRotation = 0 end end
		end
		if input.KeyCode == Enum.KeyCode.V then currentRotation = 0 end
		if input.KeyCode == Enum.KeyCode.T then freeformMode = not freeformMode; updateToolbarUI() end
		if input.KeyCode == Enum.KeyCode.G then gridEnabled = not gridEnabled; if gridEnabled then showGrid() else hideGrid() end; updateToolbarUI() end
		if input.KeyCode == Enum.KeyCode.X or input.KeyCode == Enum.KeyCode.Escape then cancelPlacement() end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then confirmPlacement() end
	else
		if input.KeyCode == Enum.KeyCode.B then if menuOpen then closeBuildMenu() else openBuildMenu() end end
	end
end)
UserInputService.InputEnded:Connect(function(input) if input.KeyCode == Enum.KeyCode.R then holdingR = false end end)

-- =============================================
-- RENDER
-- =============================================
local gridUpdateTimer = 0
RunService.RenderStepped:Connect(function(dt)
	if isPlacing then
		if freeformMode and holdingR then currentRotation += FREEFORM_SPEED*dt; if currentRotation >= math.pi*2 then currentRotation -= math.pi*2 end end
		updateGhost()
		if gridEnabled then gridUpdateTimer += dt; if gridUpdateTimer >= 0.5 then gridUpdateTimer = 0; hideGrid(); showGrid() end end
	end
end)

-- =============================================
-- API
-- =============================================
local api = Instance.new("BindableEvent"); api.Name = "BuildingPlacementAPI"; api.Parent = player
api.Event:Connect(function(a,...) if a == "StartPlacement" then startPlacement(...) elseif a == "CancelPlacement" then cancelPlacement() end end)

print("Building placement loaded — press B to open build menu")
