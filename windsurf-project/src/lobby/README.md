# Lobby System - Setup Guide

## 📁 File Structure

```
src/lobby/
├── server/
│   ├── DataStoreManager.lua       - Saves/loads player data
│   ├── PlayerDataManager.lua      - Manages inventory, loadout, gems
│   ├── SummoningSystem.lua        - Gacha mechanics with pity system
│   ├── TeleportManager.lua        - Teleports players to game map
│   └── LobbyServer.lua            - Main server script (connects everything)
├── client/
│   └── LobbyController.client.lua - UI controller for lobby
└── shared/
    └── TowerData.lua              - Tower definitions and rarity rates

```

## 🚀 Setup Instructions

### 1. **In Roblox Studio (Lobby Place):**

#### Create Folder Structure:
1. In **ReplicatedStorage**, create a folder named `Shared`
2. Move `TowerData.lua` into `ReplicatedStorage.Shared`
3. In **ServerScriptService**, create a folder named `Lobby`
4. Move all server scripts into `ServerScriptService.Lobby`
5. In **StarterPlayer.StarterPlayerScripts**, create a folder named `Lobby`
6. Move `LobbyController.client.lua` into `StarterPlayer.StarterPlayerScripts.Lobby`

#### Update TeleportManager:
1. Open `TeleportManager.lua`
2. Find line: `local GAME_MAP_PLACE_ID = 0`
3. Replace `0` with your RockMap's Place ID
   - Get it from: Game Settings → Places → Copy RockMap's Place ID

### 2. **Create UI Elements:**

You'll need to create a ScreenGui named `LobbyGui` in StarterGui with these frames:

#### Required UI Elements:
- **GemsDisplay** (Frame)
  - `GemsAmount` (TextLabel) - Shows gem count
  
- **SummonUI** (Frame)
  - `SingleSummonButton` (TextButton) - Cost: 50 gems
  - `MultiSummonButton` (TextButton) - Cost: 450 gems (10 pulls)
  - `PityCounter` (TextLabel) - Shows pity progress
  - `ResultFrame` (Frame) - Shows summon results
    - `TowerName` (TextLabel)
    - `Rarity` (TextLabel)
    - `Description` (TextLabel)
    
- **InventoryUI** (Frame)
  - `GridFrame` (Frame with UIGridLayout) - Displays owned towers
  
- **LoadoutUI** (Frame)
  - `LoadoutFrame` (Frame with UIListLayout) - Shows 6 loadout slots
  
- **PlayButton** (TextButton) - Teleports to game
- **InventoryButton** (TextButton) - Opens inventory
- **ErrorMessage** (TextLabel) - Shows error messages

## 🎮 How It Works

### **Player Data:**
- **Gems:** Currency for summoning (starts with 500)
- **Inventory:** All towers the player owns
- **Loadout:** Up to 6 towers to bring into game
- **Pity System:** Guaranteed legendary every 50 summons

### **Summoning:**
- **Single Summon:** 50 gems, 1 tower
- **Multi Summon:** 450 gems, 10 towers (10% discount)

### **Rarity Rates:**
- Common: 70%
- Rare: 20%
- Epic: 8%
- Legendary: 2% (guaranteed at 50 pity)

### **Tower Examples:**
The system comes with 8 example towers:
- 2 Common (Archer, Warrior)
- 2 Rare (Mage, Sniper)
- 2 Epic (Ninja, Summoner)
- 2 Legendary (Dragon Knight, Celestial)

**To add more towers:** Edit `TowerData.lua` and add to the `Towers` table.

## 🔧 Customization

### Change Summon Costs:
Edit `SummoningSystem.lua`:
```lua
local SINGLE_SUMMON_COST = 50
local MULTI_SUMMON_COST = 450
```

### Change Rarity Rates:
Edit `TowerData.lua` in the `Rarities` table:
```lua
Common = { PullRate = 0.70 } -- 70%
```

### Change Pity System:
Edit `TowerData.lua`:
```lua
Legendary = { PityRequired = 50 } -- Guaranteed at 50 summons
```

### Change Starting Gems:
Edit `DataStoreManager.lua`:
```lua
Gems = 500, -- Starting gems
```

## 📊 Data Persistence

Player data is automatically saved when they leave and loaded when they join:
- Gems
- Inventory (all owned towers)
- Loadout (selected towers)
- Summon history and pity counter

## 🎯 Next Steps

1. Create the UI elements in StarterGui
2. Update the RockMap Place ID in TeleportManager
3. Add your actual tower models to match the TowerData definitions
4. Test summoning and inventory systems
5. Build the lobby map/environment

## 💡 Tips

- Test in a local server to see multiplayer data persistence
- Use the Output window to see debug messages
- DataStore only works in published games (use Studio's "Enable Studio Access to API Services")
- You can give yourself gems for testing by modifying the starting amount
