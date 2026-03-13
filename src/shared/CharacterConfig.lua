-- CharacterConfig ModuleScript
-- Location: ReplicatedStorage > Modules > CharacterConfig
-- All character system constants in one place.
local CharacterConfig = {}
-- === AGING ===
CharacterConfig.Aging = {
	SecondsPerYear = 60,
	StartingAge = 5,
	AdultAge = 16,
	ElderAge = 55,
	MaxAge = 75,
	DeathChanceStart = 60,
	DeathCheckInterval = 60,
	DeathChancePerCheck = 0.05,
	DeathChancePerYear = 0.02,
}
-- === SCALING ===
CharacterConfig.Scaling = {
	ChildScale = 0.35,
	AdultScale = 1.0,
}
-- === HUNGER ===
CharacterConfig.Hunger = {
	MaxHunger = 100,
	StartingHunger = 100,
	DrainPerSecond = 0.05,
	StarvationThreshold = 0,
	StarvationDamagePerSecond = 2,
}
-- === THIRST ===
CharacterConfig.Thirst = {
	Enabled = true,
	MaxThirst = 100,
	StartingThirst = 100,
	DrainPerSecond = 0.08,
	DehydrationThreshold = 0,
	DehydrationDamagePerSecond = 3,
}
-- === HEALTH ===
CharacterConfig.Health = {
	MaxHealth = 100,
	StartingHealth = 100,
	RegenPerSecond = 0.5,
	RegenHungerThreshold = 50,
	RegenThirstThreshold = 50,
}
-- === SPEED MODIFIERS ===
CharacterConfig.Speed = {
	BaseWalkSpeed = 16,
	ChildSpeedMultiplier = 0.6,
	ElderSpeedMultiplier = 0.75,
}
-- === DEATH & RESPAWN ===
CharacterConfig.Death = {
	RespawnDelay = 5,
	RespawnAsChild = true,
	KeepLineage = true,
}
return CharacterConfig
