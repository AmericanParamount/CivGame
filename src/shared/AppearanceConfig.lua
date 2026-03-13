-- AppearanceConfig ModuleScript
-- Location: ReplicatedStorage > Modules > AppearanceConfig

local AppearanceConfig = {}

AppearanceConfig.Genders = {"Male", "Female"}

AppearanceConfig.Races = {
	Nord = {
		DisplayName = "Nord", Description = "Pale-skinned northern people of the forests and highlands",
		FaceId = "rbxassetid://45515545",
		SkinTones = { Color3.fromRGB(235,215,200), Color3.fromRGB(225,205,188), Color3.fromRGB(240,222,208), Color3.fromRGB(218,198,180) },
		HairColors = { Color3.fromRGB(220,200,160), Color3.fromRGB(180,140,90), Color3.fromRGB(200,60,30), Color3.fromRGB(235,220,190), Color3.fromRGB(55,35,18) },
		EyeColors = { Color3.fromRGB(80,130,180), Color3.fromRGB(90,160,120), Color3.fromRGB(120,140,160) },
		Lineages = {"Brenn", "Aldric", "Korva", "Thane", "Halvard"},
	},
	Sino = {
		DisplayName = "Sino", Description = "Olive-skinned coastal builders and traders",
		FaceId = "rbxassetid://15637705",
		SkinTones = { Color3.fromRGB(195,168,130), Color3.fromRGB(185,158,120), Color3.fromRGB(205,178,140), Color3.fromRGB(175,148,110) },
		HairColors = { Color3.fromRGB(20,15,10), Color3.fromRGB(35,25,15), Color3.fromRGB(55,38,22), Color3.fromRGB(45,30,18) },
		EyeColors = { Color3.fromRGB(65,45,25), Color3.fromRGB(85,60,30), Color3.fromRGB(50,35,18) },
		Lineages = {"Pelas", "Maren", "Thalo", "Keras", "Solai"},
	},
	Kush = {
		DisplayName = "Kush", Description = "Dark-skinned river kingdom people",
		FaceId = "rbxassetid://110287880",
		SkinTones = { Color3.fromRGB(120,80,52), Color3.fromRGB(105,68,42), Color3.fromRGB(90,58,35), Color3.fromRGB(135,92,62) },
		HairColors = { Color3.fromRGB(15,10,8), Color3.fromRGB(25,18,12), Color3.fromRGB(35,22,14) },
		EyeColors = { Color3.fromRGB(55,35,18), Color3.fromRGB(40,25,12), Color3.fromRGB(75,50,28) },
		Lineages = {"Shabari", "Merukai", "Tahar", "Dakari", "Zendri"},
	},
	Grundal = {
		DisplayName = "Grundal", Description = "Stocky, primal cave and mountain dwellers",
		FaceId = "rbxassetid://478720454",
		SkinTones = { Color3.fromRGB(185,162,135), Color3.fromRGB(175,150,122), Color3.fromRGB(195,172,145), Color3.fromRGB(165,140,112) },
		HairColors = { Color3.fromRGB(70,50,28), Color3.fromRGB(90,65,35), Color3.fromRGB(45,30,15), Color3.fromRGB(110,80,45), Color3.fromRGB(55,38,20) },
		EyeColors = { Color3.fromRGB(95,80,45), Color3.fromRGB(70,60,35), Color3.fromRGB(110,90,50) },
		Lineages = {"Borruk", "Thrand", "Skaldi", "Grohmak", "Uldren"},
	},
}

AppearanceConfig.HairStyles = {
	Male = {"ShortMessy","ShortClean","MediumShaggy","LongStraight","Buzzcut","Mohawk","TiedBack","Bald"},
	Female = {"LongStraight","LongWavy","ShortBob","Braided","BunUp","MediumCurly","PonyTail","ShortMessy"},
}

local function randomChoice(tbl) return tbl[math.random(1, #tbl)] end

function AppearanceConfig.GetRaceNames()
	local names = {}; for name in pairs(AppearanceConfig.Races) do table.insert(names, name) end
	table.sort(names); return names
end

function AppearanceConfig.GetRace(raceName) return AppearanceConfig.Races[raceName] end

function AppearanceConfig.GetRaceByLineage(lineageName)
	for raceName, raceData in pairs(AppearanceConfig.Races) do
		for _, lineage in ipairs(raceData.Lineages) do if lineage == lineageName then return raceName end end
	end; return nil
end

function AppearanceConfig.GetAllLineages()
	local lineages = {}
	for _, raceData in pairs(AppearanceConfig.Races) do
		for _, lineage in ipairs(raceData.Lineages) do table.insert(lineages, lineage) end
	end; return lineages
end

function AppearanceConfig.GenerateRandomAppearance(raceName)
	local race = AppearanceConfig.Races[raceName]; if not race then return nil end
	local gender = randomChoice(AppearanceConfig.Genders)
	return {
		Race = raceName, Gender = gender, Lineage = randomChoice(race.Lineages),
		SkinTone = randomChoice(race.SkinTones), HairColor = randomChoice(race.HairColors),
		HairStyle = randomChoice(AppearanceConfig.HairStyles[gender]),
		EyeColor = randomChoice(race.EyeColors), FaceId = race.FaceId,
	}
end

function AppearanceConfig.GenerateChildAppearance(parentAppearance)
	local race = AppearanceConfig.Races[parentAppearance.Race]
	if not race then return AppearanceConfig.GenerateRandomAppearance(AppearanceConfig.GetRaceNames()[1]) end
	local gender = randomChoice(AppearanceConfig.Genders)
	local skinTone = math.random() < 0.7 and parentAppearance.SkinTone or randomChoice(race.SkinTones)
	local hairColor = math.random() < 0.6 and parentAppearance.HairColor or randomChoice(race.HairColors)
	local eyeColor = math.random() < 0.65 and parentAppearance.EyeColor or randomChoice(race.EyeColors)
	return {
		Race = parentAppearance.Race, Gender = gender, Lineage = parentAppearance.Lineage,
		SkinTone = skinTone, HairColor = hairColor,
		HairStyle = randomChoice(AppearanceConfig.HairStyles[gender]),
		EyeColor = eyeColor, FaceId = race.FaceId,
	}
end

return AppearanceConfig
