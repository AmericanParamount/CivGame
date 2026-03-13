-- CombatClient LocalScript
-- Location: StarterPlayerScripts > CombatClient
-- Click on resource = hit. Click on player = punch. Click with food selected = eat.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Events = ReplicatedStorage:WaitForChild("Events")
local HitResourceEvent = Events:WaitForChild("HitResource")

local HitPlayerEvent = Events:FindFirstChild("HitPlayer")
if not HitPlayerEvent then
	HitPlayerEvent = Instance.new("RemoteEvent")
	HitPlayerEvent.Name = "HitPlayer"
	HitPlayerEvent.Parent = Events
end

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local PUNCH_COOLDOWN = 0.5
local RESOURCE_HIT_COOLDOWN = 0.7
local REACH = 3
local PUNCH_ANIM_ID = "rbxassetid://87194879960974"

local canPunch = true
local isCarrying = false
local lastResourceHitTime = 0
local punchTrack = nil

local SOUNDS = {
	Grunt = "rbxassetid://138102790984424",
	HitWood = "rbxassetid://507863457",
	HitStone = "rbxassetid://507863457",
	HitBush = "rbxassetid://4918775641",
	HitPlayer = "rbxassetid://507863457",
	Eat = "rbxassetid://9114074523",
}

local function loadPunchAnim()
	local character = player.Character; if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid"); if not humanoid then return end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then animator = Instance.new("Animator"); animator.Parent = humanoid end
	local anim = Instance.new("Animation"); anim.AnimationId = PUNCH_ANIM_ID
	punchTrack = animator:LoadAnimation(anim); punchTrack.Priority = Enum.AnimationPriority.Action; punchTrack.Looped = false
end

player.CharacterAdded:Connect(function(character)
	character:WaitForChild("Humanoid"); task.wait(0.5); loadPunchAnim()
end)
if player.Character then task.spawn(function() task.wait(0.5); loadPunchAnim() end) end

local function playPunch() if punchTrack then punchTrack:Play() end end

local function playSound(parent, soundId, volume)
	if not parent or not parent:IsA("BasePart") then return end
	local s = Instance.new("Sound"); s.SoundId = soundId; s.Volume = volume or 0.5; s.Parent = parent
	s:Play(); s.Ended:Connect(function() s:Destroy() end)
	task.delay(3, function() if s.Parent then s:Destroy() end end)
end

local function showDamageHighlight(target)
	local ht = target; local c = target
	for _ = 1, 5 do if not c then break end; if c:FindFirstChild("ResourceType") then ht = c; break end; c = c.Parent end
	local ex = ht:FindFirstChild("HitHighlight"); if ex then ex:Destroy() end
	local h = Instance.new("Highlight"); h.Name = "HitHighlight"
	h.FillColor = Color3.fromRGB(255, 40, 30); h.FillTransparency = 0.5
	h.OutlineColor = Color3.fromRGB(255, 80, 60); h.OutlineTransparency = 0.1; h.Parent = ht
	task.spawn(function()
		task.wait(0.08)
		for i = 1, 6 do if not h.Parent then return end
			h.FillTransparency = 0.5 + (i / 6) * 0.5; h.OutlineTransparency = 0.1 + (i / 6) * 0.9; task.wait(0.03) end
		if h.Parent then h:Destroy() end
	end)
end

local function showPlayerHighlight(target)
	local ht = target; local c = target
	for _ = 1, 5 do if not c then break end; if c:FindFirstChildOfClass("Humanoid") then ht = c; break end; c = c.Parent end
	local ex = ht:FindFirstChild("HitHighlight"); if ex then ex:Destroy() end
	local h = Instance.new("Highlight"); h.Name = "HitHighlight"
	h.FillColor = Color3.fromRGB(220, 20, 20); h.FillTransparency = 0.4
	h.OutlineColor = Color3.fromRGB(255, 50, 40); h.OutlineTransparency = 0.0; h.Parent = ht
	task.spawn(function()
		task.wait(0.1)
		for i = 1, 8 do if not h.Parent then return end
			h.FillTransparency = 0.4 + (i / 8) * 0.6; h.OutlineTransparency = (i / 8); task.wait(0.03) end
		if h.Parent then h:Destroy() end
	end)
end

local function getHitSound(target)
	local c = target
	for _ = 1, 5 do if not c then break end
		local tv = c:FindFirstChild("ResourceType")
		if tv and tv:IsA("StringValue") then
			local t = tv.Value
			if t == "Tree" then return SOUNDS.HitWood end
			if t == "Rock" or t == "IronDeposit" or t == "CopperDeposit" or t == "ClayDeposit" then return SOUNDS.HitStone end
			return SOUNDS.HitBush
		end; c = c.Parent end
	return SOUNDS.HitPlayer
end

local function findResourceRoot(part)
	local c = part; for _ = 1, 5 do if not c then return nil end; if c:FindFirstChild("ResourceType") then return c end; c = c.Parent end; return nil
end

local function findPlayerFromPart(part)
	local c = part; for _ = 1, 5 do if not c then return nil end
		local hum = c:FindFirstChildOfClass("Humanoid")
		if hum then local hp = Players:GetPlayerFromCharacter(c); if hp and hp ~= player then return hp, c end end
		c = c.Parent end; return nil, nil
end

mouse.Button1Down:Connect(function()
	if not canPunch then return end; if isCarrying then return end
	local character = player.Character; if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart"); if not root then return end
	local target = mouse.Target
	local resNode, hitPlayer, hitChar = nil, nil, nil
	if target then
		local dist = (root.Position - target.Position).Magnitude
		if dist <= REACH then
			resNode = findResourceRoot(target)
			if not resNode then hitPlayer, hitChar = findPlayerFromPart(target) end
		end
	end
	if resNode then
		canPunch = false; playPunch()
		local now = tick()
		if now - lastResourceHitTime >= RESOURCE_HIT_COOLDOWN then
			lastResourceHitTime = now; playSound(root, SOUNDS.Grunt, 0.3); showDamageHighlight(target)
			local hs = getHitSound(target)
			local sp = resNode:IsA("Model") and resNode.PrimaryPart or resNode
			if sp and sp:IsA("BasePart") then playSound(sp, hs, 0.6) end
			HitResourceEvent:FireServer(target)
		end
		task.delay(PUNCH_COOLDOWN, function() canPunch = true end)
	elseif hitPlayer and hitChar then
		canPunch = false; playPunch(); playSound(root, SOUNDS.Grunt, 0.3); showPlayerHighlight(target)
		local hr = hitChar:FindFirstChild("HumanoidRootPart")
		if hr then playSound(hr, SOUNDS.HitPlayer, 0.5) end
		HitPlayerEvent:FireServer(hitPlayer)
		task.delay(PUNCH_COOLDOWN, function() canPunch = true end)
	else
		local eatFunc = player:FindFirstChild("TryEatSelected")
		if eatFunc and eatFunc:IsA("BindableFunction") then
			local ate = eatFunc:Invoke()
			if ate then playSound(root, SOUNDS.Eat, 0.4) end
		end
	end
end)

local cb = Instance.new("BindableEvent"); cb.Name = "CombatCarryBinding"; cb.Parent = player
cb.Event:Connect(function(c) isCarrying = c end)

print("[COMBAT] Combat client loaded")
