# Code Cleanup: Remove Instance.new() Calls

Replace all dynamically-created RemoteEvents/RemoteFunctions with `WaitForChild()` references to the manually-created instances.

---

## Files to Modify

| File | Location | Changes |
|------|----------|---------|
| `LobbyServer.lua` | Lobby | Remove folder creation + 7 RemoteFunction creations |
| `PartyService.lua` | Lobby | Remove Events folder creation + 6 RemoteEvent/Function creations |
| `TeleportManager.lua` | Lobby | Remove Functions folder creation + 1 RemoteFunction creation |
| `Tower.lua` | Maps | Remove 9 RemoteEvent/Function creations |
| `GameManager.lua` | Maps | Remove helper functions + 6 getOrCreate calls |

---

## Detailed Changes

### 1. LobbyServer.lua (Lines 40-83)

**Remove:**
```lua
-- Lines 41-53: Folder creation
local events = ReplicatedStorage:FindFirstChild("Events")
if not events then ... end
local functions = ReplicatedStorage:FindFirstChild("Functions")
if not functions then ... end

-- Lines 56-83: All Instance.new("RemoteFunction") calls
```

**Replace with:**
```lua
-- Get pre-created folders and functions
local events = ReplicatedStorage:WaitForChild("Events")
local functions = ReplicatedStorage:WaitForChild("Functions")

local SingleSummonFunction = functions:WaitForChild("SingleSummon")
local MultiSummonFunction = functions:WaitForChild("MultiSummon")
local GetInventoryFunction = functions:WaitForChild("GetInventory")
local GetLoadoutFunction = functions:WaitForChild("GetLoadout")
local AddToLoadoutFunction = functions:WaitForChild("AddToLoadout")
local RemoveFromLoadoutFunction = functions:WaitForChild("RemoveFromLoadout")
local SetLoadoutSlotFunction = functions:WaitForChild("SetLoadoutSlot")
```

---

### 2. PartyService.lua (Lines 38-75, 844-867)

**Remove:**
```lua
-- Lines 38-43: Events folder creation
local events = ReplicatedStorage:FindFirstChild("Events")
if not events then ... end

-- Lines 46-75: All if not then Instance.new() blocks for:
-- GetPartyInfo, PartyUpdated, TeleportParty, LeaveParty

-- Lines 845-849: GetPartyMaps creation
-- Lines 862-867: GetPartyActs creation
```

**Replace with:**
```lua
-- Line 38: Direct WaitForChild
local events = ReplicatedStorage:WaitForChild("Events")

-- Lines 46-75: Replace with WaitForChild
local GetPartyInfoFunction = functions:WaitForChild("GetPartyInfo")
local PartyUpdatedEvent = events:WaitForChild("PartyUpdated")
local TeleportPartyFunction = functions:WaitForChild("TeleportParty")
local LeavePartyFunction = functions:WaitForChild("LeaveParty")

-- Lines 845, 862: Replace with WaitForChild
local GetPartyMapsFunction = functions:WaitForChild("GetPartyMaps")
local GetPartyActsFunction = functions:WaitForChild("GetPartyActs")
```

---

### 3. TeleportManager.lua (Lines 185-195)

**Remove:**
```lua
-- Lines 186-195: Functions folder creation + TeleportToGame creation
local functions = ReplicatedStorage:FindFirstChild("Functions")
if not functions then ... end
local TeleportToGameFunction = Instance.new("RemoteFunction")
...
```

**Replace with:**
```lua
-- Get pre-created function
local functions = ReplicatedStorage:WaitForChild("Functions")
local TeleportToGameFunction = functions:WaitForChild("TeleportToGame")
```

---

### 4. Tower.lua (Lines 16-41, 1237-1289)

**Remove:**
```lua
-- Lines 16-41: All if not then Instance.new() blocks for:
-- DamageIndicator, PlayerKill, PlayerDamage

-- Lines 1237-1289: All if not then Instance.new() blocks for:
-- UpgradeTower, GetUpgradeCost, UpgradeToParagon, 
-- GetUpgradeStats, GetParagonData, GetPathColor
```

**Replace at lines 16-41:**
```lua
local DamageIndicatorEvent = events:WaitForChild("DamageIndicator")
local PlayerKillEvent = events:WaitForChild("PlayerKill")
local PlayerDamageEvent = events:WaitForChild("PlayerDamage")
```

**Replace at lines 1237-1289:**
```lua
local upgradeTowerFunction = functions:WaitForChild("UpgradeTower")
local getUpgradeCostFunction = functions:WaitForChild("GetUpgradeCost")
local upgradeToParagonFunction = functions:WaitForChild("UpgradeToParagon")
local getUpgradeStatsFunction = functions:WaitForChild("GetUpgradeStats")
local getParagonDataFunction = functions:WaitForChild("GetParagonData")
local getPathColorFunction = functions:WaitForChild("GetPathColor")
```

---

### 5. GameManager.lua (Lines 15-41)

**Remove:**
```lua
-- Lines 16-34: Helper functions getOrCreateEvent, getOrCreateFunction
-- Lines 36-41: All getOrCreate calls
```

**Replace with:**
```lua
local AwardVictoryRewardsEvent = events:WaitForChild("AwardVictoryRewards")
local ResetGameFunction = functions:WaitForChild("ResetGame")
local StartGameEvent = events:WaitForChild("StartGame")
local SkipWaveFunction = functions:WaitForChild("SkipWave")
local ToggleSpeedFunction = functions:WaitForChild("ToggleSpeed")
local SpeedChangedEvent = events:WaitForChild("SpeedChanged")
```

---

## Summary of Removed Code

| File | Lines Removed | Instances Affected |
|------|---------------|-------------------|
| LobbyServer.lua | ~43 lines | 2 Folders, 7 RemoteFunctions |
| PartyService.lua | ~40 lines | 1 Folder, 6 RemoteFunctions/Events |
| TeleportManager.lua | ~10 lines | 1 Folder, 1 RemoteFunction |
| Tower.lua | ~75 lines | 9 RemoteFunctions/Events |
| GameManager.lua | ~25 lines | 6 RemoteFunctions/Events |
| **Total** | **~193 lines** | **3 Folders, 29 Remotes** |

---

## Verification After Cleanup

1. Start Lobby place → should load without errors
2. Test summon buttons → SingleSummon/MultiSummon work
3. Check inventory → GetInventory returns data
4. Test loadout → Add/Remove/Set work
5. Test party system → GetPartyInfo, TeleportParty work
6. Start game map → towers can be placed/upgraded
7. Check damage indicators → DamageIndicator event fires

---

**Confirm to proceed with these changes?**
