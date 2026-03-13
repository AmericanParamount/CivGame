-- CharacterHUD LocalScript
-- Location: StarterPlayerScripts > CharacterHUD
-- Parchment-themed HUD with custom image backgrounds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
-- STAT ICONS (Minecraft-style icon rows)
-- =============================================
local STAT_ICONS = {
	HealthFull  = "rbxassetid://78332096683950",
	HealthHalf  = "rbxassetid://130555306878603",
	HealthEmpty = "rbxassetid://118868547117519",
	HungerFull  = "rbxassetid://97360668447675",
	HungerHalf  = "rbxassetid://87090025823313",
	HungerEmpty = "rbxassetid://105920765789558",
	ThirstFull  = "rbxassetid://130021588377524",
	ThirstEmpty = "rbxassetid://123937704514273",
}

local ICON_SIZE = 18
local ICON_PADDING = 2
local ICONS_PER_STAT = 10
local STAT_ROW_GAP = 4
local STATS_BOTTOM_OFFSET = 108

local panelWidth = ICONS_PER_STAT * (ICON_SIZE + ICON_PADDING) - ICON_PADDING
local panelHeight = 3 * ICON_SIZE + 2 * STAT_ROW_GAP

local statsPanel = Instance.new("Frame")
statsPanel.Name = "StatsIconPanel"
statsPanel.Size = UDim2.new(0, panelWidth, 0, panelHeight)
statsPanel.Position = UDim2.new(0.5, -panelWidth / 2, 1, -(STATS_BOTTOM_OFFSET + panelHeight))
statsPanel.BackgroundTransparency = 1
statsPanel.BorderSizePixel = 0
statsPanel.Parent = screenGui

local healthIcons = {}
local hungerIcons = {}
local thirstIcons = {}

local function createStatIcons(tbl, rowY)
	for i = 1, ICONS_PER_STAT do
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon" .. i
		icon.Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE)
		icon.Position = UDim2.new(0, (i - 1) * (ICON_SIZE + ICON_PADDING), 0, rowY)
		icon.BackgroundTransparency = 1
		icon.Image = ""
		icon.Parent = statsPanel
		tbl[i] = icon
	end
end

createStatIcons(healthIcons, 0)
createStatIcons(hungerIcons, ICON_SIZE + STAT_ROW_GAP)
createStatIcons(thirstIcons, 2 * (ICON_SIZE + STAT_ROW_GAP))

local function updateStatIcons(current, max, icons, fullImg, halfImg, emptyImg)
	local pointsPerIcon = max / ICONS_PER_STAT
	for i = 1, ICONS_PER_STAT do
		local threshold = i * pointsPerIcon
		if current >= threshold then
			icons[i].Image = fullImg
		elseif halfImg and current >= threshold - (pointsPerIcon / 2) then
			icons[i].Image = halfImg
		else
			icons[i].Image = emptyImg
		end
	end
end

local function updateHUD(stats)
	ageLabel.Text = "Age: " .. tostring(stats.Age)
	if stats.Age < 16 then stageLabel.Text = "Child"
	elseif stats.Age >= 55 then stageLabel.Text = "Elder"
	else stageLabel.Text = "Adult" end
	lineageLabel.Text = stats.Lineage or "Unknown"
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
