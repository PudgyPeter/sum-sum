# Chunk 1: Core Unit Systems Implementation Plan

Full implementation details for 8 core unit systems with code blocks, risks, and mitigations.

---

## File Index (New Files to Create)

| File Path | Purpose |
|-----------|---------|
| `ReplicatedStorage/Modules/ColorTypeSystem.lua` | Elemental type advantages |
| `ReplicatedStorage/Modules/TagSystem.lua` | Unit tags and synergies |
| `ReplicatedStorage/Modules/EvolutionSystem.lua` | XP and evolution stages |
| `ReplicatedStorage/Modules/AbilitySystem.lua` | Active abilities |
| `ReplicatedStorage/Modules/PassiveSystem.lua` | Passive abilities and auras |
| `ReplicatedStorage/Modules/TraitSystem.lua` | Random unit traits |
| `ReplicatedStorage/Modules/RelicSystem.lua` | Equipment system |
| `Maps/ServerScriptService/Main/XPManager.lua` | XP distribution |
| `StarterPlayerScripts/TypeIndicatorHandler.lua` | Client-side type UI |

---

## 1.1 Color Type System

### ColorTypeSystem.lua

```lua
local ColorTypeSystem = {}

ColorTypeSystem.Types = {
    RED = {Name = "Fire", Color = Color3.fromRGB(255, 50, 50), StrongAgainst = "YEL", WeakAgainst = "BLU"},
    YEL = {Name = "Lightning", Color = Color3.fromRGB(255, 220, 50), StrongAgainst = "PUR", WeakAgainst = "RED"},
    PUR = {Name = "Shadow", Color = Color3.fromRGB(180, 80, 255), StrongAgainst = "GRN", WeakAgainst = "YEL"},
    GRN = {Name = "Nature", Color = Color3.fromRGB(80, 220, 80), StrongAgainst = "BLU", WeakAgainst = "PUR"},
    BLU = {Name = "Water", Color = Color3.fromRGB(80, 150, 255), StrongAgainst = "RED", WeakAgainst = "GRN"},
    LIGHT = {Name = "Holy", Color = Color3.fromRGB(255, 255, 200), StrongAgainst = "DARK", WeakAgainst = "DARK"},
    DARK = {Name = "Void", Color = Color3.fromRGB(60, 40, 80), StrongAgainst = "LIGHT", WeakAgainst = "LIGHT"},
}

ColorTypeSystem.Multipliers = {Advantage = 1.3, Disadvantage = 0.7, Neutral = 1.0, Mutual = 1.2}

-- Pre-built lookup cache for O(1) access
local cache = {}
for aType, aData in pairs(ColorTypeSystem.Types) do
    cache[aType] = {}
    for dType in pairs(ColorTypeSystem.Types) do
        if aData.StrongAgainst == dType then
            cache[aType][dType] = (aType == "LIGHT" or aType == "DARK") and 1.2 or 1.3
        elseif aData.WeakAgainst == dType then
            cache[aType][dType] = 0.7
        else
            cache[aType][dType] = 1.0
        end
    end
end

function ColorTypeSystem.GetDamageMultiplier(attackerType, defenderType)
    if not attackerType or not defenderType then return 1.0 end
    return cache[attackerType] and cache[attackerType][defenderType] or 1.0
end

function ColorTypeSystem.GetTypeColor(colorType)
    return ColorTypeSystem.Types[colorType] and ColorTypeSystem.Types[colorType].Color or Color3.new(1,1,1)
end

function ColorTypeSystem.HasAdvantage(attacker, defender)
    return ColorTypeSystem.GetDamageMultiplier(attacker, defender) > 1
end

return ColorTypeSystem
```

### Tower.lua Integration (line ~175)

```lua
local ColorTypeSystem = require(ReplicatedStorage.Modules.ColorTypeSystem)

-- After crit calculation, before TakeDamage:
local towerType = config:FindFirstChild("ColorType") and config.ColorType.Value
local mobType = target:FindFirstChild("ColorType") and target.ColorType.Value
local typeMult = ColorTypeSystem.GetDamageMultiplier(towerType, mobType)
damageAmount = math.floor(damageAmount * typeMult)

-- Fire VFX event for type indicator
if typeMult ~= 1.0 then
    ReplicatedStorage.Events.TypeIndicator:FireAllClients(target, typeMult > 1 and "Super" or "Weak")
end
```

### Data Updates

```lua
-- TowerData: Add ColorType field
TowerData["Luffy"] = {ColorType = "RED", ...}
TowerData["Zoro"] = {ColorType = "GRN", ...}
TowerData["Nami"] = {ColorType = "YEL", ...}

-- MobData: Add ColorType field
MobData["PudgePete"] = {ColorType = "BLU", ...}
```

| Risk | Mitigation |
|------|------------|
| Performance per attack | Cache lookup is O(1) |
| Missing ColorType | Default to nil (returns 1.0) |
| Player confusion | Type chart in UI + indicators |

---

## 1.2 Unit Tags System

### TagSystem.lua

```lua
local TagSystem = {}

TagSystem.Categories = {
    ANIME = {"OnePiece", "Naruto", "DragonBall", "Bleach", "JJK", "DemonSlayer", "AOT", "MHA"},
    FACTION = {"StrawHat", "Akatsuki", "Saiyan", "Marine", "Shinigami", "Hashira", "SurveyCorps"},
    ROLE = {"Captain", "Swordsman", "Support", "Tank", "Assassin", "Healer", "Buffer", "DPS"},
    STYLE = {"Melee", "Ranged", "Magic", "AOE", "SingleTarget"},
}

-- Validate tags
TagSystem.ValidTags = {}
for cat, tags in pairs(TagSystem.Categories) do
    for _, tag in ipairs(tags) do TagSystem.ValidTags[tag] = cat end
end

-- Map buffs
TagSystem.MapBuffs = {
    GrandLine = {Tags = {"OnePiece", "StrawHat", "Marine"}, Bonus = 0.20},
    HiddenLeaf = {Tags = {"Naruto", "Akatsuki"}, Bonus = 0.20},
    Namek = {Tags = {"DragonBall", "Saiyan"}, Bonus = 0.20},
}

-- Synergy (3+ matching = bonus)
TagSystem.SynergyBonus = {
    ANIME = {[3] = 0.10, [5] = 0.20},
    FACTION = {[3] = 0.15, [5] = 0.25},
    ROLE = {[4] = 0.10, [6] = 0.15}, -- Diversity bonus
}
TagSystem.MaxSynergyTotal = 0.50

function TagSystem.GetMapBonus(unitTags, mapId)
    local buff = TagSystem.MapBuffs[mapId]
    if not buff then return 0 end
    for _, tag in ipairs(unitTags) do
        for _, buffTag in ipairs(buff.Tags) do
            if tag == buffTag then return buff.Bonus end
        end
    end
    return 0
end

function TagSystem.CalculateTeamSynergy(teamUnits)
    local result = {Damage = 0, AttackSpeed = 0, Range = 0}
    local categoryCounts = {}
    
    for _, unit in ipairs(teamUnits) do
        for _, tag in ipairs(unit.Tags or {}) do
            local cat = TagSystem.ValidTags[tag]
            if cat then
                categoryCounts[cat] = categoryCounts[cat] or {}
                categoryCounts[cat][tag] = (categoryCounts[cat][tag] or 0) + 1
            end
        end
    end
    
    for cat, tagCounts in pairs(categoryCounts) do
        local bonus = TagSystem.SynergyBonus[cat]
        if bonus then
            local maxCount = 0
            for _, count in pairs(tagCounts) do maxCount = math.max(maxCount, count) end
            for threshold, value in pairs(bonus) do
                if maxCount >= threshold then result.Damage = result.Damage + value end
            end
        end
    end
    
    result.Damage = math.min(result.Damage, TagSystem.MaxSynergyTotal)
    return result
end

return TagSystem
```

### Data Updates

```lua
TowerData["Luffy"] = {
    Tags = {"OnePiece", "StrawHat", "Captain", "Melee"},
    ...
}
```

| Risk | Mitigation |
|------|------------|
| OP stacking | Cap at 50% total |
| Tag typos | Validate against ValidTags |
| Recalc cost | Only on tower place/sell |

---

## 1.3 Evolution & XP System

### EvolutionSystem.lua

```lua
local EvolutionSystem = {}

EvolutionSystem.XPGain = {
    MobKill = 1, EliteKill = 5, BossKill = 25, WaveComplete = 50, ActComplete = 500
}

EvolutionSystem.Data = {
    ["Luffy"] = {
        [0] = {Name = "East Blue", XP = 0, StatMult = 1.0, Model = "Luffy_Base"},
        [1] = {Name = "Gear 2", XP = 1000, StatMult = 1.25, Model = "Luffy_Gear2", Abilities = {"JetPistol"}},
        [2] = {Name = "Haki", XP = 5000, StatMult = 1.5, Model = "Luffy_Haki", Abilities = {"ElephantGun"}},
        [3] = {Name = "Gear 4", XP = 15000, StatMult = 2.0, Model = "Luffy_Gear4", Abilities = {"KingKongGun"}},
        [4] = {Name = "Gear 5", RequiresTrial = "NikaTrial", StatMult = 3.0, Model = "Luffy_Gear5"},
    },
    -- Add more units...
}

EvolutionSystem.Default = {
    [0] = {XP = 0, StatMult = 1.0},
    [1] = {XP = 1000, StatMult = 1.2},
    [2] = {XP = 5000, StatMult = 1.5},
    [3] = {XP = 15000, StatMult = 2.0},
}

function EvolutionSystem.GetStage(unitId, xp)
    local data = EvolutionSystem.Data[unitId] or EvolutionSystem.Default
    local stage = 0
    for s, d in pairs(data) do
        if type(s) == "number" and not d.RequiresTrial then
            if xp >= (d.XP or 0) and s > stage then stage = s end
        end
    end
    return stage
end

function EvolutionSystem.GetData(unitId, stage)
    local data = EvolutionSystem.Data[unitId] or EvolutionSystem.Default
    return data[stage]
end

function EvolutionSystem.GetStatMultiplier(unitId, stage)
    local data = EvolutionSystem.GetData(unitId, stage)
    return data and data.StatMult or 1.0
end

return EvolutionSystem
```

### PlayerData Schema Change

```lua
-- OLD: Inventory = {"Luffy", "Zoro", ...}
-- NEW: UnitInstances (each unit is unique)
UnitInstances = {
    ["uuid-1"] = {
        UnitId = "Luffy",
        XP = 0,
        EvolutionStage = 0,
        Traits = {},
        EquippedRelics = {},
        DateObtained = os.time(),
        Locked = false,
    },
}
Loadout = {"uuid-1", "uuid-2", ...} -- References instance IDs
```

### XPManager.lua (Server)

```lua
local XPManager = {}
local deployedUnits = {} -- {[player] = {[tower] = instanceId}}
local pendingXP = {}

function XPManager.Register(player, tower, instanceId)
    deployedUnits[player] = deployedUnits[player] or {}
    deployedUnits[player][tower] = instanceId
end

function XPManager.AwardToTower(player, tower, amount)
    local id = deployedUnits[player] and deployedUnits[player][tower]
    if id then
        pendingXP[player] = pendingXP[player] or {}
        pendingXP[player][id] = (pendingXP[player][id] or 0) + amount
    end
end

function XPManager.AwardToAll(player, amount)
    for tower, id in pairs(deployedUnits[player] or {}) do
        pendingXP[player] = pendingXP[player] or {}
        pendingXP[player][id] = (pendingXP[player][id] or 0) + amount
    end
end

function XPManager.Flush()
    for player, instances in pairs(pendingXP) do
        local data = PlayerDataManager.Get(player)
        for id, xp in pairs(instances) do
            local unit = data.UnitInstances[id]
            if unit then
                unit.XP = (unit.XP or 0) + xp
                local newStage = EvolutionSystem.GetStage(unit.UnitId, unit.XP)
                if newStage > (unit.EvolutionStage or 0) then
                    unit.EvolutionStage = newStage
                    -- Fire evolution event
                end
            end
        end
    end
    pendingXP = {}
end

return XPManager
```

| Risk | Mitigation |
|------|------------|
| Migration breaks saves | Test thoroughly, backup data |
| XP desync | Server authoritative |
| Large save data | Limit 500 units, compress |

---

## 1.4 Enhanced Upgrade Paths

### TowerUpgradeData.lua Updates

```lua
UpgradeData["Luffy"] = {
    A = {
        [1] = {damage = 5, cost = 100, name = "Gum-Gum Pistol"},
        [2] = {damage = 10, cost = 200, name = "Gum-Gum Bazooka"},
        [3] = {
            chooseBranch = true,
            branches = {
                Power = {damage = 25, cost = 400, name = "Giant Pistol"},
                AOE = {damage = 15, cost = 400, name = "Gatling", special = {aoe = 8}},
            },
        },
        [4] = {damage = 20, cost = 600, name = "Haki Enhancement"},
        [5] = {damage = 30, cost = 1000, name = "Elephant Gun"},
        [6] = {damage = 50, cost = 2000, name = "King Kong Gun", ability = "KingKongGun"},
    },
    B = {...}, C = {...},
    
    CrossPathBonuses = {
        {A = 3, B = 3, Bonus = {CritChance = 5}},
        {A = 6, C = 3, Bonus = {Damage = 0.10}},
    },
}

function UpgradeData.GetUpgrade(tower, path, tier, branch)
    local data = UpgradeData[tower] and UpgradeData[tower][path] and UpgradeData[tower][path][tier]
    if data and data.chooseBranch then
        return branch and data.branches[branch] or nil, "Branch required"
    end
    return data
end

function UpgradeData.GetCrossPathBonus(tower, upgrades)
    local bonuses = {}
    for _, cpb in ipairs(UpgradeData[tower].CrossPathBonuses or {}) do
        local valid = true
        for path, req in pairs(cpb) do
            if path ~= "Bonus" and (upgrades[path] or 0) < req then valid = false end
        end
        if valid then
            for stat, val in pairs(cpb.Bonus) do
                bonuses[stat] = (bonuses[stat] or 0) + val
            end
        end
    end
    return bonuses
end
```

| Risk | Mitigation |
|------|------------|
| Branch UI complexity | Modal with side-by-side comparison |
| Storing branch choice | Add PathX_Branch StringValue to config |
| Respec desire | Premium "Respec Token" item |

---

## 1.5 Active Abilities

### AbilitySystem.lua

```lua
local AbilitySystem = {}
local cooldowns = {}

AbilitySystem.Abilities = {
    KingKongGun = {
        Cooldown = 60,
        Type = "Damage",
        Execute = function(tower, target)
            if target and target:FindFirstChild("Humanoid") then
                local dmg = tower.Config.Damage.Value * 10
                target.Humanoid:TakeDamage(dmg)
                ReplicatedStorage.Events.AbilityVFX:FireAllClients(tower, "KingKongGun", target)
            end
            return true
        end,
    },
    
    ConquerorsHaki = {
        Cooldown = 45,
        Type = "AOE",
        Range = 30,
        Execute = function(tower)
            local pos = tower.HumanoidRootPart.Position
            for _, mob in ipairs(workspace.Mobs:GetChildren()) do
                if mob:FindFirstChild("HumanoidRootPart") then
                    if (mob.HumanoidRootPart.Position - pos).Magnitude <= 30 then
                        StatusEffects.Apply(mob, "Stun", {Duration = 3})
                    end
                end
            end
            ReplicatedStorage.Events.AbilityVFX:FireAllClients(tower, "ConquerorsHaki")
            return true
        end,
    },
    
    ShadowClone = {
        Cooldown = 40,
        Type = "Summon",
        Execute = function(tower, _, player)
            for i = 1, 3 do
                local clone = tower:Clone()
                clone.Name = tower.Name .. "_Clone_" .. i
                clone.Config.Damage.Value = tower.Config.Damage.Value * 0.5
                clone:SetAttribute("IsTemporary", true)
                clone.Parent = workspace.Towers
                task.delay(15, function() if clone.Parent then clone:Destroy() end end)
            end
            return true
        end,
    },
}

function AbilitySystem.CanUse(tower, ability)
    local def = AbilitySystem.Abilities[ability]
    if not def then return false, "Unknown" end
    local last = cooldowns[tower] and cooldowns[tower][ability]
    if last and tick() - last < def.Cooldown then
        return false, string.format("%.1fs", def.Cooldown - (tick() - last))
    end
    return true
end

function AbilitySystem.Use(tower, ability, target, player)
    local can, err = AbilitySystem.CanUse(tower, ability)
    if not can then return false, err end
    
    local success = AbilitySystem.Abilities[ability].Execute(tower, target, player)
    if success then
        cooldowns[tower] = cooldowns[tower] or {}
        cooldowns[tower][ability] = tick()
    end
    return success
end

function AbilitySystem.Cleanup(tower)
    cooldowns[tower] = nil
end

return AbilitySystem
```

| Risk | Mitigation |
|------|------------|
| Exploit spam | Server cooldowns + rate limit |
| Memory leak | Cleanup on tower destroy |
| Desync | Sync state after each use |

---

## 1.6 Passive Abilities

### PassiveSystem.lua

```lua
local PassiveSystem = {}

PassiveSystem.Passives = {
    DrumsOfLiberation = {
        Type = "Aura",
        Range = 30,
        Buffs = {AttackSpeedBonus = 0.20},
    },
    GoldDigger = {
        Type = "OnKill",
        Effect = function(tower, mob, player)
            player:FindFirstChild("Cash").Value += 5
        end,
    },
    BurningStrike = {
        Type = "OnHit",
        Chance = 0.10,
        Effect = function(tower, target)
            StatusEffects.Apply(target, "Burn", {Damage = tower.Config.Damage.Value * 0.1, Duration = 3})
        end,
    },
    Momentum = {
        Type = "Stacking",
        MaxStacks = 50,
        PerStack = {DamagePercent = 0.01},
        DecayAfter = 3,
        DecayAmount = 5,
    },
}

local auraTargets = {} -- {[tower] = {affected towers}}
local stacks = {} -- {[tower] = {[passive] = {count, lastAttack}}}

function PassiveSystem.ProcessAuras(allTowers)
    -- Clear old
    for tower, targets in pairs(auraTargets) do
        for _, t in ipairs(targets) do PassiveSystem.RemoveBuff(t, tower) end
    end
    auraTargets = {}
    
    -- Apply new
    for _, tower in ipairs(allTowers) do
        for _, passiveName in ipairs(tower:GetAttribute("Passives") or {}) do
            local p = PassiveSystem.Passives[passiveName]
            if p and p.Type == "Aura" then
                local pos = tower.HumanoidRootPart.Position
                auraTargets[tower] = {}
                for _, other in ipairs(allTowers) do
                    if other ~= tower and (other.HumanoidRootPart.Position - pos).Magnitude <= p.Range then
                        PassiveSystem.ApplyBuff(other, p.Buffs, tower)
                        table.insert(auraTargets[tower], other)
                    end
                end
            end
        end
    end
end

function PassiveSystem.OnAttack(tower, target, player)
    for _, passiveName in ipairs(tower:GetAttribute("Passives") or {}) do
        local p = PassiveSystem.Passives[passiveName]
        if p and p.Type == "OnHit" and math.random() < p.Chance then
            p.Effect(tower, target)
        elseif p and p.Type == "Stacking" then
            stacks[tower] = stacks[tower] or {}
            stacks[tower][passiveName] = stacks[tower][passiveName] or {count = 0, last = tick()}
            local s = stacks[tower][passiveName]
            s.count = math.min(s.count + 1, p.MaxStacks)
            s.last = tick()
        end
    end
end

return PassiveSystem
```

| Risk | Mitigation |
|------|------------|
| Aura performance | Process every 0.5s, not per frame |
| Infinite buff stacking | Cap same-source buffs |
| Memory | Cleanup on tower destroy |

---

## 1.7 Trait System

### TraitSystem.lua

```lua
local TraitSystem = {}

TraitSystem.Traits = {
    Berserker = {Category = "Offensive", Effects = {Damage = 0.30, Defense = -0.20}},
    Precision = {Category = "Offensive", Effects = {CritChance = 15}},
    Relentless = {Category = "Offensive", Effects = {ArmorPen = 0.20}},
    Fortified = {Category = "Defensive", Effects = {HP = 0.25}},
    Regeneration = {Category = "Defensive", Effects = {HPRegen = 0.01}},
    Swift = {Category = "Utility", Effects = {AttackSpeed = 0.15}},
    FarSight = {Category = "Utility", Effects = {Range = 0.20}},
    Economy = {Category = "Utility", Effects = {CashBonus = 0.10}},
}

TraitSystem.RarityWeights = {Common = 50, Rare = 30, Epic = 15, Legendary = 5}
TraitSystem.CountByRarity = {
    Common = {0, 1}, Rare = {1, 1}, Epic = {1, 2}, Legendary = {1, 2}, Mythic = {2, 3}
}

function TraitSystem.Generate(unitRarity)
    local range = TraitSystem.CountByRarity[unitRarity] or {0, 1}
    local count = math.random(range[1], range[2])
    
    local pool, usedCats, result = {}, {}, {}
    for name, data in pairs(TraitSystem.Traits) do
        local w = TraitSystem.RarityWeights[data.Rarity or "Common"] or 10
        for i = 1, w do table.insert(pool, name) end
    end
    
    for i = 1, count do
        for _ = 1, 50 do
            local name = pool[math.random(#pool)]
            local cat = TraitSystem.Traits[name].Category
            if not usedCats[cat] then
                table.insert(result, name)
                usedCats[cat] = true
                break
            end
        end
    end
    return result
end

function TraitSystem.Calculate(traits)
    local bonuses = {}
    for _, name in ipairs(traits) do
        for stat, val in pairs(TraitSystem.Traits[name].Effects) do
            bonuses[stat] = (bonuses[stat] or 0) + val
        end
    end
    return bonuses
end

return TraitSystem
```

| Risk | Mitigation |
|------|------------|
| Bad RNG | Pity after 10 rerolls |
| OP combos | No duplicate categories |
| UI clutter | Show only on detail view |

---

## 1.8 Relic System

### RelicSystem.lua

```lua
local RelicSystem = {}

RelicSystem.Slots = {"Weapon", "Armor", "Accessory", "Artifact"}

RelicSystem.Sets = {
    Warrior = {[2] = {Damage = 0.15}, [4] = {Damage = 0.30, ArmorPen = 0.10}},
    Guardian = {[2] = {HP = 0.20}, [4] = {HP = 0.40, Reflect = 0.05}},
    Swift = {[2] = {AttackSpeed = 0.10}, [4] = {AttackSpeed = 0.25}},
    Vampire = {[2] = {Lifesteal = 0.05}, [4] = {Lifesteal = 0.15}},
}

RelicSystem.RarityMult = {Common = 1, Rare = 1.25, Epic = 1.5, Legendary = 2, Mythic = 2.5}
RelicSystem.SubstatCount = {Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythic = 4}

function RelicSystem.Generate(slot, rarity, setName)
    local mainStats = {Weapon = {"Damage", "CritDmg"}, Armor = {"HP", "Def"}, Accessory = {"CritChance", "Range"}, Artifact = {"AbilityCD", "AbilityDmg"}}
    local mainStat = mainStats[slot][math.random(#mainStats[slot])]
    local mult = RelicSystem.RarityMult[rarity] or 1
    
    local substats = {}
    local pool = {"Damage", "HP", "AttackSpeed", "CritChance", "CritDmg", "Range"}
    for i = 1, RelicSystem.SubstatCount[rarity] or 1 do
        if #pool > 0 then
            local idx = math.random(#pool)
            substats[pool[idx]] = 5 * mult * 0.5
            table.remove(pool, idx)
        end
    end
    
    return {
        ID = game:GetService("HttpService"):GenerateGUID(false),
        Slot = slot, Rarity = rarity, Set = setName,
        MainStat = mainStat, MainValue = 10 * mult,
        Substats = substats,
    }
end

function RelicSystem.Calculate(equippedRelics)
    local bonuses, setCounts = {}, {}
    for slot, relic in pairs(equippedRelics) do
        bonuses[relic.MainStat] = (bonuses[relic.MainStat] or 0) + relic.MainValue
        for stat, val in pairs(relic.Substats) do
            bonuses[stat] = (bonuses[stat] or 0) + val
        end
        if relic.Set then setCounts[relic.Set] = (setCounts[relic.Set] or 0) + 1 end
    end
    
    for set, count in pairs(setCounts) do
        for threshold, bonus in pairs(RelicSystem.Sets[set] or {}) do
            if count >= threshold then
                for stat, val in pairs(bonus) do bonuses[stat] = (bonuses[stat] or 0) + val end
            end
        end
    end
    return bonuses
end

return RelicSystem
```

| Risk | Mitigation |
|------|------------|
| Inventory bloat | Limit 100 relics, bulk sell |
| Complexity | Auto-equip button |
| Power creep | Cap +100% per stat |

---

## Testing Checklist

- [ ] ColorType: All 7 types work, multipliers correct
- [ ] Tags: Synergy calculates correctly, map bonus applies
- [ ] Evolution: XP awards, stage transitions, model changes
- [ ] Abilities: Cooldowns enforce, VFX trigger, damage applies
- [ ] Passives: Auras buff range, on-hit triggers
- [ ] Traits: Generate based on rarity, bonuses apply
- [ ] Relics: Equip/unequip works, set bonuses calculate
- [ ] Migration: Old data converts without loss

---

**Next:** Chunk 2 will cover Gacha & Summoning + Progression Systems.
