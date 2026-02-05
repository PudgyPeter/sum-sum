# Anime TD Comprehensive Feature Implementation Plan

Detailed implementation guide for 150+ features with code blocks, risks, and mitigations.

---

## Part 1: Core Unit Systems

### 1.1 Color Type System ⭐
**File:** `ReplicatedStorage/Modules/ColorTypeSystem.lua`

```lua
local ColorTypeSystem = {}

ColorTypeSystem.Types = {
    RED = {Color = Color3.fromRGB(255, 50, 50), StrongAgainst = "YEL", WeakAgainst = "BLU"},
    YEL = {Color = Color3.fromRGB(255, 220, 50), StrongAgainst = "PUR", WeakAgainst = "RED"},
    PUR = {Color = Color3.fromRGB(180, 80, 255), StrongAgainst = "GRN", WeakAgainst = "YEL"},
    GRN = {Color = Color3.fromRGB(80, 220, 80), StrongAgainst = "BLU", WeakAgainst = "PUR"},
    BLU = {Color = Color3.fromRGB(80, 150, 255), StrongAgainst = "RED", WeakAgainst = "GRN"},
    LIGHT = {Color = Color3.fromRGB(255, 255, 200), StrongAgainst = "DARK", WeakAgainst = "DARK"},
    DARK = {Color = Color3.fromRGB(60, 40, 80), StrongAgainst = "LIGHT", WeakAgainst = "LIGHT"},
}

ColorTypeSystem.Multipliers = {Advantage = 1.3, Disadvantage = 0.7, Neutral = 1.0}

function ColorTypeSystem.GetDamageMultiplier(attackerType, defenderType)
    local attacker = ColorTypeSystem.Types[attackerType]
    if not attacker then return 1.0 end
    if attacker.StrongAgainst == defenderType then return 1.3 end
    if attacker.WeakAgainst == defenderType then return 0.7 end
    return 1.0
end
return ColorTypeSystem
```

**Integration in Tower.Attack:**
```lua
local typeMultiplier = ColorTypeSystem.GetDamageMultiplier(
    config:FindFirstChild("ColorType") and config.ColorType.Value,
    target:FindFirstChild("ColorType") and target.ColorType.Value
)
damageAmount = damageAmount * typeMultiplier
```

| Risk | Mitigation |
|------|------------|
| Performance on every attack | Cache type lookup on tower spawn |
| Existing data lacks ColorType | Migration script assigns defaults |
| Player confusion | Color indicators + tutorial |

---

### 1.2 Unit Tags System ⭐
**File:** `ReplicatedStorage/Modules/TagSystem.lua`

```lua
local TagSystem = {}
TagSystem.Categories = {
    ANIME = {"OnePiece", "Naruto", "DragonBall", "Bleach", "JJK"},
    FACTION = {"StrawHat", "Akatsuki", "Saiyan", "Marine"},
    ROLE = {"Captain", "Swordsman", "Support", "Tank", "Assassin"},
}
TagSystem.MapBuffs = {
    GrandLine = {Tags = {"OnePiece"}, DamageBonus = 0.20},
}
TagSystem.SynergyThreshold = 3
TagSystem.SynergyBonus = 0.15 -- 3+ same-category tags

function TagSystem.CalculateMapBonus(unitTags, mapId)
    local buff = TagSystem.MapBuffs[mapId]
    if not buff then return 0 end
    for _, tag in ipairs(unitTags) do
        for _, buffTag in ipairs(buff.Tags) do
            if tag == buffTag then return buff.DamageBonus end
        end
    end
    return 0
end
return TagSystem
```

| Risk | Mitigation |
|------|------------|
| Tag explosion | Limit 5 tags/unit, use enums |
| OP combos | Cap synergy at +50% total |
| Typos | Validate against TagSystem.Categories |

---

### 1.3 Unit Evolution & XP System ⭐
**File:** `ReplicatedStorage/Modules/EvolutionSystem.lua`

```lua
local EvolutionSystem = {}
EvolutionSystem.XPGain = {PerMobKill = 1, PerBossKill = 10, PerWaveComplete = 50, PerActComplete = 500}

EvolutionSystem.Data = {
    ["Luffy"] = {
        [0] = {Name = "East Blue Luffy", XP = 0, StatMult = 1.0},
        [1] = {Name = "Gear 2 Luffy", XP = 1000, StatMult = 1.25},
        [2] = {Name = "Haki Luffy", XP = 5000, StatMult = 1.5},
        [3] = {Name = "Gear 4 Luffy", XP = 15000, StatMult = 2.0},
        [4] = {Name = "Gear 5 Nika", RequiresTrial = true, StatMult = 3.0},
    },
}

function EvolutionSystem.GetStage(unitId, xp)
    local data = EvolutionSystem.Data[unitId]
    if not data then return 0 end
    local stage = 0
    for s, d in pairs(data) do
        if type(s) == "number" and not d.RequiresTrial and xp >= d.XP and s > stage then
            stage = s
        end
    end
    return stage
end
return EvolutionSystem
```

**PlayerData Schema Addition:**
```lua
UnitInstances = {
    ["uuid-1234"] = {UnitId = "Luffy", XP = 0, EvolutionStage = 0, Traits = {}, Relics = {}},
}
```

| Risk | Mitigation |
|------|------------|
| Data migration | Convert flat inventory on load |
| Save size bloat | Compress, chunk DataStore |
| XP spam | Batch at wave end |

---

### 1.4-1.5 Active Abilities
**File:** `ReplicatedStorage/Modules/AbilitySystem.lua`

```lua
local AbilitySystem = {}
local cooldowns = {}

AbilitySystem.Abilities = {
    KingKongGun = {Cooldown = 60, Type = "Damage", Execute = function(tower, target)
        target.Humanoid:TakeDamage(tower.Config.Damage.Value * 10)
    end},
    ConquerorsHaki = {Cooldown = 45, Type = "AOE", Range = 30, Execute = function(tower)
        for _, mob in ipairs(workspace.Mobs:GetChildren()) do
            local dist = (mob.HumanoidRootPart.Position - tower.HumanoidRootPart.Position).Magnitude
            if dist <= 30 then StatusEffects.Apply(mob, "Stun", 3) end
        end
    end},
}

function AbilitySystem.Use(tower, abilityName, target)
    local ability = AbilitySystem.Abilities[abilityName]
    if not ability then return false end
    local cd = cooldowns[tower] and cooldowns[tower][abilityName]
    if cd and tick() - cd < ability.Cooldown then return false end
    ability.Execute(tower, target)
    cooldowns[tower] = cooldowns[tower] or {}
    cooldowns[tower][abilityName] = tick()
    return true
end
return AbilitySystem
```

| Risk | Mitigation |
|------|------------|
| Exploit spam | Server-side cooldowns + rate limit |
| Client desync | Sync cooldown state after use |
| Memory leak | Clean cooldowns on tower destroy |

---

### 1.6-1.7 Passives & Traits
**File:** `ReplicatedStorage/Modules/TraitSystem.lua`

```lua
local TraitSystem = {}
TraitSystem.Traits = {
    Berserker = {Effects = {DamageBonus = 0.30, DefenseBonus = -0.20}},
    Precision = {Effects = {CritChanceBonus = 15}},
    Swift = {Effects = {AttackSpeedBonus = 0.15}},
    FarSight = {Effects = {RangeBonus = 0.20}},
}
TraitSystem.CountByRarity = {Common = {0,1}, Rare = {1,1}, Epic = {1,2}, Legendary = {1,2}, Mythic = {2,3}}

function TraitSystem.Generate(unitRarity)
    local count = math.random(table.unpack(TraitSystem.CountByRarity[unitRarity] or {0,1}))
    local traits, pool = {}, {}
    for name in pairs(TraitSystem.Traits) do table.insert(pool, name) end
    for i = 1, count do
        local idx = math.random(#pool)
        table.insert(traits, table.remove(pool, idx))
    end
    return traits
end
return TraitSystem
```

---

### 1.8 Relic System
**File:** `ReplicatedStorage/Modules/RelicSystem.lua`

```lua
local RelicSystem = {}
RelicSystem.Slots = {"Weapon", "Armor", "Accessory", "Artifact"}
RelicSystem.Sets = {
    Warrior = {[2] = {Damage = 0.15}, [4] = {Damage = 0.30, ArmorPen = 0.10}},
    Swift = {[2] = {AttackSpeed = 0.10}, [4] = {AttackSpeed = 0.25}},
}

function RelicSystem.Generate(slot, rarity, setName)
    return {
        ID = game:GetService("HttpService"):GenerateGUID(false),
        Slot = slot, Rarity = rarity, Set = setName,
        MainStat = "Damage", MainValue = 10 * ({Common=1,Rare=1.25,Epic=1.5,Legendary=2})[rarity],
        Substats = {CritChance = 3},
    }
end
return RelicSystem
```

---

## Part 2: Gacha & Summoning

### 2.1-2.6 Banner & Pity System
**File:** `lobby/ServerScriptService/Lobby/BannerSystem.lua`

```lua
local BannerSystem = {}
BannerSystem.Banners = {
    Standard = {Permanent = true},
    Featured = {RotationDays = 14, FeaturedRateUp = 0.50},
    Beginner = {MaxPulls = 20, Discount = 0.20, GuaranteedLegendaryAt = 10},
    StepUp = {Steps = {{Cost=300},{Cost=400},{Cost=450},{Cost=450},{Cost=500},{Cost=0}}},
}
BannerSystem.Pity = {
    SoftPity = {Legendary = 40, Mythic = 75}, -- Rates increase after
    HardPity = {Legendary = 50, Mythic = 100}, -- Guaranteed
    FiftyFifty = true, GuaranteedAfterLoss = true,
}
BannerSystem.Spark = {TokensPerPull = 1, ExchangeAt = 200}

function BannerSystem.GetRate(player, bannerType, rarity, pityCount)
    local baseRates = {Common=0.45, Uncommon=0.30, Rare=0.15, Epic=0.07, Legendary=0.025, Mythic=0.005}
    local rate = baseRates[rarity]
    local soft = BannerSystem.Pity.SoftPity[rarity]
    if soft and pityCount >= soft then rate = rate + (pityCount - soft) * 0.02 end
    if pityCount >= (BannerSystem.Pity.HardPity[rarity] or 999) - 1 then rate = 1.0 end
    return math.min(rate, 1.0)
end
return BannerSystem
```

| Risk | Mitigation |
|------|------------|
| Pity desync | Store pity server-side only |
| 50/50 confusion | Clear UI showing guarantee state |
| Spark exploit | Validate token count server-side |

---

## Part 3: Progression Systems

### 3.1-3.2 Account Level & Skill Tree
**File:** `ReplicatedStorage/Modules/SkillTreeSystem.lua`

```lua
local SkillTree = {}
SkillTree.Categories = {
    Combat = {
        DamageBoost = {MaxLevel = 40, BonusPerLevel = 0.01},
        CritMaster = {MaxLevel = 20, BonusPerLevel = 0.005},
    },
    Economy = {
        GoldRush = {MaxLevel = 25, BonusPerLevel = 0.02},
        StartingBonus = {MaxLevel = 20, BonusPerLevel = 50},
    },
    Utility = {
        TowerLimit = {MaxLevel = 5, BonusPerLevel = 1},
        CooldownReduce = {MaxLevel = 30, BonusPerLevel = 0.01},
    },
}

function SkillTree.GetBonus(playerSkills, category, skill)
    local level = playerSkills[category] and playerSkills[category][skill] or 0
    local config = SkillTree.Categories[category] and SkillTree.Categories[category][skill]
    if not config then return 0 end
    return level * config.BonusPerLevel
end
return SkillTree
```

### 3.3-3.6 Achievements & Daily Rewards
**Schema additions to PlayerData:**
```lua
Achievements = {},
DailyLoginStreak = 0,
LastLoginDate = "",
DailyMissions = {},
WeeklyMissions = {},
```

---

## Part 4: Game Modes

### 4.1-4.2 Story & Infinite Mode
**Infinite Mode in Round.lua:**
```lua
function round.GetInfiniteWave(waveNumber, map)
    local hpScale = 1 + (waveNumber * 0.05)
    local speedScale = 1 + (waveNumber * 0.03)
    local count = math.floor(5 + waveNumber * 1.5)
    
    local mobTypes = {"PudgePete", "CurioussGorge", "illxstrate"}
    for _, mobName in ipairs(mobTypes) do
        mob.SpawnScaled(mobName, count, map, hpScale, speedScale)
    end
    if waveNumber % 10 == 0 then
        mob.SpawnBoss(math.floor(waveNumber / 10), map)
    end
end
```

### 4.3 Raids
**File:** `ServerScriptService/RaidSystem.lua`

```lua
local RaidSystem = {}
RaidSystem.Bosses = {
    Kaido = {
        Phases = {
            {HP = 0.66, Name = "Ground", Mechanics = {"ThunderBagua"}},
            {HP = 0.33, Name = "Flying", RangedOnly = true},
            {HP = 0, Name = "Enraged", DamageMult = 2},
        },
        BaseHP = 1000000,
        Reward = 5000,
    },
}
return RaidSystem
```

---

## Part 5-6: Social & Economy

### Trading System
```lua
local TradingSystem = {}
TradingSystem.Config = {
    MinAccountLevel = 5,
    TradeCooldown = 86400, -- 24 hours on traded units
    TaxPercent = 0.10,
}

function TradingSystem.CreateTrade(player1, player2, offer1, offer2)
    -- Validate ownership, cooldowns, restrictions
    -- Create pending trade record
    -- Both players must confirm
end
return TradingSystem
```

### Guild System
```lua
local GuildSystem = {}
GuildSystem.Config = {
    MaxMembers = 50,
    Ranks = {"Leader", "Officer", "Elite", "Member", "Recruit"},
    Perks = {XPBoost = 0.10, GemBonus = 0.05},
}
return GuildSystem
```

---

## Part 7-8: Events & Monetization

### Battle Pass
```lua
local BattlePass = {}
BattlePass.Tiers = 50
BattlePass.SeasonWeeks = 8
BattlePass.PremiumCost = 500 -- Robux

BattlePass.Rewards = {
    [1] = {Free = {Gems = 50}, Premium = {Skin = "Exclusive1"}},
    [50] = {Free = {Title = "Season 1"}, Premium = {Unit = "LimitedMythic"}},
}
return BattlePass
```

### Game Passes
```lua
local GamePasses = {
    VIP = {Price = 499, Benefits = {GemBonus = 0.25, ExclusiveBadge = true}},
    AutoStart = {Price = 99, Benefits = {AutoWaveToggle = true}},
    DoubleXP = {Price = 199, Benefits = {XPMultiplier = 2}},
}
```

---

## Part 9-10: QoL & Polish

### Speed Controls
```lua
-- GameSpeed.lua update
GameSpeed.Options = {1, 2, 3}
GameSpeed.Current = 1

function GameSpeed.SetSpeed(speed)
    if table.find(GameSpeed.Options, speed) then
        GameSpeed.Current = speed
        -- Update all mobs, towers, timers
    end
end
```

### Damage Numbers
```lua
-- Client-side DamageIndicator.lua
local function ShowDamage(position, amount, isCrit)
    local billboard = Instance.new("BillboardGui")
    local label = Instance.new("TextLabel")
    label.Text = tostring(amount)
    label.TextColor3 = isCrit and Color3.new(1,1,0) or Color3.new(1,1,1)
    label.TextSize = isCrit and 24 or 18
    -- Tween up and fade
end
```

---

## Part 11-12: Technical & Refactoring

### Code Consolidation
1. **Merge duplicate files:** PlayerDataManager.lua (lobby vs maps)
2. **Split Tower.lua:** TowerCore, TowerCombat, TowerUpgrades, TowerAbilities
3. **Data-driven waves:** Move Round.lua definitions to WaveData.lua
4. **Replace spawn() with task.spawn()**

### Anti-Cheat
```lua
local AntiCheat = {}

function AntiCheat.ValidateDamage(tower, target, claimed)
    local maxPossible = tower.Config.Damage.Value * 2 -- Account for crits/buffs
    if claimed > maxPossible then
        warn("Suspicious damage from", tower.Name)
        return false
    end
    return true
end
return AntiCheat
```

---

## Part 13-15: BTD6 & Arknights Features

### Paragon System (BTD6)
```lua
-- Sacrifice 3 max-tier towers to create Paragon
function Tower.CreateParagon(player, sacrificeTowers)
    local totalValue = 0
    for _, t in ipairs(sacrificeTowers) do
        totalValue = totalValue + t.Config.TotalInvested.Value
    end
    local degree = math.min(100, math.floor(totalValue / 1000))
    -- Create Paragon with degree-based stats
end
```

### DP System (Arknights)
```lua
local DPSystem = {}
DPSystem.StartingDP = 10
DPSystem.RegenRate = 1 -- per second
DPSystem.CostByRarity = {Common = 5, Rare = 10, Epic = 15, Legendary = 25, Mythic = 35}

function DPSystem.CanDeploy(player, unitRarity)
    return player.DP.Value >= DPSystem.CostByRarity[unitRarity]
end
```

### Roguelike Mode (Arknights IS)
```lua
local RoguelikeSystem = {}
RoguelikeSystem.NodeTypes = {"Combat", "Elite", "Boss", "Recruitment", "Shop", "Rest", "Event"}

function RoguelikeSystem.StartRun(player)
    return {
        Squad = {}, -- Start empty, recruit units
        Relics = {}, -- Run-specific buffs
        CurrentNode = 1,
        HP = 3, -- Lives remaining
    }
end
```

---

## Implementation Priority

| Phase | Duration | Features |
|-------|----------|----------|
| 1 Foundation | 2-3 weeks | Code refactor, Color Types, Tags, Evolution |
| 2 Core | 4-6 weeks | Pity system, Abilities, Skill Tree, Achievements |
| 3 Content | 4-6 weeks | Infinite Mode, Raids, Trials, Battle Pass |
| 4 Social | 2-3 weeks | Trading, Guilds, Friends, Leaderboards |
| 5 Polish | Ongoing | VFX, Audio, QoL, Events |

---

## Key Risk Summary

| Category | Top Risks | Mitigation Strategy |
|----------|-----------|---------------------|
| Data | Schema changes break saves | Version migrations, backwards compat |
| Performance | Too many systems per frame | Batch updates, caching, LOD |
| Balance | Power creep from stacking | Hard caps on all bonuses |
| Exploits | Client manipulation | Server-side validation for everything |
| UX | Feature overload | Progressive unlock, good tutorials |

---

**Ready for review.** Confirm which features to prioritize and I'll begin implementation.
