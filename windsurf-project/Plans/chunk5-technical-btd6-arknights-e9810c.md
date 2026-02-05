# Chunk 5: Technical/Backend + BTD6 + Arknights Mechanics

Implementation details for backend systems, BTD6-inspired mechanics, and Arknights-inspired features.

---

## File Index

| File Path | Purpose |
|-----------|---------|
| `ServerScriptService/Services/DataService.lua` | Central data management |
| `ServerScriptService/Services/LeaderboardService.lua` | Global leaderboards |
| `ServerScriptService/Services/AntiCheatService.lua` | Exploit prevention |
| `ReplicatedStorage/Modules/PathingSystem.lua` | BTD6-style enemy pathing |
| `ReplicatedStorage/Modules/PopSystem.lua` | BTD6 bloon-like layers |
| `ReplicatedStorage/Modules/MonkeyKnowledgeSystem.lua` | BTD6 permanent upgrades |
| `ReplicatedStorage/Modules/DeploymentSystem.lua` | Arknights deployment |
| `ReplicatedStorage/Modules/DPSystem.lua` | Arknights deployment points |
| `ReplicatedStorage/Modules/TrustSystem.lua` | Arknights trust/affection |
| `ReplicatedStorage/Modules/BaseSystem.lua` | Arknights base building |

---

## 5.1 Data Service

```lua
local DataService = {}
local DataStoreService = game:GetService("DataStoreService")
local PlayerStore = DataStoreService:GetDataStore("PlayerData_v2")
local PlayerCache = {}

DataService.DefaultData = {
    Version = 2, Units = {}, OwnedUnits = {}, Gold = 1000, Gems = 50,
    Account = {Level = 1, XP = 0}, Mastery = {}, Achievements = {},
    Pity = {}, StoryProgress = {}, EndlessRecords = {},
    MonkeyKnowledge = {Points = 0, Unlocked = {}},
    Trust = {}, Base = {Facilities = {}}, Sanity = {Current = 100, Max = 100},
}

function DataService.LoadPlayer(player)
    local success, data = pcall(function()
        return PlayerStore:GetAsync("Player_" .. player.UserId)
    end)
    if not success or not data then
        data = table.clone(DataService.DefaultData)
    end
    PlayerCache[player.UserId] = data
    return data
end

function DataService.SavePlayer(player)
    local data = PlayerCache[player.UserId]
    if data then
        pcall(function() PlayerStore:SetAsync("Player_" .. player.UserId, data) end)
    end
end

function DataService.GetData(player) return PlayerCache[player.UserId] end
return DataService
```

---

## 5.2 BTD6 Pathing System

```lua
local PathingSystem = {}
PathingSystem.Paths = {}

function PathingSystem.CreatePath(pathId, waypoints)
    local path = {Id = pathId, Waypoints = waypoints, TotalLength = 0, SegmentLengths = {}}
    for i = 1, #waypoints - 1 do
        local len = (waypoints[i + 1] - waypoints[i]).Magnitude
        path.SegmentLengths[i] = len
        path.TotalLength = path.TotalLength + len
    end
    PathingSystem.Paths[pathId] = path
    return path
end

function PathingSystem.GetPositionAtDistance(pathId, distance)
    local path = PathingSystem.Paths[pathId]
    if not path then return nil end
    distance = math.clamp(distance, 0, path.TotalLength)
    
    local cumulative = 0
    for i, segLen in ipairs(path.SegmentLengths) do
        if cumulative + segLen >= distance then
            local t = (distance - cumulative) / segLen
            return path.Waypoints[i]:Lerp(path.Waypoints[i + 1], t)
        end
        cumulative = cumulative + segLen
    end
    return path.Waypoints[#path.Waypoints]
end

return PathingSystem
```

---

## 5.3 BTD6 Pop/Layer System

```lua
local PopSystem = {}

PopSystem.Layers = {
    RED = {Health = 1, Speed = 1.0, Children = nil, RBE = 1},
    BLUE = {Health = 1, Speed = 1.4, Children = {"RED"}, RBE = 2},
    GREEN = {Health = 1, Speed = 1.8, Children = {"BLUE"}, RBE = 3},
    YELLOW = {Health = 1, Speed = 3.2, Children = {"GREEN"}, RBE = 4},
    PINK = {Health = 1, Speed = 3.5, Children = {"YELLOW"}, RBE = 5},
    LEAD = {Health = 1, Speed = 1.0, Children = {"BLACK", "BLACK"}, RBE = 23, Immune = {"Sharp"}},
    CERAMIC = {Health = 10, Speed = 2.5, Children = {"RAINBOW", "RAINBOW"}, RBE = 104},
    MOAB = {Health = 200, Speed = 1.0, Children = {"CERAMIC", "CERAMIC", "CERAMIC", "CERAMIC"}, RBE = 616, IsBoss = true},
}

function PopSystem.CreateEnemy(layerType, distance)
    local layer = PopSystem.Layers[layerType]
    if not layer then return nil end
    return {
        LayerType = layerType, Health = layer.Health, MaxHealth = layer.Health,
        Speed = layer.Speed, Distance = distance or 0, Immunities = layer.Immune or {},
    }
end

function PopSystem.TakeDamage(enemy, damage, damageType)
    for _, imm in ipairs(enemy.Immunities) do
        if imm == damageType then return 0, nil end
    end
    enemy.Health = enemy.Health - damage
    if enemy.Health <= 0 then
        local layer = PopSystem.Layers[enemy.LayerType]
        if layer.Children then
            local children = {}
            for _, childType in ipairs(layer.Children) do
                table.insert(children, PopSystem.CreateEnemy(childType, enemy.Distance))
            end
            return damage, children
        end
    end
    return damage, nil
end

return PopSystem
```

---

## 5.4 BTD6 Monkey Knowledge

```lua
local MonkeyKnowledgeSystem = {}

MonkeyKnowledgeSystem.Knowledge = {
    MORE_CASH = {Tree = "SUPPORT", Cost = 1, Effect = {Type = "START_CASH", Value = 200}},
    DART_TRAINING = {Tree = "PRIMARY", Cost = 1, Effect = {Type = "STAT", Target = "PRIMARY", Stat = "Pierce", Value = 1}},
    HERO_XP_BOOST = {Tree = "HEROES", Cost = 2, Effect = {Type = "HERO_XP", Value = 0.10}},
}

function MonkeyKnowledgeSystem.Unlock(playerData, knowledgeId)
    local mk = playerData.MonkeyKnowledge
    local knowledge = MonkeyKnowledgeSystem.Knowledge[knowledgeId]
    if not knowledge or mk.Unlocked[knowledgeId] or mk.Points < knowledge.Cost then return false end
    mk.Points = mk.Points - knowledge.Cost
    mk.Unlocked[knowledgeId] = true
    return true
end

function MonkeyKnowledgeSystem.GetEffects(playerData)
    local effects = {}
    for id in pairs(playerData.MonkeyKnowledge.Unlocked) do
        local k = MonkeyKnowledgeSystem.Knowledge[id]
        if k then table.insert(effects, k.Effect) end
    end
    return effects
end

return MonkeyKnowledgeSystem
```

---

## 5.5 Arknights Deployment System

```lua
local DeploymentSystem = {}
DeploymentSystem.Config = {MaxDeployed = 12, RedeployPenalty = 70}

DeploymentSystem.Classes = {
    VANGUARD = {Position = "GROUND", BlockCount = 2, DPRecovery = true, BaseCost = 8},
    GUARD = {Position = "GROUND", BlockCount = 2, BaseCost = 12},
    DEFENDER = {Position = "GROUND", BlockCount = 3, BaseCost = 18},
    SNIPER = {Position = "RANGED", BlockCount = 0, BaseCost = 12},
    CASTER = {Position = "RANGED", BlockCount = 0, BaseCost = 18},
    MEDIC = {Position = "RANGED", BlockCount = 0, BaseCost = 14, Healer = true},
}

function DeploymentSystem.CreateState()
    return {Deployed = {}, RedeployCooldowns = {}, Count = 0}
end

function DeploymentSystem.Deploy(state, unit, position, dp)
    if state.Count >= DeploymentSystem.Config.MaxDeployed then return false, "Max deployed" end
    local class = DeploymentSystem.Classes[unit.Class]
    if not class or dp < class.BaseCost then return false, "Cannot deploy" end
    
    local id = #state.Deployed + 1
    state.Deployed[id] = {Unit = unit, Position = position, BlockedEnemies = {}}
    state.Count = state.Count + 1
    return true, class.BaseCost
end

function DeploymentSystem.Retreat(state, id)
    local deployed = state.Deployed[id]
    if not deployed then return false end
    state.RedeployCooldowns[deployed.Unit.Id] = os.time() + DeploymentSystem.Config.RedeployPenalty
    state.Deployed[id] = nil
    state.Count = state.Count - 1
    return true
end

return DeploymentSystem
```

---

## 5.6 Arknights DP System

```lua
local DPSystem = {}
DPSystem.Config = {Starting = 10, Max = 99, BaseRegen = 1}

function DPSystem.CreateState()
    return {Current = DPSystem.Config.Starting, RegenRate = DPSystem.Config.BaseRegen}
end

function DPSystem.Update(state, dt, vanguardCount)
    local regen = state.RegenRate + (vanguardCount * 0.3)
    state.Current = math.min(state.Current + regen * dt, DPSystem.Config.Max)
end

function DPSystem.Spend(state, amount)
    if state.Current < amount then return false end
    state.Current = state.Current - amount
    return true
end

return DPSystem
```

---

## 5.7 Arknights Trust System

```lua
local TrustSystem = {}
TrustSystem.Config = {Max = 200, PerBattle = 5}
TrustSystem.Bonuses = {
    [50] = {ATK = 0.02}, [100] = {ATK = 0.05, HP = 0.03}, [200] = {ATK = 0.10, HP = 0.05, DEF = 0.03}
}

function TrustSystem.AddTrust(playerData, unitId, amount)
    playerData.Trust[unitId] = playerData.Trust[unitId] or 0
    playerData.Trust[unitId] = math.min(playerData.Trust[unitId] + amount, TrustSystem.Config.Max)
end

function TrustSystem.GetBonuses(playerData, unitId)
    local trust = playerData.Trust[unitId] or 0
    local bonuses = {}
    for threshold, bonus in pairs(TrustSystem.Bonuses) do
        if trust >= threshold then
            for stat, val in pairs(bonus) do
                bonuses[stat] = (bonuses[stat] or 0) + val
            end
        end
    end
    return bonuses
end

return TrustSystem
```

---

## 5.8 Arknights Base System

```lua
local BaseSystem = {}

BaseSystem.Facilities = {
    FACTORY = {MaxLevel = 3, Slots = 5, Produces = {"GOLD", "EXP"}},
    TRADING = {MaxLevel = 3, Slots = 3},
    DORMITORY = {MaxLevel = 5, Slots = 4, MoraleRecovery = {0.4, 0.55, 0.7, 0.85, 1.0}},
    POWER = {MaxLevel = 3, Slots = 3, Output = {60, 90, 120}},
}

function BaseSystem.BuildFacility(playerData, facilityType, slot)
    local config = BaseSystem.Facilities[facilityType]
    if not config then return false end
    playerData.Base.Facilities[slot] = {Type = facilityType, Level = 1, Operators = {}}
    return true
end

function BaseSystem.AssignOperator(playerData, slot, operatorId)
    local facility = playerData.Base.Facilities[slot]
    if not facility then return false end
    table.insert(facility.Operators, operatorId)
    return true
end

return BaseSystem
```

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Data loss | Critical | Auto-save, retry logic, backup stores |
| Data corruption | Critical | Version migration, validation |
| Exploits | High | Server authority, anti-cheat validation |
| Leaderboard manipulation | Medium | Server-side score validation |
| Base timing exploits | Low | Server-side time tracking |

---

## Testing Checklist

- [ ] Data saves and loads correctly
- [ ] Data migrates between versions
- [ ] Leaderboards update and query properly
- [ ] Anti-cheat catches basic exploits
- [ ] Path positions calculate correctly
- [ ] Pop system spawns children on enemy death
- [ ] Monkey Knowledge effects apply to gameplay
- [ ] Deployment respects unit limits and costs
- [ ] DP regenerates and vanguards boost regen
- [ ] Trust bonuses apply to unit stats
- [ ] Base facilities produce resources over time

---

## Final Schema Summary

```lua
DefaultPlayerData = {
    Version = 2,
    -- Core (Chunk 1)
    Units = {}, OwnedUnits = {}, Inventory = {},
    -- Economy (Chunks 2-3)
    Gold = 1000, Gems = 50, PvPTokens = 0, RaidTokens = 0,
    -- Progression (Chunk 2)
    Account = {Level = 1, XP = 0}, Mastery = {}, Achievements = {},
    Pity = {}, BannerPulls = {}, Constellations = {},
    -- Game Progress (Chunk 3)
    StoryProgress = {}, EndlessRecords = {}, TowerProgress = {},
    PvP = {Rating = 1000}, Friends = {}, GuildId = nil,
    -- Daily Systems (Chunk 4)
    Login = {}, Missions = {}, BattlePass = {}, VIP = {}, Settings = {},
    -- BTD6 Systems (Chunk 5)
    MonkeyKnowledge = {Points = 0, Unlocked = {}}, HeroXP = {},
    -- Arknights Systems (Chunk 5)
    Trust = {}, Base = {Facilities = {}}, Sanity = {Current = 100, Max = 100},
    -- Meta
    CreatedAt = 0, LastSave = 0, PlayTime = 0,
}
```

---

## Implementation Priority

1. **DataService** - Foundation for all other systems
2. **PathingSystem + PopSystem** - Core TD gameplay
3. **DeploymentSystem + DPSystem** - Arknights-style placement
4. **MonkeyKnowledge** - Long-term progression hook
5. **TrustSystem + BaseSystem** - Idle/management layers
