-- InventoryClient LocalScript
-- Location: StarterPlayerScripts > InventoryClient
-- Floating slot tiles. Selected slot pops up larger + golden glow.
-- 1-6 toggle equip. Click food = eat. Tab = backpack.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Events = ReplicatedStorage:WaitForChild("Events")
local InventoryUpdateEvent = Events:WaitForChild("InventoryUpdate")
local SelectSlotEvent = Events:WaitForChild("SelectSlot")
local EatEvent = Events:WaitForChild("EatItem")
local DropItemEvent = Events:WaitForChild("DropItem")
local SwapSlotsEvent = Events:WaitForChild("SwapSlots")
local CarryStateEvent = Events:WaitForChild("CarryStateChanged", 10)
local isCarrying = false

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()

local UI_ASSETS = {
	SlotTile    = "rbxassetid://94301633349386",
	HotbarPanel = "rbxassetid://104728264943743",
}

local THEME = {
	TextDark     = Color3.fromRGB(62, 48, 32),
	TextMedium   = Color3.fromRGB(100, 80, 55),
	TextLight    = Color3.fromRGB(140, 120, 85),
	Gold         = Color3.fromRGB(180, 145, 55),
	GoldBright   = Color3.fromRGB(220, 190, 70),
	SelectedGlow = Color3.fromRGB(255, 210, 50),
}

local HOTBAR_SIZE = 6
local TOTAL_SLOTS = 24
local SLOT_SIZE = 52
local SLOT_PADDING = 8

local inventoryData = nil
local selectedSlot = 0
local backpackOpen = false

local hotbarGui = nil
local hotbarSlots = {}
local backpackGui = nil
local backpackSlots = {}

-- Animation configs
local popUpTween = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local popDownTween = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Normal and selected positions (selected rises up by 10px and grows)
local SELECTED_RISE = 10
local SELECTED_GROW = 10  -- extra pixels on each side

-- =============================================
-- CREATE HOTBAR
-- =============================================
local function createHotbar()
	hotbarGui = Instance.new("ScreenGui")
	hotbarGui.Name = "HotbarGui"
	hotbarGui.ResetOnSpawn = false
	hotbarGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	hotbarGui.Parent = playerGui

	local totalWidth = HOTBAR_SIZE * (SLOT_SIZE + SLOT_PADDING) - SLOT_PADDING
	local container = Instance.new("Frame")
	container.Name = "HotbarContainer"
	container.Size = UDim2.new(0, totalWidth + 20, 0, SLOT_SIZE + SELECTED_RISE + 30)
	container.Position = UDim2.new(0.5, -(totalWidth + 20) / 2, 1, -(SLOT_SIZE + SELECTED_RISE + 38))
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.Parent = hotbarGui

	for i = 1, HOTBAR_SIZE do
		local xPos = 10 + (i - 1) * (SLOT_SIZE + SLOT_PADDING)
		local yNormal = SELECTED_RISE  -- slots sit below the rise area

		local slot = Instance.new("TextButton")
		slot.Name = "Slot" .. i
		slot.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
		slot.Position = UDim2.new(0, xPos, 0, yNormal)
		slot.BackgroundTransparency = 1
		slot.Text = ""
		slot.AutoButtonColor = false
		slot.ZIndex = 2
		slot.Parent = container

		-- Slot tile image
		local slotImg = Instance.new("ImageLabel")
		slotImg.Name = "SlotImage"
		slotImg.Size = UDim2.new(1, 0, 1, 0)
		slotImg.BackgroundTransparency = 1
		slotImg.Image = UI_ASSETS.SlotTile
		slotImg.ScaleType = Enum.ScaleType.Stretch
		slotImg.Parent = slot

		-- Golden glow border (hidden by default)
		local glowStroke = Instance.new("UIStroke")
		glowStroke.Name = "GlowStroke"
		glowStroke.Color = THEME.SelectedGlow
		glowStroke.Thickness = 3
		glowStroke.Transparency = 1
		glowStroke.Parent = slot
		Instance.new("UICorner", slot).CornerRadius = UDim.new(0, 6)

		-- Item name
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "ItemName"
		nameLabel.Size = UDim2.new(1, -6, 0, 13)
		nameLabel.Position = UDim2.new(0, 3, 0, 3)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = ""
		nameLabel.TextColor3 = THEME.TextDark
		nameLabel.TextStrokeColor3 = Color3.fromRGB(230, 220, 195)
		nameLabel.TextStrokeTransparency = 0.3
		nameLabel.TextSize = 9
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.ZIndex = 3
		nameLabel.Parent = slot

		-- Item count
		local countLabel = Instance.new("TextLabel")
		countLabel.Name = "ItemCount"
		countLabel.Size = UDim2.new(0, 22, 0, 14)
		countLabel.Position = UDim2.new(1, -24, 1, -17)
		countLabel.BackgroundTransparency = 1
		countLabel.Text = ""
		countLabel.TextColor3 = THEME.TextDark
		countLabel.TextStrokeColor3 = Color3.fromRGB(230, 220, 195)
		countLabel.TextStrokeTransparency = 0.3
		countLabel.TextSize = 11
		countLabel.Font = Enum.Font.GothamBold
		countLabel.TextXAlignment = Enum.TextXAlignment.Right
		countLabel.ZIndex = 3
		countLabel.Parent = slot

		-- Keybind number below
		local keyLabel = Instance.new("TextLabel")
		keyLabel.Name = "KeyLabel"
		keyLabel.Size = UDim2.new(0, SLOT_SIZE, 0, 14)
		keyLabel.Position = UDim2.new(0, xPos, 0, yNormal + SLOT_SIZE + 3)
		keyLabel.BackgroundTransparency = 1
		keyLabel.Text = tostring(i)
		keyLabel.TextColor3 = THEME.TextLight
		keyLabel.TextSize = 10
		keyLabel.Font = Enum.Font.GothamBold
		keyLabel.Parent = container

		-- Store the normal position for animations
		slot:SetAttribute("NormalX", xPos)
		slot:SetAttribute("NormalY", yNormal)

		local index = i
		slot.MouseButton1Click:Connect(function()
			toggleSlot(index)
		end)

		hotbarSlots[i] = slot
	end
end

-- =============================================
-- ANIMATE SLOT SELECTION
-- =============================================
local function animateSlot(slot, isSelected)
	if not slot then return end
	local glowStroke = slot:FindFirstChild("GlowStroke")
	local normalX = slot:GetAttribute("NormalX") or 0
	local normalY = slot:GetAttribute("NormalY") or 0

	if isSelected then
		-- Pop up: grow larger, shift up, show glow
		TweenService:Create(slot, popUpTween, {
			Size = UDim2.new(0, SLOT_SIZE + SELECTED_GROW, 0, SLOT_SIZE + SELECTED_GROW),
			Position = UDim2.new(0, normalX - SELECTED_GROW / 2, 0, normalY - SELECTED_RISE)
		}):Play()
		if glowStroke then
			TweenService:Create(glowStroke, popUpTween, { Transparency = 0 }):Play()
		end
		slot.ZIndex = 5  -- above other slots
	else
		-- Pop down: return to normal
		TweenService:Create(slot, popDownTween, {
			Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE),
			Position = UDim2.new(0, normalX, 0, normalY)
		}):Play()
		if glowStroke then
			TweenService:Create(glowStroke, popDownTween, { Transparency = 1 }):Play()
		end
		slot.ZIndex = 2
	end
end

-- =============================================
-- CREATE BACKPACK
-- =============================================
local function createBackpack()
	backpackGui = Instance.new("ScreenGui")
	backpackGui.Name = "BackpackGui"
	backpackGui.ResetOnSpawn = false
	backpackGui.Enabled = false
	backpackGui.Parent = playerGui

	local cols = 6
	local rows = 3
	local bpWidth = cols * (SLOT_SIZE + SLOT_PADDING) - SLOT_PADDING + 24
	local bpHeight = rows * (SLOT_SIZE + SLOT_PADDING) - SLOT_PADDING + 40

	local container = Instance.new("ImageLabel")
	container.Name = "BackpackPanel"
	container.Size = UDim2.new(0, bpWidth, 0, bpHeight)
	container.Position = UDim2.new(0.5, -bpWidth / 2, 1, -(SLOT_SIZE + SELECTED_RISE + 38) - bpHeight - 6)
	container.BackgroundTransparency = 1
	container.Image = UI_ASSETS.HotbarPanel
	container.ScaleType = Enum.ScaleType.Stretch
	container.Parent = backpackGui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 24)
	title.Position = UDim2.new(0, 0, 0, 6)
	title.BackgroundTransparency = 1
	title.Text = "BACKPACK"
	title.TextColor3 = THEME.TextDark
	title.TextSize = 13
	title.Font = Enum.Font.GothamBold
	title.Parent = container

	for i = 1, TOTAL_SLOTS - HOTBAR_SIZE do
		local slotIndex = HOTBAR_SIZE + i
		local col = (i - 1) % cols
		local row = math.floor((i - 1) / cols)

		local slot = Instance.new("TextButton")
		slot.Name = "BPSlot" .. slotIndex
		slot.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
		slot.Position = UDim2.new(0, 12 + SLOT_PADDING + col * (SLOT_SIZE + SLOT_PADDING), 0, 32 + row * (SLOT_SIZE + SLOT_PADDING))
		slot.BackgroundTransparency = 1
		slot.Text = ""
		slot.AutoButtonColor = false
		slot.Parent = container

		local slotImg = Instance.new("ImageLabel")
		slotImg.Name = "SlotImage"
		slotImg.Size = UDim2.new(1, 0, 1, 0)
		slotImg.BackgroundTransparency = 1
		slotImg.Image = UI_ASSETS.SlotTile
		slotImg.ScaleType = Enum.ScaleType.Stretch
		slotImg.Parent = slot

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "ItemName"
		nameLabel.Size = UDim2.new(1, -6, 0, 13)
		nameLabel.Position = UDim2.new(0, 3, 0, 3)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = ""
		nameLabel.TextColor3 = THEME.TextDark
		nameLabel.TextSize = 9
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.ZIndex = 3
		nameLabel.Parent = slot

		local countLabel = Instance.new("TextLabel")
		countLabel.Name = "ItemCount"
		countLabel.Size = UDim2.new(0, 22, 0, 14)
		countLabel.Position = UDim2.new(1, -24, 1, -17)
		countLabel.BackgroundTransparency = 1
		countLabel.Text = ""
		countLabel.TextColor3 = THEME.TextDark
		countLabel.TextSize = 11
		countLabel.Font = Enum.Font.GothamBold
		countLabel.TextXAlignment = Enum.TextXAlignment.Right
		countLabel.ZIndex = 3
		countLabel.Parent = slot

		backpackSlots[slotIndex] = slot
	end
end

-- =============================================
-- UPDATE DISPLAY
-- =============================================
local function updateSlotDisplay(slotUI, slotData, isSelected, isHotbar)
	if not slotUI then return end
	local nameLabel = slotUI:FindFirstChild("ItemName")
	local countLabel = slotUI:FindFirstChild("ItemCount")
	local slotImg = slotUI:FindFirstChild("SlotImage")

	if slotData and slotData.Name ~= "" then
		if nameLabel then nameLabel.Text = slotData.DisplayName or slotData.Name end
		if countLabel then countLabel.Text = slotData.Count > 1 and tostring(slotData.Count) or "" end
		if slotImg then slotImg.ImageTransparency = 0 end
	else
		if nameLabel then nameLabel.Text = "" end
		if countLabel then countLabel.Text = "" end
		if slotImg then slotImg.ImageTransparency = 0.2 end
	end

	-- Animate hotbar slots
	if isHotbar then
		animateSlot(slotUI, isSelected)
	end
end

local function refreshUI()
	if not inventoryData then return end
	for i = 1, HOTBAR_SIZE do
		local slotData = inventoryData.Slots[i]
		updateSlotDisplay(hotbarSlots[i], slotData, selectedSlot == i, true)
	end
	for i = HOTBAR_SIZE + 1, TOTAL_SLOTS do
		local slotData = inventoryData.Slots[i]
		updateSlotDisplay(backpackSlots[i], slotData, false, false)
	end
end

-- =============================================
-- SLOT TOGGLE
-- =============================================
function toggleSlot(index)
	if not inventoryData then return end
	if isCarrying then return end
	if index < 1 or index > HOTBAR_SIZE then return end

	local slotData = inventoryData.Slots[index]
	if not slotData or slotData.Name == "" then
		if selectedSlot ~= 0 then
			selectedSlot = 0
			SelectSlotEvent:FireServer(0)
			refreshUI()
		end
		return
	end

	if selectedSlot == index then
		selectedSlot = 0
		SelectSlotEvent:FireServer(0)
	else
		selectedSlot = index
		SelectSlotEvent:FireServer(index)
	end
	refreshUI()
end

-- =============================================
-- EAT / SELECTED INFO
-- =============================================
local function tryEatSelected()
	if selectedSlot == 0 or not inventoryData then return false end
	local slotData = inventoryData.Slots[selectedSlot]
	if not slotData or slotData.Name == "" then return false end
	if slotData.Category ~= "Food" then return false end
	EatEvent:FireServer()
	return true
end

local eatBinding = Instance.new("BindableFunction")
eatBinding.Name = "TryEatSelected"
eatBinding.OnInvoke = function() return tryEatSelected() end
eatBinding.Parent = player

local selectedInfoBinding = Instance.new("BindableFunction")
selectedInfoBinding.Name = "GetSelectedItemInfo"
selectedInfoBinding.OnInvoke = function()
	if selectedSlot == 0 or not inventoryData then return nil end
	local slotData = inventoryData.Slots[selectedSlot]
	if not slotData or slotData.Name == "" then return nil end
	return slotData
end
selectedInfoBinding.Parent = player

-- =============================================
-- INPUT
-- =============================================
local KEY_TO_SLOT = {
	[Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5, [Enum.KeyCode.Six] = 6,
}

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	local slot = KEY_TO_SLOT[input.KeyCode]
	if slot then toggleSlot(slot) end
	if input.KeyCode == Enum.KeyCode.Tab then
		backpackOpen = not backpackOpen
		if backpackGui then backpackGui.Enabled = backpackOpen end
	end
	if input.KeyCode == Enum.KeyCode.Q then
		if isCarrying then return end
		if selectedSlot > 0 and inventoryData then
			local slotData = inventoryData.Slots[selectedSlot]
			if slotData and slotData.Name ~= "" then
				DropItemEvent:FireServer(selectedSlot, 1)
			end
		end
	end
end)

-- =============================================
-- SERVER UPDATES
-- =============================================
InventoryUpdateEvent.OnClientEvent:Connect(function(data)
	inventoryData = data
	HOTBAR_SIZE = data.HotbarSize or 6
	TOTAL_SLOTS = data.TotalSlots or 24
	if selectedSlot > 0 then
		local slotData = data.Slots[selectedSlot]
		if not slotData or slotData.Name == "" then
			selectedSlot = 0
		end
	end
	refreshUI()
end)

-- =============================================
-- INIT
-- =============================================
createHotbar()
createBackpack()

if CarryStateEvent then
	CarryStateEvent.OnClientEvent:Connect(function(carrying)
		isCarrying = carrying
		if carrying and selectedSlot ~= 0 then
			selectedSlot = 0
			SelectSlotEvent:FireServer(0)
			refreshUI()
		end
	end)
end

local StarterGui = game:GetService("StarterGui")
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)
task.delay(1, function()
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)
end)

-- =============================================
-- WORLD PICKUP (HOVER + E)
-- =============================================
local PickupItemEvent = Events:WaitForChild("PickupInventoryItem", 10)
local currentHighlight = nil
local hoveredPickup = nil

local function createPickupPrompt()
	local gui = Instance.new("ScreenGui")
	gui.Name = "PickupPromptGui"
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "PromptFrame"
	frame.Size = UDim2.new(0, 140, 0, 30)
	frame.BackgroundColor3 = Color3.fromRGB(40, 32, 22)
	frame.BackgroundTransparency = 0.3
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = gui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "[E] Pick up"
	label.TextColor3 = Color3.fromRGB(230, 220, 195)
	label.TextSize = 12
	label.Font = Enum.Font.GothamBold
	label.Parent = frame

	return frame
end

local promptFrame = createPickupPrompt()
local PICKUP_HOVER_RANGE = 12

local function getMousePickup()
	local target = mouse.Target
	if not target then return nil end
	if target:FindFirstChild("IsPickup") then return target end
	if target.Parent and target.Parent:FindFirstChild("IsPickup") then return target.Parent end
	return nil
end

RunService.RenderStepped:Connect(function()
	local pickup = getMousePickup()

	if pickup and pickup:FindFirstChild("ItemName") then
		local character = player.Character
		if character and character:FindFirstChild("HumanoidRootPart") then
			local dist = (character.HumanoidRootPart.Position - pickup.Position).Magnitude
			if dist <= PICKUP_HOVER_RANGE then
				if hoveredPickup ~= pickup then
					if currentHighlight then currentHighlight:Destroy() end
					currentHighlight = Instance.new("SelectionBox")
					currentHighlight.Adornee = pickup
					currentHighlight.Color3 = Color3.fromRGB(255, 210, 50)
					currentHighlight.LineThickness = 0.03
					currentHighlight.SurfaceTransparency = 0.85
					currentHighlight.SurfaceColor3 = Color3.fromRGB(255, 220, 100)
					currentHighlight.Parent = pickup
					hoveredPickup = pickup
				end
				local itemName = pickup:FindFirstChild("ItemName")
				promptFrame.Visible = true
				promptFrame.Label.Text = "[E] " .. (itemName and itemName.Value or "Pick up")
				promptFrame.Position = UDim2.new(0, mouse.X + 16, 0, mouse.Y - 15)
				return
			end
		end
	end

	if currentHighlight then currentHighlight:Destroy(); currentHighlight = nil end
	hoveredPickup = nil
	promptFrame.Visible = false
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.E then
		if hoveredPickup and hoveredPickup.Parent and PickupItemEvent then
			PickupItemEvent:FireServer(hoveredPickup)
		end
	end
end)

print("[INVENTORY] Inventory client loaded")
