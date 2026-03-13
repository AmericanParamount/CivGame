-- HeldItemClient LocalScript
-- Location: StarterPlayerScripts > HeldItemClient
-- Attaches a small held model to the character's right hand based on the selected hotbar slot.
-- This is NOT the carry system (head-carry for logs/stones). This is for inventory items.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Events = ReplicatedStorage:WaitForChild("Events")
local InventoryUpdateEvent = Events:WaitForChild("InventoryUpdate", 15)

if not InventoryUpdateEvent then warn("[HELD] Missing InventoryUpdate event!"); return end

local player = Players.LocalPlayer

-- =============================================
-- CONSTANTS
-- =============================================
local HOLD_OFFSET_R6   = CFrame.new(0, -1, 0)       -- offset from Right Arm center
local HOLD_OFFSET_TOOL = CFrame.new(0, -1, -0.5)    -- tools extend slightly forward

local MODEL_NAME_OVERRIDES = {
	Sticks = "Stick",
}

local ITEM_HOLD_OFFSETS = {
	Sticks = CFrame.new(0, -1, 0) * CFrame.Angles(math.rad(90), 0, 0),
}

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

	local offset = ITEM_HOLD_OFFSETS[itemName] or ((category == "Tool") and HOLD_OFFSET_TOOL or HOLD_OFFSET_R6)
	local heldPart = nil
	local heldRoot = nil  -- top-level instance tracked for cleanup

	-- Try custom model first
	local heldFolder = getHeldItemsFolder()
	if heldFolder then
		local modelName = MODEL_NAME_OVERRIDES[itemName] or itemName
		local template = heldFolder:FindFirstChild(modelName)
		if template then
			local clone = template:Clone()
			clone.Name = "HeldItemModel"

			if clone:IsA("Model") then
				if not clone.PrimaryPart then
					for _, p in ipairs(clone:GetDescendants()) do
						if p:IsA("BasePart") then clone.PrimaryPart = p; break end
					end
				end
				if clone.PrimaryPart then
					for _, p in ipairs(clone:GetDescendants()) do
						if p:IsA("BasePart") then p.Anchored = false; p.CanCollide = false; p.Massless = true end
					end
					clone.Parent = character
					heldPart = clone.PrimaryPart
					heldRoot = clone
				else
					clone:Destroy()
				end

			elseif clone:IsA("BasePart") then
				clone.Anchored = false
				clone.CanCollide = false
				clone.Massless = true
				clone.Parent = character
				heldPart = clone
				heldRoot = clone
			else
				clone:Destroy()
			end
		end
	end

	-- Fallback: build default part
	if not heldPart then
		local defaultPart = buildDefaultPart(category or "Resource")
		defaultPart.Anchored = false
		defaultPart.CanCollide = false
		defaultPart.Massless = true
		defaultPart.Parent = character
		heldPart = defaultPart
		heldRoot = defaultPart
	end

	local motor = Instance.new("Motor6D")
	motor.Name = "HeldItemMotor"
	motor.Part0 = rightArm
	motor.Part1 = heldPart
	motor.C0 = offset
	motor.C1 = CFrame.new()
	motor.Parent = rightArm

	currentHeldModel = heldRoot
	currentHeldItem = itemName
	print("[HELD] Attached " .. itemName .. " to right hand")
end

-- =============================================
-- SLOT EVALUATION
-- =============================================
local function refreshHeldItem()
	print("[HELD] refreshHeldItem: selected=" .. tostring(latestSelected) .. " currentHeld=" .. tostring(currentHeldItem))
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

player.CharacterAdded:Connect(function()
	-- Clean up old model; re-attach once character is ready if slot is active
	destroyHeldModel()
	currentHeldItem = nil
	task.wait(0.5)
	refreshHeldItem()
end)

print("[HELD ITEM] Held item client loaded")
