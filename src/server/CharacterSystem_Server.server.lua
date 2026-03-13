-- CharacterSystem_Server Script
-- Location: ServerScriptService > CharacterSystem_Server
-- Simulates aging, hunger, thirst, health, scaling, and death for all players.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local CharacterConfig = require(Modules:WaitForChild("CharacterConfig"))
local TerrainIdentifier = require(Modules:WaitForChild("TerrainIdentifier"))
local TerrainConfig = require(Modules:WaitForChild("TerrainConfig"))

local Events = ReplicatedStorage:WaitForChild("Events")

local StatsUpdateEvent = Events:FindFirstChild("StatsUpdate")
if not StatsUpdateEvent then
	StatsUpdateEvent = Instance.new("RemoteEvent")
	StatsUpdateEvent.Name = "StatsUpdate"
	StatsUpdateEvent.Parent = Events
end

local playerData = {}

local function initPlayerData(player, keepLineage)
	local existing = playerData[player.UserId]
	local lineage = (keepLineage and existing) and existing.Lineage or "Unknown"
	playerData[player.UserId] = {
		Player = player, Age = CharacterConfig.Aging.StartingAge, AgeTimer = 0,
		Health = CharacterConfig.Health.StartingHealth, MaxHealth = CharacterConfig.Health.MaxHealth,
		Hunger = CharacterConfig.Hunger.StartingHunger, MaxHunger = CharacterConfig.Hunger.MaxHunger,
		Thirst = CharacterConfig.Thirst.StartingThirst, MaxThirst = CharacterConfig.Thirst.MaxThirst,
		Alive = true, Lineage = lineage, DeathCheckTimer = 0,
	}
	return playerData[player.UserId]
end

local function applyScale(player, age)
	local character = player.Character; if not character then return end
	local agingConfig = CharacterConfig.Aging
	local scalingConfig = CharacterConfig.Scaling
	local scale
	if age >= agingConfig.AdultAge then scale = scalingConfig.AdultScale
	elseif age <= agingConfig.StartingAge then scale = scalingConfig.ChildScale
	else
		local progress = (age - agingConfig.StartingAge) / (agingConfig.AdultAge - agingConfig.StartingAge)
		scale = scalingConfig.ChildScale + (scalingConfig.AdultScale - scalingConfig.ChildScale) * progress
	end
	character:ScaleTo(scale)
end

local function applySpeed(player, data)
	local character = player.Character; if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid"); if not humanoid then return end
	local speedConfig = CharacterConfig.Speed
	local speed = speedConfig.BaseWalkSpeed
	if data.Age < CharacterConfig.Aging.AdultAge then speed = speed * speedConfig.ChildSpeedMultiplier
	elseif data.Age >= CharacterConfig.Aging.ElderAge then speed = speed * speedConfig.ElderSpeedMultiplier end
	local terrainType = TerrainIdentifier.GetTerrainUnderPlayer(player)
	if terrainType then speed = speed * TerrainConfig.GetSpeed(terrainType) end
	humanoid.WalkSpeed = speed
end

local function checkOldAgeDeath(data)
	if data.Age < CharacterConfig.Aging.DeathChanceStart then return false end
	if data.Age >= CharacterConfig.Aging.MaxAge then return true end
	local yearsOver = data.Age - CharacterConfig.Aging.DeathChanceStart
	local deathChance = CharacterConfig.Aging.DeathChancePerCheck + (yearsOver * CharacterConfig.Aging.DeathChancePerYear)
	return math.random() < deathChance
end

local function killPlayer(player, data, cause)
	if not data.Alive then return end
	data.Alive = false
	print(string.format("[DEATH] %s died at age %d (%s)", player.Name, math.floor(data.Age), cause))
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid.Health = 0 end
	end
	task.delay(CharacterConfig.Death.RespawnDelay, function()
		if player.Parent then
			initPlayerData(player, CharacterConfig.Death.KeepLineage)
			player:LoadCharacter()
		end
	end)
end

local function feedPlayer(player, amount)
	local data = playerData[player.UserId]; if not data or not data.Alive then return end
	data.Hunger = math.min(data.Hunger + amount, data.MaxHunger)
end

local function hydratePlayer(player, amount)
	local data = playerData[player.UserId]; if not data or not data.Alive then return end
	data.Thirst = math.min(data.Thirst + amount, data.MaxThirst)
end

local function healPlayer(player, amount)
	local data = playerData[player.UserId]; if not data or not data.Alive then return end
	data.Health = math.min(data.Health + amount, data.MaxHealth)
end

local function damagePlayer(player, amount, source)
	local data = playerData[player.UserId]; if not data or not data.Alive then return end
	data.Health = math.max(data.Health - amount, 0)
	if data.Health <= 0 then killPlayer(player, data, source or "damage") end
end

local UPDATE_INTERVAL = 1
local accumulator = 0

RunService.Heartbeat:Connect(function(dt)
	accumulator = accumulator + dt
	if accumulator < UPDATE_INTERVAL then return end
	accumulator = accumulator - UPDATE_INTERVAL
	for userId, data in pairs(playerData) do
		if not data.Alive then continue end
		local player = data.Player
		if not player.Parent then playerData[userId] = nil; continue end
		local character = player.Character
		if not character or not character:FindFirstChildOfClass("Humanoid") then continue end
		data.AgeTimer = data.AgeTimer + UPDATE_INTERVAL
		if data.AgeTimer >= CharacterConfig.Aging.SecondsPerYear then
			data.AgeTimer = data.AgeTimer - CharacterConfig.Aging.SecondsPerYear
			data.Age = data.Age + 1; applyScale(player, data.Age)
			if data.Age % 10 == 0 then print(string.format("[AGE] %s is now %d years old", player.Name, data.Age)) end
		end
		data.Hunger = math.max(data.Hunger - (CharacterConfig.Hunger.DrainPerSecond * UPDATE_INTERVAL), 0)
		if CharacterConfig.Thirst.Enabled then
			data.Thirst = math.max(data.Thirst - (CharacterConfig.Thirst.DrainPerSecond * UPDATE_INTERVAL), 0)
		end
		if data.Hunger <= CharacterConfig.Hunger.StarvationThreshold then
			data.Health = math.max(data.Health - (CharacterConfig.Hunger.StarvationDamagePerSecond * UPDATE_INTERVAL), 0)
			if data.Health <= 0 then killPlayer(player, data, "starvation"); continue end
		end
		if CharacterConfig.Thirst.Enabled and data.Thirst <= CharacterConfig.Thirst.DehydrationThreshold then
			data.Health = math.max(data.Health - (CharacterConfig.Thirst.DehydrationDamagePerSecond * UPDATE_INTERVAL), 0)
			if data.Health <= 0 then killPlayer(player, data, "dehydration"); continue end
		end
		local canRegen = data.Hunger > CharacterConfig.Health.RegenHungerThreshold
		if CharacterConfig.Thirst.Enabled then canRegen = canRegen and data.Thirst > CharacterConfig.Health.RegenThirstThreshold end
		if canRegen and data.Health < data.MaxHealth then
			data.Health = math.min(data.Health + (CharacterConfig.Health.RegenPerSecond * UPDATE_INTERVAL), data.MaxHealth)
		end
		data.DeathCheckTimer = data.DeathCheckTimer + UPDATE_INTERVAL
		if data.DeathCheckTimer >= CharacterConfig.Aging.DeathCheckInterval then
			data.DeathCheckTimer = 0
			if checkOldAgeDeath(data) then killPlayer(player, data, "old age"); continue end
		end
		applySpeed(player, data)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid.MaxHealth = data.MaxHealth; humanoid.Health = data.Health end
		local statsPayload = {
			Age = math.floor(data.Age), Health = math.floor(data.Health), MaxHealth = data.MaxHealth,
			Hunger = math.floor(data.Hunger), MaxHunger = data.MaxHunger, Lineage = data.Lineage,
		}
		if CharacterConfig.Thirst.Enabled then
			statsPayload.Thirst = math.floor(data.Thirst); statsPayload.MaxThirst = data.MaxThirst
		end
		StatsUpdateEvent:FireClient(player, statsPayload)
	end
end)

Players.PlayerAdded:Connect(function(player)
	initPlayerData(player, false)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		local data = playerData[player.UserId]
		if data then applyScale(player, data.Age) end
		humanoid.Died:Connect(function()
			local data = playerData[player.UserId]
			if data and data.Alive then killPlayer(player, data, "accident") end
		end)
	end)
end)

Players.PlayerRemoving:Connect(function(player) playerData[player.UserId] = nil end)

local FeedFunction = Instance.new("BindableFunction"); FeedFunction.Name = "FeedPlayer"
FeedFunction.OnInvoke = function(player, amount) feedPlayer(player, amount); return true end
FeedFunction.Parent = Events

local HydrateFunction = Instance.new("BindableFunction"); HydrateFunction.Name = "HydratePlayer"
HydrateFunction.OnInvoke = function(player, amount) hydratePlayer(player, amount); return true end
HydrateFunction.Parent = Events

local DamageFunction = Instance.new("BindableFunction"); DamageFunction.Name = "DamagePlayer"
DamageFunction.OnInvoke = function(player, amount, source) damagePlayer(player, amount, source); return true end
DamageFunction.Parent = Events

local HealFunction = Instance.new("BindableFunction"); HealFunction.Name = "HealPlayer"
HealFunction.OnInvoke = function(player, amount) healPlayer(player, amount); return true end
HealFunction.Parent = Events

print("Character system loaded")
