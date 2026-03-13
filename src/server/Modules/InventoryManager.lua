-- InventoryManager ModuleScript
-- Location: ServerScriptService > Modules > InventoryManager

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local ItemConfig = require(Modules:WaitForChild("ItemConfig"))

local InventoryManager = {}

local HOTBAR_SLOTS = 6
local BACKPACK_SLOTS = 18
local TOTAL_SLOTS = HOTBAR_SLOTS + BACKPACK_SLOTS

local inventories = {}

local Events = ReplicatedStorage:WaitForChild("Events")
local InventoryUpdateEvent = Events:FindFirstChild("InventoryUpdate")
if not InventoryUpdateEvent then
	InventoryUpdateEvent = Instance.new("RemoteEvent"); InventoryUpdateEvent.Name = "InventoryUpdate"; InventoryUpdateEvent.Parent = Events
end

local PickupItemEvent = Events:FindFirstChild("PickupInventoryItem")
if not PickupItemEvent then
	PickupItemEvent = Instance.new("RemoteEvent"); PickupItemEvent.Name = "PickupInventoryItem"; PickupItemEvent.Parent = Events
end

function InventoryManager.InitPlayer(player)
	local slots = {}
	for i = 1, TOTAL_SLOTS do slots[i] = { Name = "", Count = 0 } end
	inventories[player.UserId] = { Slots = slots, SelectedSlot = 0 }
	InventoryManager.SyncToClient(player)
end

function InventoryManager.ClearInventory(player)
	local inv = inventories[player.UserId]; if not inv then return end
	for i = 1, TOTAL_SLOTS do inv.Slots[i] = { Name = "", Count = 0 } end
	InventoryManager.SyncToClient(player)
end

function InventoryManager.AddItem(player, itemName, count)
	if not ItemConfig.IsValidItem(itemName) then warn("Tried to add invalid item: " .. tostring(itemName)); return 0 end
	local inv = inventories[player.UserId]; if not inv then return 0 end
	local maxStack = ItemConfig.GetMaxStack(itemName); local remaining = count
	for i = 1, TOTAL_SLOTS do
		if remaining <= 0 then break end
		local slot = inv.Slots[i]
		if slot.Name == itemName and slot.Count < maxStack then
			local space = maxStack - slot.Count; local toAdd = math.min(remaining, space)
			slot.Count = slot.Count + toAdd; remaining = remaining - toAdd
		end
	end
	for i = 1, TOTAL_SLOTS do
		if remaining <= 0 then break end
		local slot = inv.Slots[i]
		if slot.Name == "" then
			local toAdd = math.min(remaining, maxStack)
			slot.Name = itemName; slot.Count = toAdd; remaining = remaining - toAdd
		end
	end
	local added = count - remaining
	if added > 0 then InventoryManager.SyncToClient(player) end
	return added
end

function InventoryManager.RemoveItem(player, itemName, count)
	local inv = inventories[player.UserId]; if not inv then return 0 end
	local remaining = count
	for i = TOTAL_SLOTS, 1, -1 do
		if remaining <= 0 then break end
		local slot = inv.Slots[i]
		if slot.Name == itemName then
			local toRemove = math.min(remaining, slot.Count)
			slot.Count = slot.Count - toRemove; remaining = remaining - toRemove
			if slot.Count <= 0 then slot.Name = ""; slot.Count = 0 end
		end
	end
	local removed = count - remaining
	if removed > 0 then InventoryManager.SyncToClient(player) end
	return removed
end

function InventoryManager.RemoveFromSlot(player, slotIndex, count)
	local inv = inventories[player.UserId]; if not inv then return 0 end
	if slotIndex < 1 or slotIndex > TOTAL_SLOTS then return 0 end
	local slot = inv.Slots[slotIndex]; if slot.Name == "" then return 0 end
	local toRemove = math.min(count, slot.Count)
	slot.Count = slot.Count - toRemove
	if slot.Count <= 0 then slot.Name = ""; slot.Count = 0 end
	InventoryManager.SyncToClient(player); return toRemove
end

function InventoryManager.HasItem(player, itemName, count)
	local inv = inventories[player.UserId]; if not inv then return false end
	local total = 0
	for i = 1, TOTAL_SLOTS do if inv.Slots[i].Name == itemName then total = total + inv.Slots[i].Count end end
	return total >= count
end

function InventoryManager.CountItem(player, itemName)
	local inv = inventories[player.UserId]; if not inv then return 0 end
	local total = 0
	for i = 1, TOTAL_SLOTS do if inv.Slots[i].Name == itemName then total = total + inv.Slots[i].Count end end
	return total
end

function InventoryManager.GetSelectedItem(player)
	local inv = inventories[player.UserId]; if not inv then return nil, 0 end
	if inv.SelectedSlot < 1 then return nil, 0 end
	local slot = inv.Slots[inv.SelectedSlot]
	if slot and slot.Name ~= "" then return slot.Name, slot.Count end
	return nil, 0
end

function InventoryManager.SetSelectedSlot(player, slotIndex)
	local inv = inventories[player.UserId]; if not inv then return end
	if slotIndex < 0 or slotIndex > HOTBAR_SLOTS then return end
	inv.SelectedSlot = slotIndex; InventoryManager.SyncToClient(player)
end

function InventoryManager.UseSelectedItem(player)
	local inv = inventories[player.UserId]; if not inv then return false end
	local slot = inv.Slots[inv.SelectedSlot]; if slot.Name == "" then return false end
	local foodValues = ItemConfig.GetFoodValues(slot.Name)
	if foodValues then
		slot.Count = slot.Count - 1
		if slot.Count <= 0 then slot.Name = ""; slot.Count = 0 end
		if foodValues.Hunger > 0 then
			local feedFunc = Events:FindFirstChild("FeedPlayer")
			if feedFunc then feedFunc:Invoke(player, foodValues.Hunger) end
		end
		if foodValues.Thirst > 0 then
			local hydrateFunc = Events:FindFirstChild("HydratePlayer")
			if hydrateFunc then hydrateFunc:Invoke(player, foodValues.Thirst) end
		end
		if foodValues.Health > 0 then
			local healFunc = Events:FindFirstChild("HealPlayer")
			if healFunc then healFunc:Invoke(player, foodValues.Health) end
		end
		InventoryManager.SyncToClient(player); return true
	end
	return false
end

function InventoryManager.SwapSlots(player, slotA, slotB)
	local inv = inventories[player.UserId]; if not inv then return end
	if slotA < 1 or slotA > TOTAL_SLOTS then return end
	if slotB < 1 or slotB > TOTAL_SLOTS then return end
	local temp = inv.Slots[slotA]; inv.Slots[slotA] = inv.Slots[slotB]; inv.Slots[slotB] = temp
	InventoryManager.SyncToClient(player)
end

function InventoryManager.DropItem(player, slotIndex, count)
	local inv = inventories[player.UserId]; if not inv then return end
	if slotIndex < 1 or slotIndex > TOTAL_SLOTS then return end
	local slot = inv.Slots[slotIndex]; if slot.Name == "" then return end
	local toDrop = math.min(count, slot.Count); local itemName = slot.Name
	slot.Count = slot.Count - toDrop
	if slot.Count <= 0 then slot.Name = ""; slot.Count = 0 end
	local character = player.Character
	if character then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			local dropPos = root.Position + root.CFrame.LookVector * 5 + Vector3.new(0, 0.5, 0)
			InventoryManager.CreateWorldPickup(itemName, toDrop, dropPos)
		end
	end
	InventoryManager.SyncToClient(player)
end

function InventoryManager.CreateWorldPickup(itemName, count, position)
	local itemData = ItemConfig.GetItem(itemName)
	if not itemData then return end

	local pickupsFolder = workspace:FindFirstChild("Pickups")
	if not pickupsFolder then
		pickupsFolder = Instance.new("Folder")
		pickupsFolder.Name = "Pickups"
		pickupsFolder.Parent = workspace
	end

	-- Try to find a custom model in ReplicatedStorage > Models > HeldItems
	local pickup = nil
	local modelsFolder = ReplicatedStorage:FindFirstChild("Models")
	if modelsFolder then
		local heldItems = modelsFolder:FindFirstChild("HeldItems")
		if heldItems then
			local template = heldItems:FindFirstChild(itemName)
			if not template then
				-- Try common name overrides
				local overrides = { Sticks = "Stick" }
				local altName = overrides[itemName]
				if altName then template = heldItems:FindFirstChild(altName) end
			end
			if template then
				pickup = template:Clone()
				pickup.Name = "Pickup_" .. itemName
				if pickup:IsA("Model") then
					if not pickup.PrimaryPart then
						for _, p in ipairs(pickup:GetDescendants()) do
							if p:IsA("BasePart") then pickup.PrimaryPart = p; break end
						end
					end
					for _, p in ipairs(pickup:GetDescendants()) do
						if p:IsA("BasePart") then p.Anchored = false; p.CanCollide = true end
					end
					if pickup.PrimaryPart then
						pickup:PivotTo(CFrame.new(position))
					else
						pickup:Destroy(); pickup = nil
					end
				elseif pickup:IsA("BasePart") then
					pickup.Anchored = false
					pickup.CanCollide = true
					pickup.Position = position
				else
					pickup:Destroy(); pickup = nil
				end
			end
		end
	end

	-- Fallback: generic block if no custom model found
	if not pickup then
		pickup = Instance.new("Part")
		pickup.Name = "Pickup_" .. itemName
		pickup.Size = Vector3.new(2, 2, 2)
		pickup.Position = position
		pickup.Anchored = false
		pickup.CanCollide = true
		pickup.Material = Enum.Material.SmoothPlastic
		pickup.Shape = Enum.PartType.Block
		if itemData.Category == "Resource" then pickup.Color = Color3.fromRGB(139, 105, 65)
		elseif itemData.Category == "Food" then pickup.Color = Color3.fromRGB(120, 180, 80)
		else pickup.Color = Color3.fromRGB(160, 160, 160) end
	end
	local nameVal = Instance.new("StringValue"); nameVal.Name = "ItemName"; nameVal.Value = itemName; nameVal.Parent = pickup
	local countVal = Instance.new("IntValue"); countVal.Name = "ItemCount"; countVal.Value = count; countVal.Parent = pickup
	local pickupTag = Instance.new("StringValue"); pickupTag.Name = "IsPickup"; pickupTag.Value = "true"; pickupTag.Parent = pickup
	local bb = Instance.new("BillboardGui"); bb.Size = UDim2.new(0, 100, 0, 30)
	bb.StudsOffset = Vector3.new(0, 2, 0); bb.AlwaysOnTop = false; bb.MaxDistance = 30; bb.Parent = pickup
	local label = Instance.new("TextLabel"); label.Size = UDim2.new(1, 0, 1, 0); label.BackgroundTransparency = 1
	label.Text = itemData.DisplayName .. " x" .. count; label.TextColor3 = Color3.fromRGB(255, 255, 200)
	label.TextStrokeTransparency = 0.5; label.TextSize = 13; label.Font = Enum.Font.GothamBold; label.Parent = bb
	task.delay(300, function() if pickup.Parent then pickup:Destroy() end end)
	pickup.Parent = pickupsFolder
end

function InventoryManager.SyncToClient(player)
	local inv = inventories[player.UserId]; if not inv then return end
	local slotData = {}
	for i = 1, TOTAL_SLOTS do
		local slot = inv.Slots[i]
		if slot.Name ~= "" then
			local itemData = ItemConfig.GetItem(slot.Name)
			slotData[i] = { Name = slot.Name, DisplayName = itemData and itemData.DisplayName or slot.Name, Count = slot.Count, Category = itemData and itemData.Category or "Unknown" }
		else slotData[i] = { Name = "", DisplayName = "", Count = 0, Category = "" } end
	end
	InventoryUpdateEvent:FireClient(player, { Slots = slotData, SelectedSlot = inv.SelectedSlot, HotbarSize = HOTBAR_SLOTS, TotalSlots = TOTAL_SLOTS })
end

function InventoryManager.RemovePlayer(player) inventories[player.UserId] = nil end
function InventoryManager.GetInventory(player) return inventories[player.UserId] end

PickupItemEvent.OnServerEvent:Connect(function(player, targetPickup)
	if not player.Character then return end
	local root = player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	if not targetPickup or not targetPickup.Parent then return end
	if not targetPickup:FindFirstChild("IsPickup") then return end
	local itemNameVal = targetPickup:FindFirstChild("ItemName")
	local itemCountVal = targetPickup:FindFirstChild("ItemCount")
	if not itemNameVal or not itemCountVal then return end
	local pickupPos
	if targetPickup:IsA("Model") then
		pickupPos = targetPickup:GetPivot().Position
	elseif targetPickup:IsA("BasePart") then
		pickupPos = targetPickup.Position
	else
		return
	end
	if (root.Position - pickupPos).Magnitude > 10 then return end
	local added = InventoryManager.AddItem(player, itemNameVal.Value, itemCountVal.Value)
	if added > 0 then
		targetPickup:Destroy()
		print(string.format("[PICKUP] %s picked up %s", player.Name, itemNameVal.Value))
	end
end)

return InventoryManager
