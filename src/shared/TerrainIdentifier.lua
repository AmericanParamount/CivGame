-- TerrainIdentifier ModuleScript
-- Location: ReplicatedStorage > Modules > TerrainIdentifier

local TerrainIdentifier = {}
local TerrainConfig = require(script.Parent:WaitForChild("TerrainConfig"))

local RAY_HEIGHT = 100
local RAY_DISTANCE = 200
local TILE_SIZE = 32
local FARM_PARCEL_SIZE = 8

local terrainFolder = workspace:WaitForChild("Map")
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Include

local function refreshTerrainFilter()
	raycastParams.FilterDescendantsInstances = {terrainFolder}
end
refreshTerrainFilter()
terrainFolder.DescendantAdded:Connect(function() task.defer(refreshTerrainFilter) end)
terrainFolder.DescendantRemoving:Connect(function() task.defer(refreshTerrainFilter) end)

local function readTerrainType(part)
	local typeValue = part:FindFirstChild("TerrainType")
	if typeValue and typeValue:IsA("StringValue") then return typeValue.Value end
	local parent = part.Parent
	if parent and parent:IsA("Folder") and TerrainConfig.IsValidType(parent.Name) then return parent.Name end
	return nil
end

function TerrainIdentifier.GetTerrainAtPosition(worldPosition)
	local origin = Vector3.new(worldPosition.X, worldPosition.Y + RAY_HEIGHT, worldPosition.Z)
	local direction = Vector3.new(0, -RAY_DISTANCE, 0)
	local result = workspace:Raycast(origin, direction, raycastParams)
	if result and result.Instance then
		local terrainType = readTerrainType(result.Instance)
		return terrainType, result.Instance, result.Position
	end
	return nil, nil, nil
end

function TerrainIdentifier.GetTerrainUnderPlayer(player)
	local character = player.Character; if not character then return nil, nil, nil end
	local root = character:FindFirstChild("HumanoidRootPart"); if not root then return nil, nil, nil end
	return TerrainIdentifier.GetTerrainAtPosition(root.Position)
end

function TerrainIdentifier.GetFullDataAtPosition(worldPosition)
	local terrainType, hitPart, hitPosition = TerrainIdentifier.GetTerrainAtPosition(worldPosition)
	if terrainType then
		local data = TerrainConfig.GetTypeData(terrainType)
		return {
			Type = terrainType, Data = data, Part = hitPart, Position = hitPosition,
			Fertility = data and data.Fertility or 0, CanBuild = data and data.CanBuild or false,
			CanFarm = data and data.CanFarm or false, SpeedMultiplier = data and data.SpeedMultiplier or 1.0,
		}
	end
	return nil
end

function TerrainIdentifier.WorldToTileGrid(worldPosition)
	return math.floor(worldPosition.X / TILE_SIZE), math.floor(worldPosition.Z / TILE_SIZE)
end

function TerrainIdentifier.WorldToFarmParcel(worldPosition)
	return math.floor(worldPosition.X / FARM_PARCEL_SIZE), math.floor(worldPosition.Z / FARM_PARCEL_SIZE)
end

function TerrainIdentifier.FarmParcelToWorld(parcelX, parcelZ)
	local worldX = (parcelX * FARM_PARCEL_SIZE) + (FARM_PARCEL_SIZE / 2)
	local worldZ = (parcelZ * FARM_PARCEL_SIZE) + (FARM_PARCEL_SIZE / 2)
	local _, _, hitPos = TerrainIdentifier.GetTerrainAtPosition(Vector3.new(worldX, 0, worldZ))
	local worldY = hitPos and hitPos.Y or 0
	return Vector3.new(worldX, worldY, worldZ)
end

function TerrainIdentifier.CheckBuildingArea(position, buildingSize, rotation)
	local halfX = buildingSize.X / 2; local halfZ = buildingSize.Z / 2
	local offsets = {
		Vector3.new(0, 0, 0), Vector3.new(halfX, 0, halfZ), Vector3.new(-halfX, 0, halfZ),
		Vector3.new(halfX, 0, -halfZ), Vector3.new(-halfX, 0, -halfZ),
	}
	local rotCF = CFrame.Angles(0, rotation, 0)
	for _, offset in ipairs(offsets) do
		local rotatedOffset = rotCF:VectorToWorldSpace(offset)
		local checkPos = position + rotatedOffset
		local terrainType = TerrainIdentifier.GetTerrainAtPosition(checkPos)
		if not terrainType then return false, "No terrain found" end
		if not TerrainConfig.CanBuildOn(terrainType) then
			local displayName = TerrainConfig.GetProperty(terrainType, "DisplayName", terrainType)
			return false, "Cannot build on " .. displayName
		end
	end
	return true, nil
end

return TerrainIdentifier
