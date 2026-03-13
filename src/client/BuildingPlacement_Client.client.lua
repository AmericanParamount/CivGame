-- BuildingPlacement LocalScript
-- Location: StarterPlayerScripts > BuildingPlacement
-- Parchment-themed build menu. Semi-transparent, draggable. 3D previews. Sound effects.
-- B = toggle. R/T/G/V placement controls.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

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

local UI = {
	BuildMenuPanel = "rbxassetid://112244832004411",
	SlotTile       = "rbxassetid://94301633349386",
	ToolbarPanel   = "rbxassetid://84324990884668",
	Button         = "rbxassetid://102593938595317",
	Tooltip        = "rbxassetid://106526935100610",
}

local SOUNDS = {
	MenuOpen      = "rbxassetid://97861038165143",
	MenuClose     = "rbxassetid://110059957735733",
	CategoryClick = "rbxassetid://76353543802706",
	TileClick     = "rbxassetid://88442833509532",
	TileHover     = "rbxassetid://139800881181209",
	PlaceClick    = "rbxassetid://77117485112690",
	LockedClick   = "rbxassetid://87519554692663",
}

local THEME = {
	TextDark     = Color3.fromRGB(62, 48, 32),
	TextMedium   = Color3.fromRGB(100, 80, 55),
	TextLight    = Color3.fromRGB(140, 120, 85),
	Gold         = Color3.fromRGB(180, 145, 55),
	GoldDim      = Color3.fromRGB(140, 112, 50),
	Green        = Color3.fromRGB(70, 150, 65),
	Red          = Color3.fromRGB(175, 55, 45),
	CatActive    = Color3.fromRGB(200, 180, 145),
	CatInactive  = Color3.fromRGB(220, 210, 185),
	PanelDarker  = Color3.fromRGB(215, 205, 180),
}

local MENU_TRANSPARENCY = 0.25

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
local detailPanel = nil
local categoryButtons = {}

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

-- Grid
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

-- Ghost
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
-- BUILD MENU
-- =============================================
local function updateDetailPanel()
	if not detailPanel then return end
	for _, ch in ipairs(detailPanel:GetChildren()) do
		if not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") then ch:Destroy() end
	end
	if not selectedBuilding then
		local h = Instance.new("TextLabel"); h.Size = UDim2.new(1,0,0,60); h.BackgroundTransparency = 1
		h.Text = "Select a building\nfrom the list"; h.TextColor3 = THEME.TextLight
		h.TextSize = 13; h.Font = Enum.Font.Gotham; h.TextWrapped = true
		h.LayoutOrder = 1; h.Parent = detailPanel; return
	end
	local config = BuildingConfig.GetBuilding(selectedBuilding); if not config then return end
	local cb, lr = canPlayerBuild(selectedBuilding)

	local nl = Instance.new("TextLabel"); nl.Size = UDim2.new(1,0,0,22); nl.BackgroundTransparency = 1
	nl.Text = config.DisplayName; nl.TextColor3 = cb and THEME.TextDark or THEME.TextLight
	nl.TextSize = 15; nl.Font = Enum.Font.GothamBold; nl.TextXAlignment = Enum.TextXAlignment.Left
	nl.LayoutOrder = 1; nl.Parent = detailPanel

	local cl = Instance.new("TextLabel"); cl.Size = UDim2.new(1,0,0,14); cl.BackgroundTransparency = 1
	cl.Text = config.Category; cl.TextColor3 = THEME.GoldDim; cl.TextSize = 10; cl.Font = Enum.Font.Gotham
	cl.TextXAlignment = Enum.TextXAlignment.Left; cl.LayoutOrder = 2; cl.Parent = detailPanel

	local s1 = Instance.new("Frame"); s1.Size = UDim2.new(1,0,0,1); s1.BackgroundColor3 = THEME.GoldDim
	s1.BackgroundTransparency = 0.5; s1.BorderSizePixel = 0; s1.LayoutOrder = 3; s1.Parent = detailPanel

	local dl = Instance.new("TextLabel"); dl.Size = UDim2.new(1,0,0,40); dl.BackgroundTransparency = 1
	dl.Text = config.Description or ""; dl.TextColor3 = THEME.TextMedium; dl.TextSize = 10
	dl.Font = Enum.Font.Gotham; dl.TextWrapped = true; dl.TextYAlignment = Enum.TextYAlignment.Top
	dl.TextXAlignment = Enum.TextXAlignment.Left; dl.LayoutOrder = 4; dl.Parent = detailPanel

	local chdr = Instance.new("TextLabel"); chdr.Size = UDim2.new(1,0,0,14); chdr.BackgroundTransparency = 1
	chdr.Text = "COST"; chdr.TextColor3 = THEME.Gold; chdr.TextSize = 10; chdr.Font = Enum.Font.GothamBold
	chdr.TextXAlignment = Enum.TextXAlignment.Left; chdr.LayoutOrder = 5; chdr.Parent = detailPanel

	if config.Cost and next(config.Cost) then
		local co = 6; local sorted = {}
		for item, count in pairs(config.Cost) do table.insert(sorted, {I=item,C=count}) end
		table.sort(sorted, function(a,b) return a.I < b.I end)
		for _, e in ipairs(sorted) do
			local r = Instance.new("TextLabel"); r.Size = UDim2.new(1,0,0,13); r.BackgroundTransparency = 1
			r.Text = "  "..e.C.."x "..e.I; r.TextColor3 = THEME.TextMedium; r.TextSize = 10; r.Font = Enum.Font.Gotham
			r.TextXAlignment = Enum.TextXAlignment.Left; r.LayoutOrder = co; r.Parent = detailPanel; co += 1
		end
	end

	local rh = Instance.new("TextLabel"); rh.Size = UDim2.new(1,0,0,14); rh.BackgroundTransparency = 1
	rh.Text = "REQUIRES"; rh.TextColor3 = THEME.Gold; rh.TextSize = 10; rh.Font = Enum.Font.GothamBold
	rh.TextXAlignment = Enum.TextXAlignment.Left; rh.LayoutOrder = 20; rh.Parent = detailPanel

	local rt = BuildingConfig.GetRequirementString(selectedBuilding)
	local rl = Instance.new("TextLabel"); rl.Size = UDim2.new(1,0,0,13); rl.BackgroundTransparency = 1
	rl.Text = "  "..rt; rl.TextColor3 = cb and THEME.Green or THEME.Red; rl.TextSize = 10; rl.Font = Enum.Font.Gotham
	rl.TextXAlignment = Enum.TextXAlignment.Left; rl.LayoutOrder = 21; rl.Parent = detailPanel

	if not cb and lr then
		local ll = Instance.new("TextLabel"); ll.Size = UDim2.new(1,0,0,13); ll.BackgroundTransparency = 1
		ll.Text = "  "..lr; ll.TextColor3 = THEME.Red; ll.TextSize = 9; ll.Font = Enum.Font.GothamBold
		ll.TextXAlignment = Enum.TextXAlignment.Left; ll.LayoutOrder = 22; ll.Parent = detailPanel
	end

	local s2 = Instance.new("Frame"); s2.Size = UDim2.new(1,0,0,1); s2.BackgroundColor3 = THEME.GoldDim
	s2.BackgroundTransparency = 0.5; s2.BorderSizePixel = 0; s2.LayoutOrder = 30; s2.Parent = detailPanel

	local pb = Instance.new("ImageButton"); pb.Size = UDim2.new(1,0,0,32)
	pb.BackgroundTransparency = 1; pb.Image = UI.Button; pb.ScaleType = Enum.ScaleType.Stretch
	pb.LayoutOrder = 31; pb.Parent = detailPanel
	local bt = Instance.new("TextLabel"); bt.Size = UDim2.new(1,0,1,0); bt.BackgroundTransparency = 1
	bt.Font = Enum.Font.GothamBold; bt.TextSize = 13; bt.Parent = pb
	if cb then
		bt.Text = "Place Blueprint"; bt.TextColor3 = Color3.new(1,1,1)
		pb.MouseButton1Click:Connect(function()
			playUISound(SOUNDS.PlaceClick, 0.5)
			closeBuildMenu()
			startPlacement(selectedBuilding)
		end)
	else
		bt.Text = "Locked"; bt.TextColor3 = THEME.TextLight; pb.ImageTransparency = 0.4
		pb.MouseButton1Click:Connect(function()
			playUISound(SOUNDS.LockedClick, 0.5)
		end)
	end
end

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
			local c = BuildingConfig.GetBuilding(n)
			if c and string.find(string.lower(c.DisplayName), lo, 1, true) then table.insert(f, n) end
		end
		names = f
	end

	for i, name in ipairs(names) do
		local config = BuildingConfig.GetBuilding(name); if not config then continue end
		local cb = canPlayerBuild(name)

		local tile = Instance.new("ImageButton"); tile.Name = name
		tile.Size = UDim2.new(0,1,0,1); tile.BackgroundTransparency = 1
		tile.Image = UI.SlotTile; tile.ScaleType = Enum.ScaleType.Stretch
		tile.ImageTransparency = cb and 0 or 0.3
		tile.LayoutOrder = i; tile.Parent = gridContainer

		local nl = Instance.new("TextLabel")
		nl.Size = UDim2.new(1, -8, 0, 16); nl.Position = UDim2.new(0, 4, 0, 4)
		nl.BackgroundTransparency = 1; nl.Text = config.DisplayName
		nl.TextColor3 = cb and THEME.TextDark or THEME.TextLight
		nl.TextSize = 10; nl.Font = Enum.Font.GothamBold
		nl.TextXAlignment = Enum.TextXAlignment.Left
		nl.TextTruncate = Enum.TextTruncate.AtEnd
		nl.ZIndex = 3; nl.Parent = tile

		local cl = Instance.new("TextLabel")
		cl.Size = UDim2.new(1, -8, 0, 12); cl.Position = UDim2.new(0, 4, 1, -16)
		cl.BackgroundTransparency = 1; cl.Text = BuildingConfig.GetCostString(name)
		cl.TextColor3 = cb and THEME.TextMedium or THEME.TextLight
		cl.TextSize = 9; cl.Font = Enum.Font.Gotham
		cl.TextXAlignment = Enum.TextXAlignment.Left
		cl.TextTruncate = Enum.TextTruncate.AtEnd
		cl.ZIndex = 3; cl.Parent = tile

		if not cb then
			local li = Instance.new("TextLabel")
			li.Size = UDim2.new(0, 18, 0, 18); li.Position = UDim2.new(1, -20, 0, 2)
			li.BackgroundTransparency = 1; li.Text = "🔒"; li.TextSize = 12
			li.ZIndex = 4; li.Parent = tile
		end

		if name == selectedBuilding then
			local sel = Instance.new("UIStroke"); sel.Color = THEME.Gold; sel.Thickness = 2; sel.Parent = tile
		end

		-- 3D Viewport preview
		local vpf = Instance.new("ViewportFrame")
		vpf.Size = UDim2.new(0, 75, 0, 75)
		vpf.Position = UDim2.new(0.5, -37, 0.5, -30)
		vpf.BackgroundTransparency = 1
		vpf.Ambient = Color3.fromRGB(180, 170, 150)
		vpf.LightColor = Color3.fromRGB(255, 250, 240)
		vpf.LightDirection = Vector3.new(-1, -1, -1)
		vpf.ZIndex = 2; vpf.Parent = tile

		local previewModel = nil
		local repModels = ReplicatedStorage:FindFirstChild("Models")
		if repModels then
			local bf = repModels:FindFirstChild("Buildings")
			if bf then
				local src = bf:FindFirstChild(name)
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
		local camDist = maxDim * 1.5
		local center = modelCF.Position
		local angle = math.rad(i * 45)

		vpCam.CFrame = CFrame.new(
			center + Vector3.new(math.cos(angle) * camDist * 0.8, camDist * 0.5, math.sin(angle) * camDist * 0.8),
			center
		)

		local rotConn = RunService.Heartbeat:Connect(function(dt)
			if not vpf.Parent then return end
			angle = angle + dt * 0.5
			vpCam.CFrame = CFrame.new(
				center + Vector3.new(math.cos(angle) * camDist * 0.8, camDist * 0.5, math.sin(angle) * camDist * 0.8),
				center
			)
		end)
		table.insert(viewportConnections, rotConn)

		-- SOUND: hover
		tile.MouseEnter:Connect(function()
			playUISound(SOUNDS.TileHover, 0.2)
		end)

		-- SOUND: click
		tile.MouseButton1Click:Connect(function()
			playUISound(SOUNDS.TileClick, 0.4)
			selectedBuilding = name
			populateGrid()
			updateDetailPanel()
		end)
	end

	local gl = gridContainer:FindFirstChildOfClass("UIGridLayout")
	if gl then gridContainer.CanvasSize = UDim2.new(0, 0, 0, gl.AbsoluteContentSize.Y + 16) end
end

local function updateCategoryHighlights()
	for key, btn in pairs(categoryButtons) do
		if key == currentCategory then btn.BackgroundColor3 = THEME.CatActive; btn.TextColor3 = THEME.TextDark
		else btn.BackgroundColor3 = THEME.CatInactive; btn.TextColor3 = THEME.TextMedium end
	end
end

local function openBuildMenu()
	if menuOpen then closeBuildMenu(); return end
	if isPlacing then return end
	menuOpen = true; selectedBuilding = nil

	-- SOUND: menu open
	playUISound(SOUNDS.MenuOpen, 0.5)

	menuGui = Instance.new("ScreenGui"); menuGui.Name = "BuildMenu"; menuGui.ResetOnSpawn = false; menuGui.Parent = playerGui

	local MENU_W, MENU_H = 680, 440

	local screenSize = camera.ViewportSize
	local startX = math.floor((screenSize.X - MENU_W) / 2)
	local startY = math.floor((screenSize.Y - MENU_H) / 2)

	local main = Instance.new("Frame"); main.Name = "Main"
	main.Size = UDim2.new(0, MENU_W, 0, MENU_H)
	main.Position = UDim2.new(0, startX, 0, startY)
	main.BackgroundTransparency = 1; main.BorderSizePixel = 0
	main.Parent = menuGui

	local mainBg = Instance.new("ImageLabel"); mainBg.Name = "PanelBg"
	mainBg.Size = UDim2.new(1, 0, 1, 0)
	mainBg.BackgroundTransparency = 1
	mainBg.Image = UI.BuildMenuPanel
	mainBg.ScaleType = Enum.ScaleType.Stretch
	mainBg.ImageTransparency = MENU_TRANSPARENCY
	mainBg.ZIndex = 0; mainBg.Parent = main

	-- === TOP BAR (drag handle) ===
	local topBar = Instance.new("TextButton"); topBar.Name = "TopBar"
	topBar.Size = UDim2.new(1, -24, 0, 36); topBar.Position = UDim2.new(0, 12, 0, 10)
	topBar.BackgroundColor3 = THEME.PanelDarker; topBar.BackgroundTransparency = 0.85
	topBar.BorderSizePixel = 0; topBar.Text = ""; topBar.AutoButtonColor = false
	topBar.Parent = main
	Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 8)

	-- Drag logic
	local dragging = false
	local dragStart = nil
	local startPos = nil

	topBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			startPos = main.Position
		end
	end)

	topBar.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - dragStart
			local newX = startPos.X.Offset + delta.X
			local newY = startPos.Y.Offset + delta.Y

			local vs = camera.ViewportSize
			local PAD = 80
			newX = math.clamp(newX, PAD - MENU_W, vs.X - PAD)
			newY = math.clamp(newY, 0, vs.Y - PAD)

			main.Position = UDim2.new(0, newX, 0, newY)
		end
	end)

	-- Title
	local tl = Instance.new("TextLabel"); tl.Size = UDim2.new(0, 70, 1, 0); tl.Position = UDim2.new(0, 10, 0, 0)
	tl.BackgroundTransparency = 1; tl.Text = "BUILD"; tl.TextColor3 = THEME.TextDark
	tl.TextSize = 16; tl.Font = Enum.Font.GothamBold; tl.TextXAlignment = Enum.TextXAlignment.Left; tl.Parent = topBar

	local dragHint = Instance.new("TextLabel")
	dragHint.Size = UDim2.new(0, 100, 0, 12); dragHint.Position = UDim2.new(0, 10, 1, -14)
	dragHint.BackgroundTransparency = 1; dragHint.Text = "— drag to move —"
	dragHint.TextColor3 = THEME.TextLight; dragHint.TextSize = 8; dragHint.Font = Enum.Font.Gotham
	dragHint.TextXAlignment = Enum.TextXAlignment.Left; dragHint.Parent = topBar

	-- Search box
	local sf = Instance.new("Frame"); sf.Size = UDim2.new(0, 200, 0, 24)
	sf.Position = UDim2.new(0.5, -100, 0.5, -12)
	sf.BackgroundColor3 = Color3.fromRGB(250, 245, 232); sf.BackgroundTransparency = 0.3
	sf.BorderSizePixel = 0; sf.Parent = topBar
	Instance.new("UICorner", sf).CornerRadius = UDim.new(0, 6)

	local sb = Instance.new("TextBox"); sb.Size = UDim2.new(1, -8, 1, 0); sb.Position = UDim2.new(0, 4, 0, 0)
	sb.BackgroundTransparency = 1; sb.Text = ""
	sb.PlaceholderText = "Search buildings..."; sb.PlaceholderColor3 = THEME.TextLight
	sb.TextColor3 = THEME.TextDark; sb.TextSize = 11; sb.Font = Enum.Font.Gotham
	sb.ClearTextOnFocus = false; sb.Parent = sf
	sb:GetPropertyChangedSignal("Text"):Connect(function() searchText = sb.Text; populateGrid() end)

	-- Close button
	local xBtn = Instance.new("TextButton"); xBtn.Size = UDim2.new(0, 28, 0, 28)
	xBtn.Position = UDim2.new(1, -32, 0.5, -14)
	xBtn.BackgroundColor3 = THEME.Red; xBtn.TextColor3 = Color3.new(1, 1, 1)
	xBtn.TextSize = 14; xBtn.Font = Enum.Font.GothamBold; xBtn.Text = "X"; xBtn.Parent = topBar
	Instance.new("UICorner", xBtn).CornerRadius = UDim.new(0, 6)
	xBtn.MouseButton1Click:Connect(function() closeBuildMenu() end)

	-- Sidebar
	local SIDEBAR_W = 100
	local sidebar = Instance.new("ScrollingFrame")
	sidebar.Size = UDim2.new(0, SIDEBAR_W, 1, -58); sidebar.Position = UDim2.new(0, 11, 0, 50)
	sidebar.BackgroundColor3 = THEME.PanelDarker; sidebar.BackgroundTransparency = 0.85
	sidebar.BorderSizePixel = 0; sidebar.ScrollBarThickness = 0
	sidebar.CanvasSize = UDim2.new(0, 0, 0, 0); sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sidebar.Parent = main
	Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 6)

	local sLayout = Instance.new("UIListLayout", sidebar); sLayout.SortOrder = Enum.SortOrder.LayoutOrder; sLayout.Padding = UDim.new(0, 2)
	local sPad = Instance.new("UIPadding", sidebar); sPad.PaddingTop = UDim.new(0, 4); sPad.PaddingBottom = UDim.new(0, 4)
	sPad.PaddingLeft = UDim.new(0, 4); sPad.PaddingRight = UDim.new(0, 4)

	categoryButtons = {}
	for i, cat in ipairs(BuildingConfig.Categories) do
		local btn = Instance.new("TextButton"); btn.Size = UDim2.new(1, 0, 0, 28)
		btn.BackgroundColor3 = THEME.CatInactive; btn.BorderSizePixel = 0
		btn.TextColor3 = THEME.TextMedium; btn.TextSize = 11; btn.Font = Enum.Font.GothamBold
		btn.Text = cat.DisplayName; btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.LayoutOrder = i; btn.Parent = sidebar
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
		Instance.new("UIPadding", btn).PaddingLeft = UDim.new(0, 6)
		categoryButtons[cat.Key] = btn
		btn.MouseButton1Click:Connect(function()
			playUISound(SOUNDS.CategoryClick, 0.35)
			currentCategory = cat.Key
			updateCategoryHighlights()
			populateGrid()
		end)
	end
	updateCategoryHighlights()

	-- Center grid
	local GRID_X = SIDEBAR_W + 22
	local GRID_W = MENU_W - SIDEBAR_W - 220
	gridContainer = Instance.new("ScrollingFrame")
	gridContainer.Size = UDim2.new(0, GRID_W, 1, -58); gridContainer.Position = UDim2.new(0, GRID_X, 0, 50)
	gridContainer.BackgroundTransparency = 1; gridContainer.BorderSizePixel = 0
	gridContainer.ScrollBarThickness = 4; gridContainer.ScrollBarImageColor3 = THEME.GoldDim
	gridContainer.Parent = main

	local gLayout = Instance.new("UIGridLayout", gridContainer)
	gLayout.CellSize = UDim2.new(0, 130, 0, 130); gLayout.CellPadding = UDim2.new(0, 5, 0, 5)
	gLayout.SortOrder = Enum.SortOrder.LayoutOrder
	local gPad = Instance.new("UIPadding", gridContainer)
	gPad.PaddingTop = UDim.new(0, 4); gPad.PaddingLeft = UDim.new(0, 4); gPad.PaddingRight = UDim.new(0, 4)
	populateGrid()

	-- Right detail panel
	local DETAIL_W = 180
	detailPanel = Instance.new("ScrollingFrame")
	detailPanel.Size = UDim2.new(0, DETAIL_W, 1, -58)
	detailPanel.Position = UDim2.new(1, -(DETAIL_W + 14), 0, 50)
	detailPanel.BackgroundColor3 = THEME.PanelDarker; detailPanel.BackgroundTransparency = 0.85
	detailPanel.BorderSizePixel = 0; detailPanel.ScrollBarThickness = 3
	detailPanel.ScrollBarImageColor3 = THEME.GoldDim
	detailPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y; detailPanel.Parent = main
	Instance.new("UICorner", detailPanel).CornerRadius = UDim.new(0, 6)

	local dLayout = Instance.new("UIListLayout", detailPanel); dLayout.SortOrder = Enum.SortOrder.LayoutOrder; dLayout.Padding = UDim.new(0, 3)
	local dPad = Instance.new("UIPadding", detailPanel)
	dPad.PaddingTop = UDim.new(0, 8); dPad.PaddingBottom = UDim.new(0, 8); dPad.PaddingLeft = UDim.new(0, 8); dPad.PaddingRight = UDim.new(0, 8)
	updateDetailPanel()
end

function closeBuildMenu()
	-- SOUND: menu close
	playUISound(SOUNDS.MenuClose, 0.5)

	cleanupViewportConnections()
	if menuGui then menuGui:Destroy(); menuGui = nil end
	menuOpen = false; gridContainer = nil; detailPanel = nil; categoryButtons = {}; searchText = ""
end

-- =============================================
-- TOOLBAR (parchment)
-- =============================================
local toolbarGui, rotationBtn, gridBtn, gridSizeLabel = nil, nil, nil, nil

local function updateToolbarUI()
	if rotationBtn then
		if freeformMode then rotationBtn.Text = "[T] Free"; rotationBtn.BackgroundColor3 = Color3.fromRGB(130,175,120)
		else rotationBtn.Text = "[T] 15° Snap"; rotationBtn.BackgroundColor3 = Color3.fromRGB(180,170,150) end
	end
	if gridBtn then
		if gridEnabled then gridBtn.Text = "[G] Grid ON"; gridBtn.BackgroundColor3 = Color3.fromRGB(130,175,120)
		else gridBtn.Text = "[G] Grid OFF"; gridBtn.BackgroundColor3 = Color3.fromRGB(180,170,150) end
	end
	if gridSizeLabel then gridSizeLabel.Text = GRID_SIZE .. " st" end
end

local function showToolbar()
	if toolbarGui then return end
	toolbarGui = Instance.new("ScreenGui"); toolbarGui.Name = "BuildToolbar"; toolbarGui.ResetOnSpawn = false; toolbarGui.Parent = playerGui
	local panel = Instance.new("Frame"); panel.Size = UDim2.new(0,160,0,220)
	panel.Position = UDim2.new(1,-170,0.5,-110); panel.BackgroundTransparency = 1; panel.BorderSizePixel = 0; panel.Parent = toolbarGui
	local bg = Instance.new("ImageLabel"); bg.Size = UDim2.new(1,0,1,0); bg.BackgroundTransparency = 1
	bg.Image = UI.ToolbarPanel; bg.ScaleType = Enum.ScaleType.Stretch; bg.ZIndex = 0; bg.Parent = panel
	local pad = Instance.new("UIPadding", panel); pad.PaddingTop = UDim.new(0,12); pad.PaddingBottom = UDim.new(0,12)
	pad.PaddingLeft = UDim.new(0,12); pad.PaddingRight = UDim.new(0,12)
	local lay = Instance.new("UIListLayout", panel); lay.SortOrder = Enum.SortOrder.LayoutOrder; lay.Padding = UDim.new(0,5)

	local ti = Instance.new("TextLabel"); ti.Size = UDim2.new(1,0,0,16); ti.BackgroundTransparency = 1
	ti.Text = "TOOLS"; ti.TextColor3 = THEME.TextDark; ti.TextSize = 12; ti.Font = Enum.Font.GothamBold; ti.LayoutOrder = 0; ti.Parent = panel

	rotationBtn = Instance.new("TextButton"); rotationBtn.Size = UDim2.new(1,0,0,26)
	rotationBtn.TextColor3 = THEME.TextDark; rotationBtn.TextSize = 10; rotationBtn.Font = Enum.Font.GothamBold
	rotationBtn.LayoutOrder = 1; rotationBtn.Parent = panel; Instance.new("UICorner", rotationBtn).CornerRadius = UDim.new(0,4)
	rotationBtn.MouseButton1Click:Connect(function() freeformMode = not freeformMode; updateToolbarUI() end)

	local rb = Instance.new("TextButton"); rb.Size = UDim2.new(1,0,0,20); rb.BackgroundColor3 = Color3.fromRGB(195,140,130)
	rb.TextColor3 = THEME.TextDark; rb.TextSize = 9; rb.Font = Enum.Font.GothamBold; rb.Text = "[V] Reset"
	rb.LayoutOrder = 2; rb.Parent = panel; Instance.new("UICorner", rb).CornerRadius = UDim.new(0,4)
	rb.MouseButton1Click:Connect(function() currentRotation = 0 end)

	local s1 = Instance.new("Frame"); s1.Size = UDim2.new(1,0,0,1); s1.BackgroundColor3 = THEME.GoldDim
	s1.BackgroundTransparency = 0.5; s1.BorderSizePixel = 0; s1.LayoutOrder = 3; s1.Parent = panel

	gridBtn = Instance.new("TextButton"); gridBtn.Size = UDim2.new(1,0,0,26)
	gridBtn.TextColor3 = THEME.TextDark; gridBtn.TextSize = 10; gridBtn.Font = Enum.Font.GothamBold
	gridBtn.LayoutOrder = 4; gridBtn.Parent = panel; Instance.new("UICorner", gridBtn).CornerRadius = UDim.new(0,4)
	gridBtn.MouseButton1Click:Connect(function() gridEnabled = not gridEnabled; if gridEnabled then showGrid() else hideGrid() end; updateToolbarUI() end)

	local sr = Instance.new("Frame"); sr.Size = UDim2.new(1,0,0,26); sr.BackgroundTransparency = 1; sr.LayoutOrder = 5; sr.Parent = panel
	local mb = Instance.new("TextButton"); mb.Size = UDim2.new(0,26,1,0); mb.BackgroundColor3 = Color3.fromRGB(180,170,150)
	mb.TextColor3 = THEME.TextDark; mb.TextSize = 14; mb.Font = Enum.Font.GothamBold; mb.Text = "-"; mb.Parent = sr
	Instance.new("UICorner", mb).CornerRadius = UDim.new(0,4)
	gridSizeLabel = Instance.new("TextLabel"); gridSizeLabel.Size = UDim2.new(1,-60,1,0); gridSizeLabel.Position = UDim2.new(0,30,0,0)
	gridSizeLabel.BackgroundTransparency = 1; gridSizeLabel.TextColor3 = THEME.TextDark; gridSizeLabel.TextSize = 10
	gridSizeLabel.Font = Enum.Font.GothamBold; gridSizeLabel.Parent = sr
	local pBtn = Instance.new("TextButton"); pBtn.Size = UDim2.new(0,26,1,0); pBtn.Position = UDim2.new(1,-26,0,0)
	pBtn.BackgroundColor3 = Color3.fromRGB(180,170,150); pBtn.TextColor3 = THEME.TextDark; pBtn.TextSize = 14
	pBtn.Font = Enum.Font.GothamBold; pBtn.Text = "+"; pBtn.Parent = sr; Instance.new("UICorner", pBtn).CornerRadius = UDim.new(0,4)
	mb.MouseButton1Click:Connect(function() if gridSizeIndex > 1 then gridSizeIndex -= 1; GRID_SIZE = GRID_SIZES[gridSizeIndex]; refreshGrid(); updateToolbarUI() end end)
	pBtn.MouseButton1Click:Connect(function() if gridSizeIndex < #GRID_SIZES then gridSizeIndex += 1; GRID_SIZE = GRID_SIZES[gridSizeIndex]; refreshGrid(); updateToolbarUI() end end)

	local ht = Instance.new("TextLabel"); ht.Size = UDim2.new(1,0,0,40); ht.BackgroundTransparency = 1
	ht.Text = "R = Rotate | V = Reset\nT = Mode | G = Grid"; ht.TextColor3 = THEME.TextLight
	ht.TextSize = 9; ht.Font = Enum.Font.Gotham; ht.TextYAlignment = Enum.TextYAlignment.Top
	ht.LayoutOrder = 7; ht.Parent = panel
	updateToolbarUI()
end

local function hideToolbar() if toolbarGui then toolbarGui:Destroy(); toolbarGui = nil; rotationBtn = nil; gridBtn = nil; gridSizeLabel = nil end end

-- Placement HUD
local placementGui = nil
function showPlacementHUD()
	if placementGui then placementGui:Destroy() end
	placementGui = Instance.new("ScreenGui"); placementGui.Name = "PlacementHUD"; placementGui.ResetOnSpawn = false; placementGui.Parent = playerGui
	local f = Instance.new("ImageLabel"); f.Size = UDim2.new(0,380,0,48); f.Position = UDim2.new(0.5,-190,1,-75)
	f.BackgroundTransparency = 1; f.Image = UI.Tooltip; f.ScaleType = Enum.ScaleType.Stretch; f.Parent = placementGui
	local config = BuildingConfig.GetBuilding(currentBuildingName)
	local dn = config and config.DisplayName or currentBuildingName
	local nl = Instance.new("TextLabel"); nl.Size = UDim2.new(1,0,0,18); nl.Position = UDim2.new(0,0,0,5)
	nl.BackgroundTransparency = 1; nl.Text = dn.."  ("..BuildingConfig.GetCostString(currentBuildingName)..")"
	nl.TextColor3 = THEME.TextDark; nl.TextSize = 12; nl.Font = Enum.Font.GothamBold; nl.Parent = f
	local cl = Instance.new("TextLabel"); cl.Size = UDim2.new(1,0,0,14); cl.Position = UDim2.new(0,0,0,24)
	cl.BackgroundTransparency = 1; cl.Text = "[Click] Place  [R] Rotate  [V] Reset  [X] Cancel"
	cl.TextColor3 = THEME.TextMedium; cl.TextSize = 10; cl.Font = Enum.Font.Gotham; cl.Parent = f
end
function hidePlacementHUD() if placementGui then placementGui:Destroy(); placementGui = nil end end

-- Placement flow
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
function cancelPlacement() destroyGhost(); hideGrid(); hideToolbar(); hidePlacementHUD(); isPlacing = false; canPlace = false; currentBuildingName = nil end

-- Input
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if isPlacing then
		if input.KeyCode == Enum.KeyCode.R then if freeformMode then holdingR = true else currentRotation += SNAP_STEP; if currentRotation >= math.pi*2 then currentRotation = 0 end end end
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

-- Render
local gridUpdateTimer = 0
RunService.RenderStepped:Connect(function(dt)
	if isPlacing then
		if freeformMode and holdingR then currentRotation += FREEFORM_SPEED*dt; if currentRotation >= math.pi*2 then currentRotation -= math.pi*2 end end
		updateGhost()
		if gridEnabled then gridUpdateTimer += dt; if gridUpdateTimer >= 0.5 then gridUpdateTimer = 0; hideGrid(); showGrid() end end
	end
end)

-- API
local api = Instance.new("BindableEvent"); api.Name = "BuildingPlacementAPI"; api.Parent = player
api.Event:Connect(function(a,...) if a == "StartPlacement" then startPlacement(...) elseif a == "CancelPlacement" then cancelPlacement() end end)

print("Building placement loaded — press B to open build menu")
