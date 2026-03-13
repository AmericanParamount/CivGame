-- AppearanceSystem_Server Script
-- Location: ServerScriptService > AppearanceSystem_Server

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local AppearanceConfig = require(Modules:WaitForChild("AppearanceConfig"))

local playerAppearances = {}
local TORSO_COLOR = Color3.fromRGB(30, 50, 90)
local FALLBACK_FACE = "rbxasset://textures/face.png"

local function ensureFolders()
	local hairFolder = ServerStorage:FindFirstChild("HairModels")
	if not hairFolder then
		hairFolder = Instance.new("Folder"); hairFolder.Name = "HairModels"; hairFolder.Parent = ServerStorage
		Instance.new("Folder", hairFolder).Name = "Male"
		Instance.new("Folder", hairFolder).Name = "Female"
	end; return hairFolder
end
local hairModelsFolder = ensureFolders()

local function applySkinTone(character, skinTone)
	for _, partName in ipairs({"Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}) do
		local part = character:FindFirstChild(partName)
		if part and part:IsA("BasePart") then part.Color = skinTone end
	end
	local torso = character:FindFirstChild("Torso"); if torso then torso.Color = TORSO_COLOR end
	local bc = character:FindFirstChildOfClass("BodyColors")
	if bc then
		bc.HeadColor3 = skinTone; bc.TorsoColor3 = TORSO_COLOR
		bc.LeftArmColor3 = skinTone; bc.RightArmColor3 = skinTone
		bc.LeftLegColor3 = skinTone; bc.RightLegColor3 = skinTone
	end
end

local function applyFace(character, faceId)
	local head = character:FindFirstChild("Head"); if not head then return end
	for _, child in ipairs(head:GetChildren()) do
		if child:IsA("Decal") and (child.Name == "face" or child.Name == "Face") then child:Destroy() end
	end
	local newFace = Instance.new("Decal"); newFace.Name = "face"
	newFace.Face = Enum.NormalId.Front; newFace.Texture = faceId or FALLBACK_FACE; newFace.Parent = head
end

local function applyHair(character, gender, hairStyle, hairColor)
	local head = character:FindFirstChild("Head"); if not head then return end
	for _, child in ipairs(head:GetChildren()) do if child.Name == "Hair" then child:Destroy() end end
	if hairStyle == "Bald" then return end
	local genderFolder = hairModelsFolder:FindFirstChild(gender); if not genderFolder then return end
	local hairTemplate = genderFolder:FindFirstChild(hairStyle); if not hairTemplate then return end
	local hair = hairTemplate:Clone(); hair.Name = "Hair"
	for _, part in ipairs(hair:GetDescendants()) do
		if part:IsA("BasePart") then part.Color = hairColor; part.Anchored = false; part.CanCollide = false end
	end
	if hair:IsA("Model") and hair.PrimaryPart then
		hair:PivotTo(head.CFrame * CFrame.new(0, head.Size.Y / 2, 0))
		local weld = Instance.new("WeldConstraint"); weld.Part0 = head; weld.Part1 = hair.PrimaryPart; weld.Parent = hair.PrimaryPart
	elseif hair:IsA("BasePart") then
		hair.Position = head.Position + Vector3.new(0, head.Size.Y / 2, 0)
		local weld = Instance.new("WeldConstraint"); weld.Part0 = head; weld.Part1 = hair; weld.Parent = hair
	end
	hair.Parent = head
end

local function stripDefaultAppearance(character)
	for _, item in ipairs(character:GetChildren()) do
		if item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") or item:IsA("Accessory") or item:IsA("CharacterMesh") then item:Destroy() end
	end
	local head = character:FindFirstChild("Head")
	if head then
		for _, child in ipairs(head:GetChildren()) do
			if child:IsA("Decal") and (child.Name == "face" or child.Name == "Face") then child:Destroy() end
			if child:IsA("SpecialMesh") then child:Destroy() end
		end
		local defaultMesh = Instance.new("SpecialMesh")
		defaultMesh.MeshType = Enum.MeshType.Head; defaultMesh.Scale = Vector3.new(1.25, 1.25, 1.25); defaultMesh.Parent = head
	end
end

local function applyFullAppearance(player, appearance)
	local character = player.Character; if not character then return end
	if not player:HasAppearanceLoaded() then player.CharacterAppearanceLoaded:Wait() end
	character:WaitForChild("Head"); character:WaitForChild("Torso"); character:WaitForChild("Humanoid")
	task.wait(0.5)
	stripDefaultAppearance(character)
	applySkinTone(character, appearance.SkinTone)
	applyFace(character, appearance.FaceId)
	applyHair(character, appearance.Gender, appearance.HairStyle, appearance.HairColor)
	local existingTag = character:FindFirstChild("LineageTag"); if existingTag then existingTag:Destroy() end
	local billboard = Instance.new("BillboardGui"); billboard.Name = "LineageTag"
	local currentScale = 1
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local scaleValue = humanoid:FindFirstChild("BodyHeightScale")
		if scaleValue and scaleValue:IsA("NumberValue") then
			currentScale = scaleValue.Value
		end
	end
	billboard.Size = UDim2.new(0, 200, 0, 50); billboard.StudsOffset = Vector3.new(0, 2.5 / currentScale, 0)
	billboard.AlwaysOnTop = false; billboard.MaxDistance = 50; billboard.Parent = character.Head
	local nameLabel = Instance.new("TextLabel"); nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
	nameLabel.BackgroundTransparency = 1; nameLabel.Text = player.DisplayName
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255); nameLabel.TextStrokeTransparency = 0.5
	nameLabel.TextSize = 14; nameLabel.Font = Enum.Font.GothamBold; nameLabel.Parent = billboard
	local lineageLabel = Instance.new("TextLabel"); lineageLabel.Size = UDim2.new(1, 0, 0.5, 0)
	lineageLabel.Position = UDim2.new(0, 0, 0.5, 0); lineageLabel.BackgroundTransparency = 1
	lineageLabel.Text = appearance.Lineage .. " · " .. appearance.Race
	lineageLabel.TextColor3 = Color3.fromRGB(200, 190, 170); lineageLabel.TextStrokeTransparency = 0.7
	lineageLabel.TextSize = 11; lineageLabel.Font = Enum.Font.Gotham; lineageLabel.Parent = billboard
	print(string.format("[APPEARANCE] %s | Race: %s | Lineage: %s | Gender: %s | Hair: %s", player.Name, appearance.Race, appearance.Lineage, appearance.Gender, appearance.HairStyle))
end

local function getOrCreateAppearance(player)
	local raceNames = AppearanceConfig.GetRaceNames()
	local randomRace = raceNames[math.random(1, #raceNames)]
	local appearance = AppearanceConfig.GenerateRandomAppearance(randomRace)
	playerAppearances[player.UserId] = appearance; return appearance
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function() applyFullAppearance(player, getOrCreateAppearance(player)) end)
end)

Players.PlayerRemoving:Connect(function(player)
	task.delay(60, function() if not Players:FindFirstChild(player.Name) then playerAppearances[player.UserId] = nil end end)
end)

local GetAppearanceFunction = Instance.new("BindableFunction"); GetAppearanceFunction.Name = "GetPlayerAppearance"
GetAppearanceFunction.OnInvoke = function(player) return playerAppearances[player.UserId] end
GetAppearanceFunction.Parent = ReplicatedStorage:WaitForChild("Events")

for _, player in ipairs(Players:GetPlayers()) do
	if player.Character then applyFullAppearance(player, getOrCreateAppearance(player)) end
	player.CharacterAdded:Connect(function() applyFullAppearance(player, getOrCreateAppearance(player)) end)
end

print("Appearance system loaded — " .. tostring(#AppearanceConfig.GetRaceNames()) .. " races registered")
