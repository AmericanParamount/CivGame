-- HeldItemClient LocalScript
-- Location: StarterPlayerScripts > HeldItemClient
-- Attaches a small held model to the character's right hand based on the selected hotbar slot.
-- This is NOT the carry system (head-carry for logs/stones). This is for inventory items.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Events = ReplicatedStorage:WaitForChild("Events")
local InventoryUpdateEvent = Events:WaitForChild("InventoryUpdate", 15)
local CarryStateEvent = Events:WaitForChild("CarryStateChanged", 15)

if not InventoryUpdateEvent then warn("[HELD] Missing InventoryUpdate event!"); return end

local player = Players.LocalPlayer

-- =============================================
-- CONSTANTS
-- =============================================
local HOLD_OFFSET_R6   = CFrame.new(0, -1, 0)       -- offset from Right Arm center
local HOLD_OFFSET_TOOL = CFrame.new(0, -1, -0.5)    -- tools extend slightly forward

local DEFAULT_SHAPES = {
	Resource = {
		Size     = Vector3.new(1, 0.3, 0.3),
		Material = Enum.Material.WoodPlanks,
		Color    = Color3.fromRGB(110, 75, 35),
	},
	Tool = {
		Size     = Vector3.new(0.4, 0.4, 3),
		Material = Enum.Material.WoodPlanks,
		Color    = Color3.fromRGB(100, 70, 35),
	},
	Food = {
		Size     = Vector3.new(0.8, 0.8, 0.8),
		Material = Enum.Material.SmoothPlastic,
		Color    = Color3.fromRGB(120, 160, 70),
	},
}

-- =============================================
-- STATE
-- =============================================
local currentHeldItem  = nil   -- item name string or nil
local currentHeldModel = nil   -- Instance in workspace or nil
local isCarrying       = false
local latestSlots      = nil
local latestSelected   = 0

-- =============================================
-- HELD MODEL MANAGEMENT
-- =============================================
local function destroyHeldModel()
	if currentHeldModel then
		currentHeldModel:Destroy()
		currentHeldModel = nil
	end
end

local function getHeldItemsFolder()
	local models = ReplicatedStorage:FindFirstChild("Models")
	if not models then return nil end
	return models:FindFirstChild("HeldItems")
end

local function buildDefaultPart(category)
	local shape = DEFAULT_SHAPES[category] or DEFAULT_SHAPES.Resource
	local part = Instance.new("Part")
	part.Size      = shape.Size
	part.Material  = shape.Material
	part.Color     = shape.Color
	part.Anchored  = false
	part.CanCollide = false
	part.CastShadow = true
	part.Massless  = true
	part.Name      = "HeldItemPart"
	return part
end

local function attachHeldModel(itemName, category)
	destroyHeldModel()

	local character = player.Character
	if not character then return end
	local rightArm = character:FindFirstChild("Right Arm")    -- R6
		or character:FindFirstChild("RightHand")              -- R15
	if not rightArm then return end

	local offset = (category == "Tool") and HOLD_OFFSET_TOOL or HOLD_OFFSET_R6

	-- Try custom model first
	local heldFolder = getHeldItemsFolder()
	if heldFolder then
		local template = heldFolder:FindFirstChild(itemName)
		if template then
			local clone = template:Clone()
			clone.Name = "HeldItemModel"
			if clone:IsA("Model") then
				if not clone.PrimaryPart then
					for _, p in ipairs(clone:GetDescendants()) do
						if p:IsA("BasePart") then clone.PrimaryPart = p; break end
					end
				end
				for _, p in ipairs(clone:GetDescendants()) do
					if p:IsA("BasePart") then p.Anchored = false; p.CanCollide = false; p.Massless = true end
				end
				clone.Parent = character
				local motor = Instance.new("Motor6D")
				motor.Name = "HeldItemMotor"
				motor.Part0 = rightArm
				motor.Part1 = clone.PrimaryPart
				motor.C0 = offset
				motor.C1 = CFrame.new()
				motor.Parent = rightArm
				currentHeldModel = clone
				currentHeldItem = itemName
				return
			end
		end
	end

	-- Default: build a simple Part
	local heldPart = buildDefaultPart(category or "Resource")
	heldPart.Anchored = false
	heldPart.CanCollide = false
	heldPart.Massless = true
	heldPart.Parent = character

	local motor = Instance.new("Motor6D")
	motor.Name = "HeldItemMotor"
	motor.Part0 = rightArm
	motor.Part1 = heldPart
	motor.C0 = offset
	motor.C1 = CFrame.new()
	motor.Parent = rightArm

	currentHeldModel = heldPart
	currentHeldItem = itemName
end

-- =============================================
-- SLOT EVALUATION
-- =============================================
local function refreshHeldItem()
	if isCarrying then
		destroyHeldModel()
		currentHeldItem = nil
		return
	end

	local slots    = latestSlots
	local selected = latestSelected

	if not slots or selected == 0 then
		-- Nothing selected
		if currentHeldItem ~= nil then
			destroyHeldModel()
			currentHeldItem = nil
		end
		return
	end

	local slotData = slots[selected]
	local itemName = slotData and slotData.Name ~= "" and slotData.Name or nil
	local category = slotData and slotData.Category or "Resource"

	if itemName == currentHeldItem then return end  -- no change, skip

	if not itemName then
		destroyHeldModel()
		currentHeldItem = nil
	else
		attachHeldModel(itemName, category)
	end
end

-- =============================================
-- EVENT CONNECTIONS
-- =============================================
InventoryUpdateEvent.OnClientEvent:Connect(function(data)
	latestSlots    = data.Slots
	latestSelected = data.SelectedSlot or 0
	refreshHeldItem()
end)

if CarryStateEvent then
	CarryStateEvent.OnClientEvent:Connect(function(carrying)
		isCarrying = carrying
		refreshHeldItem()
	end)
end

player.CharacterAdded:Connect(function()
	-- Clean up old model; re-attach once character is ready if slot is active
	destroyHeldModel()
	currentHeldItem = nil
	task.wait(0.5)
	refreshHeldItem()
end)

print("[HELD ITEM] Held item client loaded")
