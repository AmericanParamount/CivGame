-- CharacterHUD LocalScript
-- Location: StarterPlayerScripts > CharacterHUD
-- Parchment-themed HUD with custom image backgrounds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Events = ReplicatedStorage:WaitForChild("Events")
local StatsUpdateEvent = Events:WaitForChild("StatsUpdate")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local UI_ASSETS = {
	TopInfoBar = "rbxassetid://101582090412308",
}

local ICONS = {
	Age = "rbxassetid://73314400891073",
}

local COLORS = {
	TextDark   = Color3.fromRGB(62, 48, 32),
	TextMedium = Color3.fromRGB(100, 80, 55),
	TextLight  = Color3.fromRGB(140, 120, 85),
	Gold       = Color3.fromRGB(180, 145, 55),
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CharacterHUD"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- =============================================
-- TOP INFO BAR — taller so circles show evenly
-- =============================================
local topBar = Instance.new("ImageLabel")
topBar.Name = "TopInfoBar"
topBar.Size = UDim2.new(0, 520, 0, 52)  -- taller (was 44)
topBar.Position = UDim2.new(0.5, -260, 0, 6)
topBar.BackgroundTransparency = 1
topBar.Image = UI_ASSETS.TopInfoBar
topBar.ScaleType = Enum.ScaleType.Stretch
topBar.Parent = screenGui

local ageIcon = Instance.new("ImageLabel")
ageIcon.Size = UDim2.new(0, 22, 0, 22)
ageIcon.Position = UDim2.new(0, 18, 0.5, -11)
ageIcon.BackgroundTransparency = 1
ageIcon.Image = ICONS.Age
ageIcon.Parent = topBar

local ageLabel = Instance.new("TextLabel")
ageLabel.Name = "AgeLabel"
ageLabel.Size = UDim2.new(0, 85, 1, 0)
ageLabel.Position = UDim2.new(0, 42, 0, 0)
ageLabel.BackgroundTransparency = 1
ageLabel.Text = "Age: 5"
ageLabel.TextColor3 = COLORS.TextDark
ageLabel.TextSize = 13; ageLabel.Font = Enum.Font.GothamBold
ageLabel.TextXAlignment = Enum.TextXAlignment.Left
ageLabel.Parent = topBar

local raceLabel = Instance.new("TextLabel")
raceLabel.Name = "RaceLabel"
raceLabel.Size = UDim2.new(0, 90, 1, 0)
raceLabel.Position = UDim2.new(0.25, 12, 0, 0)
raceLabel.BackgroundTransparency = 1
raceLabel.Text = "Unknown"
raceLabel.TextColor3 = COLORS.TextMedium
raceLabel.TextSize = 11; raceLabel.Font = Enum.Font.GothamBold
raceLabel.TextXAlignment = Enum.TextXAlignment.Center
raceLabel.Parent = topBar

local lineageLabel = Instance.new("TextLabel")
lineageLabel.Name = "LineageLabel"
lineageLabel.Size = UDim2.new(0, 110, 1, 0)
lineageLabel.Position = UDim2.new(0.5, 12, 0, 0)
lineageLabel.BackgroundTransparency = 1
lineageLabel.Text = "Unknown"
lineageLabel.TextColor3 = COLORS.TextMedium
lineageLabel.TextSize = 11; lineageLabel.Font = Enum.Font.Gotham
lineageLabel.TextXAlignment = Enum.TextXAlignment.Center
lineageLabel.Parent = topBar

local stageLabel = Instance.new("TextLabel")
stageLabel.Name = "StageLabel"
stageLabel.Size = UDim2.new(0, 80, 1, 0)
stageLabel.Position = UDim2.new(0.75, 12, 0, 0)
stageLabel.BackgroundTransparency = 1
stageLabel.Text = "Child"
stageLabel.TextColor3 = COLORS.TextDark
stageLabel.TextSize = 13; stageLabel.Font = Enum.Font.GothamBold
stageLabel.TextXAlignment = Enum.TextXAlignment.Center
stageLabel.Parent = topBar

-- =============================================
-- STAT BAR (unified horizontal icon bar)
-- =============================================
local STAT_ICONS = {
	HealthFull  = "rbxassetid://106591422612852",
	HealthHalf  = "rbxassetid://82042308865605",
	HealthEmpty = "rbxassetid://75702978374004",
	HungerFull  = "rbxassetid://97360668447675",
	HungerHalf  = "rbxassetid://87090025823313",
	HungerEmpty = "rbxassetid://105920765789558",
	ThirstFull  = "rbxassetid://130021588377524",
	ThirstEmpty = "rbxassetid://123937704514273",
}

local ICON_SIZE       = 18
local ICON_GAP        = 2
local SECTION_ICONS   = 10
local DIVIDER_WIDTH   = 1
local BAR_PADDING_X   = 6
local BAR_PADDING_Y   = 3
local DIVIDER_MARGIN  = 8
local BAR_BOTTOM_OFFSET = 108

local sectionWidth = SECTION_ICONS * ICON_SIZE + (SECTION_ICONS - 1) * ICON_GAP
local totalWidth   = BAR_PADDING_X * 2 + sectionWidth * 3 + (DIVIDER_MARGIN * 2 + DIVIDER_WIDTH) * 2
local barHeight    = ICON_SIZE + BAR_PADDING_Y * 2

local statBar = Instance.new("ImageLabel")
statBar.Name = "StatBar"
statBar.Size = UDim2.new(0, totalWidth, 0, barHeight)
statBar.Position = UDim2.new(0.5, -totalWidth / 2, 1, -(BAR_BOTTOM_OFFSET + barHeight))
statBar.BackgroundTransparency = 1
statBar.Image = "rbxassetid://113413200023574"
statBar.ScaleType = Enum.ScaleType.Stretch
statBar.Parent = screenGui

local healthIcons = {}
local hungerIcons = {}
local thirstIcons = {}

local function makeIcon(xPos, tbl)
	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE)
	icon.Position = UDim2.new(0, xPos, 0, BAR_PADDING_Y)
	icon.BackgroundTransparency = 1
	icon.Image = ""
	icon.ScaleType = Enum.ScaleType.Fit
	icon:SetAttribute("BaseX", xPos)
	icon:SetAttribute("BaseY", BAR_PADDING_Y)
	icon.Parent = statBar
	tbl[#tbl + 1] = icon
	return xPos + ICON_SIZE + ICON_GAP
end

local function makeDivider(xPos)
	local div = Instance.new("Frame")
	div.Size = UDim2.new(0, DIVIDER_WIDTH, 1, -6)
	div.Position = UDim2.new(0, xPos + DIVIDER_MARGIN, 0, 3)
	div.BackgroundColor3 = Color3.fromRGB(120, 90, 50)
	div.BackgroundTransparency = 0.5
	div.BorderSizePixel = 0
	div.Parent = statBar
	return xPos + DIVIDER_MARGIN * 2 + DIVIDER_WIDTH
end

local function buildStatBar()
	local x = BAR_PADDING_X
	for _ = 1, SECTION_ICONS do x = makeIcon(x, healthIcons) end
	x = x - ICON_GAP  -- remove trailing gap before divider
	x = makeDivider(x)
	for _ = 1, SECTION_ICONS do x = makeIcon(x, hungerIcons) end
	x = x - ICON_GAP
	x = makeDivider(x)
	for _ = 1, SECTION_ICONS do x = makeIcon(x, thirstIcons) end
end

buildStatBar()

-- =============================================
-- ICON STATE LOGIC
-- =============================================
local previousIconStates = {}
local popTween = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function updateStatIcons(current, max, icons, fullImg, halfImg, emptyImg)
	local pointsPerIcon = max / #icons
	for i, icon in ipairs(icons) do
		local threshold = i * pointsPerIcon
		local newState, newImage = "empty", emptyImg

		if current >= threshold then
			newState, newImage = "full", fullImg
		elseif halfImg and current >= threshold - (pointsPerIcon / 2) then
			newState, newImage = "half", halfImg
		end

		local oldState = previousIconStates[icon]
		if oldState ~= newState then
			icon.Image = newImage
			previousIconStates[icon] = newState

			if oldState ~= nil then
				local bx = icon:GetAttribute("BaseX")
				local by = icon:GetAttribute("BaseY")
				icon.Size = UDim2.new(0, ICON_SIZE * 1.4, 0, ICON_SIZE * 1.4)
				icon.Position = UDim2.new(0, bx - ICON_SIZE * 0.2, 0, by - ICON_SIZE * 0.2)
				TweenService:Create(icon, popTween, {
					Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE),
					Position = UDim2.new(0, bx, 0, by),
				}):Play()
			end
		end
	end
end

-- =============================================
-- LOW STAT PULSE
-- =============================================
local latestHealth,    latestMaxHealth    = 100, 100
local latestHunger,    latestMaxHunger    = 100, 100
local latestThirst,    latestMaxThirst    = 100, 100

local pulseTime = 0
RunService.Heartbeat:Connect(function(dt)
	pulseTime = pulseTime + dt

	local function pulseIcons(current, max, icons)
		local ratio = current / max
		if ratio > 0.25 then return end
		local speed = ratio <= 0.1 and 6 or 3
		local scale = 1 + math.sin(pulseTime * speed) * 0.08
		local offset = (scale - 1) * ICON_SIZE / 2
		for _, icon in ipairs(icons) do
			local state = previousIconStates[icon]
			if state == "full" or state == "half" then
				local bx = icon:GetAttribute("BaseX")
				local by = icon:GetAttribute("BaseY")
				icon.Size = UDim2.new(0, ICON_SIZE * scale, 0, ICON_SIZE * scale)
				icon.Position = UDim2.new(0, bx - offset, 0, by - offset)
			end
		end
	end

	pulseIcons(latestHealth, latestMaxHealth, healthIcons)
	pulseIcons(latestHunger, latestMaxHunger, hungerIcons)
	pulseIcons(latestThirst, latestMaxThirst, thirstIcons)
end)

-- =============================================
-- UPDATE
-- =============================================
local function updateHUD(stats)
	ageLabel.Text = "Age: " .. tostring(stats.Age)
	if stats.Age < 16 then stageLabel.Text = "Child"
	elseif stats.Age >= 55 then stageLabel.Text = "Elder"
	else stageLabel.Text = "Adult" end
	lineageLabel.Text = stats.Lineage or "Unknown"

	latestHealth    = stats.Health
	latestMaxHealth = stats.MaxHealth
	latestHunger    = stats.Hunger
	latestMaxHunger = stats.MaxHunger
	if stats.Thirst then
		latestThirst    = stats.Thirst
		latestMaxThirst = stats.MaxThirst
	end

	updateStatIcons(stats.Health, stats.MaxHealth, healthIcons, STAT_ICONS.HealthFull, STAT_ICONS.HealthHalf, STAT_ICONS.HealthEmpty)
	updateStatIcons(stats.Hunger, stats.MaxHunger, hungerIcons, STAT_ICONS.HungerFull, STAT_ICONS.HungerHalf, STAT_ICONS.HungerEmpty)
	if stats.Thirst then
		updateStatIcons(stats.Thirst, stats.MaxThirst, thirstIcons, STAT_ICONS.ThirstFull, nil, STAT_ICONS.ThirstEmpty)
	end
end

StatsUpdateEvent.OnClientEvent:Connect(function(stats) updateHUD(stats) end)

local StarterGui = game:GetService("StarterGui")
local function disableDefaults() pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false) end) end
disableDefaults(); task.delay(1, disableDefaults)

print("Character HUD loaded")
