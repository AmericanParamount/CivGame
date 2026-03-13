-- CharacterHUD LocalScript
-- Location: StarterPlayerScripts > CharacterHUD
-- Unified bottom HUD panel with age label + stat icon row. Hotbar slots drawn by InventoryClient.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Events = ReplicatedStorage:WaitForChild("Events")
local StatsUpdateEvent = Events:WaitForChild("StatsUpdate")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

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

local HUD_PANEL_IMAGE = "rbxassetid://114604193327055"

-- Sizing constants
local ICON_SIZE      = 14
local ICON_GAP       = 2
local SECTION_ICONS  = 10
local DIVIDER_WIDTH  = 1
local DIVIDER_MARGIN = 6
local AGE_WIDTH      = 28
local BAR_PADDING_X  = 8
local BAR_PADDING_Y  = 2

local sectionWidth = SECTION_ICONS * ICON_SIZE + (SECTION_ICONS - 1) * ICON_GAP
local totalIconRowWidth = BAR_PADDING_X + AGE_WIDTH
	+ (DIVIDER_MARGIN * 2 + DIVIDER_WIDTH) + sectionWidth
	+ (DIVIDER_MARGIN * 2 + DIVIDER_WIDTH) + sectionWidth
	+ (DIVIDER_MARGIN * 2 + DIVIDER_WIDTH) + sectionWidth
	+ BAR_PADDING_X

local STAT_ROW_HEIGHT      = ICON_SIZE + BAR_PADDING_Y * 2
local SLOT_SIZE_NEW        = 40
local SLOT_PADDING_NEW     = 4
local GAP_BETWEEN_ROWS     = 4
local PANEL_PADDING_TOP    = 6
local PANEL_PADDING_BOTTOM = 6
-- +16 accounts for keybind labels below slots
local PANEL_HEIGHT = PANEL_PADDING_TOP + STAT_ROW_HEIGHT + GAP_BETWEEN_ROWS + SLOT_SIZE_NEW + 16 + PANEL_PADDING_BOTTOM

local HOTBAR_SIZE_CONST = 9
local PANEL_WIDTH = math.max(
	totalIconRowWidth,
	HOTBAR_SIZE_CONST * (SLOT_SIZE_NEW + SLOT_PADDING_NEW) - SLOT_PADDING_NEW + 20
)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CharacterHUD"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- =============================================
-- UNIFIED HUD PANEL
-- =============================================
local hudPanel = Instance.new("ImageLabel")
hudPanel.Name = "HUDPanel"
hudPanel.Image = HUD_PANEL_IMAGE
hudPanel.ScaleType = Enum.ScaleType.Stretch
hudPanel.BackgroundTransparency = 1
hudPanel.Size = UDim2.new(0, PANEL_WIDTH, 0, PANEL_HEIGHT)
hudPanel.Position = UDim2.new(0.5, -PANEL_WIDTH / 2, 1, -PANEL_HEIGHT - 4)
hudPanel.Parent = screenGui

-- Age label (just the number)
local ageLabel = Instance.new("TextLabel")
ageLabel.Name = "AgeLabel"
ageLabel.Size = UDim2.new(0, AGE_WIDTH, 0, STAT_ROW_HEIGHT)
ageLabel.Position = UDim2.new(0, BAR_PADDING_X, 0, PANEL_PADDING_TOP)
ageLabel.BackgroundTransparency = 1
ageLabel.Text = "5"
ageLabel.TextColor3 = Color3.fromRGB(200, 170, 90)
ageLabel.TextSize = 13
ageLabel.Font = Enum.Font.GothamBold
ageLabel.Parent = hudPanel

-- =============================================
-- STAT ICONS
-- =============================================
local healthIcons = {}
local hungerIcons = {}
local thirstIcons = {}

local iconY = PANEL_PADDING_TOP + BAR_PADDING_Y

local function makeIcon(xPos, tbl)
	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE)
	icon.Position = UDim2.new(0, xPos, 0, iconY)
	icon.BackgroundTransparency = 1
	icon.Image = ""
	icon.ScaleType = Enum.ScaleType.Fit
	icon:SetAttribute("BaseX", xPos)
	icon:SetAttribute("BaseY", iconY)
	icon.Parent = hudPanel
	tbl[#tbl + 1] = icon
	return xPos + ICON_SIZE + ICON_GAP
end

local function makeDivider(xPos)
	local div = Instance.new("Frame")
	div.Size = UDim2.new(0, DIVIDER_WIDTH, 0, STAT_ROW_HEIGHT - 4)
	div.Position = UDim2.new(0, xPos + DIVIDER_MARGIN, 0, PANEL_PADDING_TOP + 2)
	div.BackgroundColor3 = Color3.fromRGB(120, 90, 50)
	div.BackgroundTransparency = 0.5
	div.BorderSizePixel = 0
	div.Parent = hudPanel
	return xPos + DIVIDER_MARGIN * 2 + DIVIDER_WIDTH
end

local function buildStatBar()
	local x = BAR_PADDING_X + AGE_WIDTH
	x = makeDivider(x)
	for _ = 1, SECTION_ICONS do x = makeIcon(x, healthIcons) end
	x = x - ICON_GAP
	x = makeDivider(x)
	for _ = 1, SECTION_ICONS do x = makeIcon(x, hungerIcons) end
	x = x - ICON_GAP
	x = makeDivider(x)
	for _ = 1, SECTION_ICONS do x = makeIcon(x, thirstIcons) end
end

buildStatBar()

-- =============================================
-- SHARED HUD INFO (for InventoryClient positioning)
-- =============================================
local SharedHUDInfo = Instance.new("Folder")
SharedHUDInfo.Name = "SharedHUDInfo"
SharedHUDInfo.Parent = player
local panelWidthVal = Instance.new("NumberValue"); panelWidthVal.Name = "PanelWidth"; panelWidthVal.Value = PANEL_WIDTH; panelWidthVal.Parent = SharedHUDInfo
local panelHeightVal = Instance.new("NumberValue"); panelHeightVal.Name = "PanelHeight"; panelHeightVal.Value = PANEL_HEIGHT; panelHeightVal.Parent = SharedHUDInfo
local slotYVal = Instance.new("NumberValue"); slotYVal.Name = "SlotStartY"; slotYVal.Value = PANEL_PADDING_TOP + STAT_ROW_HEIGHT + GAP_BETWEEN_ROWS; slotYVal.Parent = SharedHUDInfo

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
	ageLabel.Text = tostring(stats.Age)

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
