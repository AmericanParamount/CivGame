-- CharacterHUD LocalScript
-- Location: StarterPlayerScripts > CharacterHUD
-- Parchment-themed HUD with custom image backgrounds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Events = ReplicatedStorage:WaitForChild("Events")
local StatsUpdateEvent = Events:WaitForChild("StatsUpdate")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local UI_ASSETS = {
	StatPanel  = "rbxassetid://79685099301049",
	TopInfoBar = "rbxassetid://101582090412308",
}

local ICONS = {
	Health = "rbxassetid://97444507059266",
	Hunger = "rbxassetid://76698443074638",
	Thirst = "rbxassetid://134767492227695",
	Age    = "rbxassetid://73314400891073",
}

local COLORS = {
	TextDark    = Color3.fromRGB(62, 48, 32),
	TextMedium  = Color3.fromRGB(100, 80, 55),
	TextLight   = Color3.fromRGB(140, 120, 85),
	Gold        = Color3.fromRGB(180, 145, 55),
	HealthFull  = Color3.fromRGB(180, 45, 40),
	HungerFull  = Color3.fromRGB(210, 160, 40),
	ThirstFull  = Color3.fromRGB(45, 160, 220),
	BarLow      = Color3.fromRGB(210, 155, 40),
	BarCritical = Color3.fromRGB(195, 55, 45),
	BarBg       = Color3.fromRGB(165, 150, 125),
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
-- STAT BARS PANEL
-- =============================================
local STAT_PANEL_W = 260
local STAT_PANEL_H = 180

local statPanel = Instance.new("ImageLabel")
statPanel.Name = "StatPanel"
statPanel.Size = UDim2.new(0, STAT_PANEL_W, 0, STAT_PANEL_H)
statPanel.Position = UDim2.new(0, 16, 1, -(STAT_PANEL_H + 16))
statPanel.BackgroundTransparency = 1
statPanel.Image = UI_ASSETS.StatPanel
statPanel.ScaleType = Enum.ScaleType.Stretch
statPanel.Parent = screenGui

-- =============================================
-- TUNING GUIDE:
-- ROW_Y = pixel Y-center of each bar inside the panel image
-- BAR_LEFT = how far right the bar starts (past the icon circles)
-- BAR_WIDTH = width of the colored fill bar
-- ICON_X = horizontal position of stat icons
-- Adjust these until bars sit perfectly inside the image's indented areas
-- =============================================
local ICON_X = 18
local BAR_LEFT = 52
local BAR_WIDTH = 180
local BAR_HEIGHT = 16
local ICON_SIZE = 22

-- ADJUST THESE 3 VALUES to align bars with your stat panel image:
local ROW_Y = {58, 102, 146}

local function createStatBar(name, icon, color, rowIndex)
	local yCenter = ROW_Y[rowIndex]

	local iconLabel = Instance.new("ImageLabel")
	iconLabel.Name = name .. "Icon"
	iconLabel.Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE)
	iconLabel.Position = UDim2.new(0, ICON_X, 0, yCenter - ICON_SIZE / 2)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Image = icon
	iconLabel.Parent = statPanel

	local barBg = Instance.new("Frame")
	barBg.Name = name .. "BarBg"
	barBg.Size = UDim2.new(0, BAR_WIDTH, 0, BAR_HEIGHT)
	barBg.Position = UDim2.new(0, BAR_LEFT, 0, yCenter - BAR_HEIGHT / 2)
	barBg.BackgroundColor3 = COLORS.BarBg
	barBg.BackgroundTransparency = 0.4
	barBg.BorderSizePixel = 0
	barBg.Parent = statPanel
	Instance.new("UICorner", barBg).CornerRadius = UDim.new(0, 5)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = barBg
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 5)

	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.5, 0.3),
		NumberSequenceKeypoint.new(1, 0.5),
	})
	gradient.Rotation = 270
	gradient.Parent = fill

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0.5, 0, 1, 0)
	nameLabel.Position = UDim2.new(0, 6, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = name
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	nameLabel.TextStrokeTransparency = 0.5
	nameLabel.TextSize = 10; nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.ZIndex = 3; nameLabel.Parent = barBg

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Name = "Value"
	valueLabel.Size = UDim2.new(1, -6, 1, 0)
	valueLabel.BackgroundTransparency = 1
	valueLabel.Text = "100/100"
	valueLabel.TextColor3 = Color3.new(1, 1, 1)
	valueLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	valueLabel.TextStrokeTransparency = 0.5
	valueLabel.TextSize = 10; valueLabel.Font = Enum.Font.GothamBold
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	valueLabel.ZIndex = 3; valueLabel.Parent = barBg

	return { Fill = fill, Value = valueLabel, DefaultColor = color }
end

local healthBar = createStatBar("Health", ICONS.Health, COLORS.HealthFull, 1)
local hungerBar = createStatBar("Hunger", ICONS.Hunger, COLORS.HungerFull, 2)
local thirstBar = createStatBar("Thirst", ICONS.Thirst, COLORS.ThirstFull, 3)

local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function updateBar(bar, current, max)
	local ratio = math.clamp(current / max, 0, 1)
	TweenService:Create(bar.Fill, tweenInfo, { Size = UDim2.new(ratio, 0, 1, 0) }):Play()
	bar.Value.Text = tostring(current) .. "/" .. tostring(max)
	if ratio < 0.25 then bar.Fill.BackgroundColor3 = COLORS.BarCritical
	elseif ratio < 0.5 then bar.Fill.BackgroundColor3 = COLORS.BarLow
	else bar.Fill.BackgroundColor3 = bar.DefaultColor end
end

local function updateHUD(stats)
	ageLabel.Text = "Age: " .. tostring(stats.Age)
	if stats.Age < 16 then stageLabel.Text = "Child"
	elseif stats.Age >= 55 then stageLabel.Text = "Elder"
	else stageLabel.Text = "Adult" end
	lineageLabel.Text = stats.Lineage or "Unknown"
	updateBar(healthBar, stats.Health, stats.MaxHealth)
	updateBar(hungerBar, stats.Hunger, stats.MaxHunger)
	if stats.Thirst then updateBar(thirstBar, stats.Thirst, stats.MaxThirst) end
end

StatsUpdateEvent.OnClientEvent:Connect(function(stats) updateHUD(stats) end)

local StarterGui = game:GetService("StarterGui")
local function disableDefaults() pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false) end) end
disableDefaults(); task.delay(1, disableDefaults)

print("Character HUD loaded")
