# Civilization Era — Rojo Project

## Structure
```
src/
  server/                          → ServerScriptService
    ResourceSystem_Server.server.lua
    BuildingPlacement_Server.server.lua
    CharacterSystem_Server.server.lua
    CarrySystem_Server.server.lua
    AppearanceSystem_Server.server.lua
    Modules/                       → ServerScriptService > Modules
      InventoryManager.lua
  client/                          → StarterPlayer > StarterPlayerScripts
    BuildingPlacement_Client.client.lua
    InventoryClient.client.lua
    CarryClient.client.lua
    CombatClient.client.lua
    CharacterHUD.client.lua
  shared/                          → ReplicatedStorage > Modules
    BuildingConfig.lua
    ItemConfig.lua
    TerrainConfig.lua
    TerrainIdentifier.lua
    CharacterConfig.lua
    AppearanceConfig.lua
```

## Naming Convention
- `.server.lua` = Script (runs on server)
- `.client.lua` = LocalScript (runs on client)
- `.lua` = ModuleScript (shared/required)

## Usage
1. Install Rojo CLI
2. `rojo serve` from this folder
3. Connect via Rojo plugin in Studio
4. Edits to files sync to Studio automatically

## Non-Script Assets (remain in Studio)
- ReplicatedStorage > Models > Buildings/ (building templates)
- ReplicatedStorage > Models > Saplings/ (sapling templates)
- ServerStorage > CarryModels/ (carry item models)
- ServerStorage > ResourceModels/ (tree/rock templates)
- ServerStorage > ResourceRemnants/ (stump models)
- ServerStorage > HairModels/ (Male/, Female/)
- Workspace > Map/ (terrain tiles with TerrainType StringValues)
- Workspace > Water/ (water BaseParts)
- Workspace > Resources/ (resource nodes)
- ReplicatedStorage > Events/ (auto-created by scripts)
