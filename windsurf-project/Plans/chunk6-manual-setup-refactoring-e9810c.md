# Chunk 6: Manual Setup & Code Refactoring Guide

Comprehensive list of all RemoteEvents, RemoteFunctions, Folders, and GUI elements currently created by scripts that can be manually set up in Roblox Studio to clean up the codebase.

---

## Table of Contents
1. [ReplicatedStorage Structure](#1-replicatedstorage-structure)
2. [RemoteFunctions (Lobby)](#2-remotefunctions-lobby)
3. [RemoteFunctions (Maps/Game)](#3-remotefunctions-mapsgame)
4. [RemoteEvents](#4-remoteevents)
5. [GUI Elements (Lobby)](#5-gui-elements-lobby)
6. [GUI Elements (Maps/Game)](#6-gui-elements-mapsgame)
7. [Workspace Folders](#7-workspace-folders)
8. [Player Value Objects](#8-player-value-objects)
9. [Refactoring Checklist](#9-refactoring-checklist)

---

## 1. ReplicatedStorage Structure

### Folders to Create Manually

| Folder Path | Purpose | Currently Created In |
|-------------|---------|---------------------|
| `ReplicatedStorage/Events` | Container for all RemoteEvents | `LobbyServer.lua:41-46`, `PartyService.lua:38-43` |
| `ReplicatedStorage/Functions` | Container for all RemoteFunctions | `LobbyServer.lua:48-53`, `TeleportManager.lua:186-191` |
| `ReplicatedStorage/Shared` | Shared modules (Lobby) | Manual |
| `ReplicatedStorage/Modules` | Shared modules (Maps) | Manual |
| `ReplicatedStorage/Towers` | Tower model templates | Manual |

### How to Create in Studio
1. In Explorer, right-click `ReplicatedStorage`
2. Select **Insert Object → Folder**
3. Rename to `Events`, `Functions`, `Shared`, `Modules`, or `Towers`

---

## 2. RemoteFunctions (Lobby)

These are created in `LobbyServer.lua` and `PartyService.lua`. Create them manually in `ReplicatedStorage/Functions`.

| Name | Purpose | Script Location | Line |
|------|---------|-----------------|------|
| `SingleSummon` | Single gacha summon | `LobbyServer.lua` | 56-58 |
| `MultiSummon` | 10x gacha summon | `LobbyServer.lua` | 60-62 |
| `GetInventory` | Get player's tower inventory | `LobbyServer.lua` | 65-67 |
| `GetLoadout` | Get player's equipped loadout | `LobbyServer.lua` | 69-71 |
| `AddToLoadout` | Add tower to loadout slot | `LobbyServer.lua` | 73-75 |
| `RemoveFromLoadout` | Remove tower from loadout | `LobbyServer.lua` | 77-79 |
| `SetLoadoutSlot` | Set specific loadout slot | `LobbyServer.lua` | 81-83 |
| `TeleportToGame` | Teleport solo player to map | `TeleportManager.lua` | 193-195 |
| `TeleportParty` | Teleport party to map | `PartyService.lua` | 62-67 |
| `GetPartyInfo` | Get current party information | `PartyService.lua` | 46-51 |
| `LeaveParty` | Leave current party/PlayBox | `PartyService.lua` | 69-75 |
| `GetPartyMaps` | Get party-restricted maps | `PartyService.lua` | 845-849 |
| `GetPartyActs` | Get party-restricted acts | `PartyService.lua` | 862-867 |

### How to Create RemoteFunctions
1. In Explorer, right-click `ReplicatedStorage/Functions`
2. Select **Insert Object → RemoteFunction**
3. Rename to the exact name from the table above
4. **Important**: Names must match EXACTLY (case-sensitive)

---

## 3. RemoteFunctions (Maps/Game)

These are created in `Tower.lua` and `GameManager.lua`. Create them in `ReplicatedStorage/Functions`.

| Name | Purpose | Script Location | Line |
|------|---------|-----------------|------|
| `RequestTower` | Check if tower can be placed | `Tower.lua` | 10 (waited) |
| `ChangeTowerPriority` | Change tower targeting mode | `Tower.lua` | 11 (waited) |
| `SpawnTower` | Spawn tower at location | `Tower.lua` | 12 (waited) |
| `SellTower` | Sell placed tower | `Tower.lua` | 14 (waited) |
| `UpgradeTower` | Upgrade tower path | `Tower.lua` | 1238-1243 |
| `GetUpgradeCost` | Get upgrade cost for UI | `Tower.lua` | 1247-1252 |
| `UpgradeToParagon` | Upgrade tower to paragon | `Tower.lua` | 1256-1261 |
| `GetUpgradeStats` | Get upgrade stat preview | `Tower.lua` | 1265-1270 |
| `GetParagonData` | Get paragon data for UI | `Tower.lua` | 1274-1279 |
| `GetPathColor` | Get upgrade path color | `Tower.lua` | 1283-1288 |
| `ResetGame` | Reset game for retry | `GameManager.lua` | 37 |
| `SkipWave` | Skip to next wave | `GameManager.lua` | 39 |
| `ToggleSpeed` | Toggle game speed | `GameManager.lua` | 40 |

---

## 4. RemoteEvents

Create these in `ReplicatedStorage/Events`.

| Name | Purpose | Script Location | Line |
|------|---------|-----------------|------|
| `AnimateTower` | Trigger tower attack animation | `Tower.lua` | 13 (waited) |
| `DamageIndicator` | Show damage numbers on mob | `Tower.lua` | 17-22 |
| `PlayerKill` | Notify player of kill | `Tower.lua` | 26-31 |
| `PlayerDamage` | Track player damage dealt | `Tower.lua` | 35-40 |
| `StartGame` | Start game from lobby | `GameManager.lua` | 38 |
| `AwardVictoryRewards` | Award gems on victory | `GameManager.lua` | 36 |
| `SpeedChanged` | Notify speed change to clients | `GameManager.lua` | 41 |
| `NextAct` | Advance to next act | `Main.lua` | 159 (waited) |
| `PartyUpdated` | Real-time party updates | `PartyService.lua` | 54-58 |

### How to Create RemoteEvents
1. In Explorer, right-click `ReplicatedStorage/Events`
2. Select **Insert Object → RemoteEvent**
3. Rename to the exact name from the table above

---

## 5. GUI Elements (Lobby)

These GUI elements are expected by `LobbyController.client.lua`. Create them in `StarterGui/LobbyGui`.

### Main ScreenGui: `LobbyGui`
Create a ScreenGui named `LobbyGui` in `StarterGui`.

### Required Frames/Elements

| Element Name | Type | Parent | Purpose |
|--------------|------|--------|---------|
| `SummonUI` | Frame | LobbyGui | Gacha summoning interface |
| `SingleSummonButton` | TextButton | SummonUI | Single summon trigger |
| `MultiSummonButton` | TextButton | SummonUI | 10x summon trigger |
| `PityCounter` | TextLabel | SummonUI | Shows pity progress |
| `CloseButton` | TextButton | SummonUI | Close summon UI |
| `ResultFrame` | Frame | LobbyGui | Summon result display |
| `ViewportFrame` | ViewportFrame | ResultFrame | 3D tower preview |
| `TowerName` | TextLabel | ResultFrame | Tower name display |
| `Rarity` | TextLabel | ResultFrame | Rarity display |
| `Description` | TextLabel | ResultFrame | Tower description |
| `InventoryUI` | Frame | LobbyGui | Tower inventory display |
| `GridFrame` | Frame/ScrollingFrame | InventoryUI | Grid of tower slots |
| `Template` | Frame | GridFrame | Template slot (set Visible=false) |
| `LoadoutUI` | Frame | LobbyGui | Equipped towers display |
| `Template` | Frame | LoadoutUI | Filled slot template |
| `EmptyTemplate` | Frame | LoadoutUI | Empty slot template |
| `Slot1-6` | Frame | LoadoutUI | Individual loadout slots |
| `Swap` | TextButton | Each Slot | Swap button (hidden by default) |
| `GemsDisplay` | Frame | LobbyGui | Currency display |
| `GemsAmount` | TextLabel | GemsDisplay | Gem count |
| `PlayButton` | Frame | LobbyGui | Main play button |
| `Button` | TextButton | PlayButton | Clickable button |
| `Buttons` | Frame | LobbyGui | Container for nav buttons |
| `InventoryButton` | Frame | Buttons | Open inventory |
| `SummonButton` | Frame | Buttons | Open summon UI |
| `ErrorMessage` | TextLabel | LobbyGui | Error display (Visible=false) |
| `MapSelectorUI` | Frame | LobbyGui | Map selection interface |
| `MapListFrame` | ScrollingFrame | MapSelectorUI | List of maps |
| `Template` | Frame | MapListFrame | Unlocked map template |
| `LockedTemplate` | Frame | MapListFrame | Locked map template |
| `ActFrame` | Frame | MapSelectorUI | Act selection |
| `ActListFrame` | ScrollingFrame | ActFrame | List of acts |
| `MapDetailsFrame` | Frame | MapSelectorUI | Selected map details |
| `PlayButton` | Frame | MapSelectorUI | Start game button |
| `CloseButton` | TextButton | MapSelectorUI | Close map selector |

### How to Create GUI in Studio
1. In Explorer, right-click `StarterGui`
2. Select **Insert Object → ScreenGui**
3. Rename to `LobbyGui`
4. Right-click `LobbyGui` → **Insert Object → Frame** for each frame
5. Add child elements (TextLabel, TextButton, ImageLabel, ViewportFrame)
6. Set `Template` elements to `Visible = false`

### Template Slot Structure (Inventory/Loadout)
```
Template (Frame)
├── ViewportFrame (ViewportFrame)
│   └── WorldModel (WorldModel)
├── Name (TextLabel)
├── Price (TextLabel) [optional]
└── SelectionHighlight (UIStroke) [created dynamically]
```

---

## 6. GUI Elements (Maps/Game)

These are expected by `GameController.client.lua`. Create in `StarterGui`.

### Main ScreenGui (Maps)
The script references `script.Parent` which should be a ScreenGui.

| Element Name | Type | Parent | Purpose |
|--------------|------|--------|---------|
| `LoadoutFrame` | Frame | ScreenGui | In-game tower selection |
| `Template` | Frame | LoadoutFrame | Tower slot template |
| `UpgradeUi` | Frame | ScreenGui | Tower upgrade interface |
| `Portrait` | Frame | UpgradeUi | Tower portrait container |
| `ViewportFrame` | ViewportFrame | Portrait | 3D tower preview |
| `MaxLimit` | Frame | ScreenGui | Max tower warning |
| `MaxLimitL` | TextLabel | MaxLimit | Warning text |

---

## 7. Workspace Folders

Create these folders in Workspace before running the game.

| Folder Name | Purpose | Referenced In |
|-------------|---------|---------------|
| `Towers` | Contains all placed towers | `Tower.lua`, `GameController.client.lua` |
| `Mobs` | Contains all spawned enemies | `Tower.lua`, `Mob.lua`, `Main.lua` |

### How to Create
1. In Explorer, right-click `Workspace`
2. Select **Insert Object → Folder**
3. Rename to `Towers` or `Mobs`

---

## 8. Player Value Objects

These are created when a player joins. For testing, you can pre-create them.

### Created by `OnPlayerAdded.lua` (Maps)

| Value Name | Type | Parent | Default |
|------------|------|--------|---------|
| `Cash` | IntValue | Player | 5000000 |
| `PlacedTowers` | IntValue | Player | 0 |

### Created by `PlayerDataManager.lua`

Creates a `PlayerData` folder under each Player with:

| Value Name | Type | Parent | Purpose |
|------------|------|--------|---------|
| `Gems` | IntValue | PlayerData | Premium currency |
| `Coins` | IntValue | PlayerData | Regular currency |
| `Tickets` | IntValue | PlayerData | Event currency |
| `TotalSummons` | IntValue | PlayerData | Summon count |
| `PityCounter` | IntValue | PlayerData | Legendary pity |
| `MythicPityCounter` | IntValue | PlayerData | Mythic pity |
| `Stats` | Folder | PlayerData | Stats container |
| `TotalGamesPlayed` | IntValue | Stats | Games played |
| `TotalWaves` | IntValue | Stats | Waves completed |
| `TotalMobsKilled` | IntValue | Stats | Kill count |
| `TotalGemsEarned` | IntValue | Stats | Total gems earned |
| `MapProgress` | Folder | PlayerData | Map completion |
| `Inventory` | Folder | PlayerData | Owned towers |
| `Loadout` | Folder | PlayerData | Equipped towers |
| `Slot_1` to `Slot_6` | StringValue | Loadout | Tower IDs |

---

## 9. Refactoring Checklist

### Step 1: Create ReplicatedStorage Structure
- [ ] Create `ReplicatedStorage/Events` folder
- [ ] Create `ReplicatedStorage/Functions` folder
- [ ] Verify `ReplicatedStorage/Shared` exists (Lobby)
- [ ] Verify `ReplicatedStorage/Modules` exists (Maps)
- [ ] Verify `ReplicatedStorage/Towers` exists

### Step 2: Create All RemoteFunctions (Lobby)
- [ ] `SingleSummon`
- [ ] `MultiSummon`
- [ ] `GetInventory`
- [ ] `GetLoadout`
- [ ] `AddToLoadout`
- [ ] `RemoveFromLoadout`
- [ ] `SetLoadoutSlot`
- [ ] `TeleportToGame`
- [ ] `TeleportParty`
- [ ] `GetPartyInfo`
- [ ] `LeaveParty`
- [ ] `GetPartyMaps`
- [ ] `GetPartyActs`

### Step 3: Create All RemoteFunctions (Maps)
- [ ] `RequestTower`
- [ ] `ChangeTowerPriority`
- [ ] `SpawnTower`
- [ ] `SellTower`
- [ ] `UpgradeTower`
- [ ] `GetUpgradeCost`
- [ ] `UpgradeToParagon`
- [ ] `GetUpgradeStats`
- [ ] `GetParagonData`
- [ ] `GetPathColor`
- [ ] `ResetGame`
- [ ] `SkipWave`
- [ ] `ToggleSpeed`

### Step 4: Create All RemoteEvents
- [ ] `AnimateTower`
- [ ] `DamageIndicator`
- [ ] `PlayerKill`
- [ ] `PlayerDamage`
- [ ] `StartGame`
- [ ] `AwardVictoryRewards`
- [ ] `SpeedChanged`
- [ ] `NextAct`
- [ ] `PartyUpdated`

### Step 5: Create Workspace Folders
- [ ] `Workspace/Towers`
- [ ] `Workspace/Mobs`

### Step 6: Create GUI (Lobby)
- [ ] `LobbyGui` ScreenGui
- [ ] `SummonUI` with all children
- [ ] `ResultFrame` with ViewportFrame
- [ ] `InventoryUI` with GridFrame and Template
- [ ] `LoadoutUI` with Template and EmptyTemplate
- [ ] `GemsDisplay`
- [ ] `MapSelectorUI` with all children
- [ ] `PlayButton` and `Buttons` container
- [ ] `ErrorMessage`

### Step 7: Create GUI (Maps)
- [ ] `LoadoutFrame` with Template
- [ ] `UpgradeUi` with Portrait/ViewportFrame
- [ ] `MaxLimit` warning frame

---

## Code Cleanup After Manual Setup

Once all items are created manually, remove the `Instance.new()` creation code from:

### LobbyServer.lua (Lines 41-83)
```lua
-- REMOVE THIS SECTION:
local events = ReplicatedStorage:FindFirstChild("Events")
if not events then
    events = Instance.new("Folder")
    events.Name = "Events"
    events.Parent = ReplicatedStorage
end
-- ... and all RemoteFunction creation code
```

**Replace with:**
```lua
local events = ReplicatedStorage:WaitForChild("Events")
local functions = ReplicatedStorage:WaitForChild("Functions")

local SingleSummonFunction = functions:WaitForChild("SingleSummon")
local MultiSummonFunction = functions:WaitForChild("MultiSummon")
-- etc.
```

### Tower.lua (Lines 16-40, 1237-1289)
Remove all `if not X then Instance.new()` blocks and replace with `WaitForChild()`.

### GameManager.lua (Lines 16-41)
Remove `getOrCreateEvent` and `getOrCreateFunction` helper functions. Use `WaitForChild()` directly.

### PartyService.lua (Lines 38-75)
Remove all conditional `Instance.new()` blocks.

---

## Benefits of Manual Setup

1. **Cleaner Code**: No runtime instance creation
2. **Faster Load Times**: Objects already exist
3. **Easier Debugging**: Can inspect objects in Explorer
4. **Version Control**: Structure visible in place file
5. **Studio Editing**: Can modify properties visually
6. **No Race Conditions**: Objects guaranteed to exist

---

## Testing After Refactoring

1. **Start Lobby Place**: Verify all remote functions respond
2. **Open SummonUI**: Test single/multi summon
3. **Check Inventory**: Verify towers display
4. **Edit Loadout**: Add/remove/swap towers
5. **Select Map**: Navigate map selector
6. **Teleport**: Start game and verify loadout transfers
7. **In-Game**: Place towers, upgrade, sell
8. **Party System**: Test PlayBox entry/exit

---

*This document serves as the complete reference for manual Roblox Studio setup to replace runtime Instance.new() calls.*
