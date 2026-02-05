# Chunk 2: Gacha & Summoning + Progression Systems Implementation Plan

Full implementation details for summoning mechanics, banner systems, pity, and progression features.

---

## File Index (New Files to Create)

| File Path | Purpose |
|-----------|---------|
| `ReplicatedStorage/Modules/GachaSystem.lua` | Core gacha logic and rates |
| `ReplicatedStorage/Modules/BannerSystem.lua` | Banner management and rotation |
| `ReplicatedStorage/Modules/PitySystem.lua` | Pity counter and guarantee logic |
| `ReplicatedStorage/Modules/SummonVFX.lua` | Client summoning visuals |
| `ReplicatedStorage/Modules/DuplicateSystem.lua` | Dupe conversion and shards |
| `ReplicatedStorage/Modules/MasterySystem.lua` | Unit mastery progression |
| `ReplicatedStorage/Modules/AccountLevelSystem.lua` | Player account progression |
| `ReplicatedStorage/Modules/AchievementSystem.lua` | Achievement tracking |
| `ServerScriptService/Services/GachaService.lua` | Server-side gacha handler |
| `StarterPlayerScripts/SummonUI.lua` | Client summon interface |

---

## 2.1 Core Gacha System

### GachaSystem.lua

```lua
local GachaSystem = {}

-- Rarity definitions with base rates
GachaSystem.Rarities = {
    COMMON = {Weight = 5000, Color = Color3.fromRGB(180, 180, 180), Stars = 1},
    UNCOMMON = {Weight = 3000, Color = Color3.fromRGB(100, 200, 100), Stars = 2},
    RARE = {Weight = 1500, Color = Color3.fromRGB(80, 150, 255), Stars = 3},
    EPIC = {Weight = 400, Color = Color3.fromRGB(200, 80, 255), Stars = 4},
    LEGENDARY = {Weight = 95, Color = Color3.fromRGB(255, 200, 50), Stars = 5},
    MYTHIC = {Weight = 5, Color = Color3.fromRGB(255, 100, 100), Stars = 6},
}

-- Calculate total weight for normalization
local totalWeight = 0
for _, data in pairs(GachaSystem.Rarities) do
    totalWeight = totalWeight + data.Weight
end
GachaSystem.TotalWeight = totalWeight

-- Unit pools by rarity (populated from TowerData)
GachaSystem.Pools = {
    COMMON = {},
    UNCOMMON = {},
    RARE = {},
    EPIC = {},
    LEGENDARY = {},
    MYTHIC = {},
}

function GachaSystem.Initialize(TowerData)
    for unitName, data in pairs(TowerData) do
        local rarity = data.Rarity or "COMMON"
        if GachaSystem.Pools[rarity] then
            table.insert(GachaSystem.Pools[rarity], unitName)
        end
    end
end

function GachaSystem.RollRarity(rng, rateBoosts)
    rateBoosts = rateBoosts or {}
    local roll = rng:NextNumber() * GachaSystem.TotalWeight
    local cumulative = 0
    
    for rarity, data in pairs(GachaSystem.Rarities) do
        local boostedWeight = data.Weight * (rateBoosts[rarity] or 1)
        cumulative = cumulative + boostedWeight
        if roll <= cumulative then
            return rarity
        end
    end
    return "COMMON"
end

function GachaSystem.RollUnit(rng, rarity, bannedUnits, rateUpUnits)
    local pool = GachaSystem.Pools[rarity]
    if not pool or #pool == 0 then return nil end
    
    -- Filter banned units
    local available = {}
    for _, unit in ipairs(pool) do
        if not bannedUnits or not bannedUnits[unit] then
            table.insert(available, unit)
        end
    end
    
    if #available == 0 then return nil end
    
    -- Rate-up check (50% chance to get rate-up unit if applicable)
    if rateUpUnits and #rateUpUnits > 0 then
        local rateUpInPool = {}
        for _, unit in ipairs(rateUpUnits) do
            for _, avail in ipairs(available) do
                if avail == unit then
                    table.insert(rateUpInPool, unit)
                    break
                end
            end
        end
        
        if #rateUpInPool > 0 and rng:NextNumber() < 0.5 then
            return rateUpInPool[rng:NextInteger(1, #rateUpInPool)]
        end
    end
    
    return available[rng:NextInteger(1, #available)]
end

function GachaSystem.PerformSummon(playerData, bannerData, count)
    local results = {}
    local rng = Random.new()
    
    for i = 1, count do
        local rarity = GachaSystem.RollRarity(rng, bannerData.RateBoosts)
        local unit = GachaSystem.RollUnit(rng, rarity, bannerData.BannedUnits, bannerData.RateUpUnits)
        
        if unit then
            table.insert(results, {
                UnitName = unit,
                Rarity = rarity,
                IsNew = not playerData.OwnedUnits[unit],
                IsRateUp = bannerData.RateUpUnits and table.find(bannerData.RateUpUnits, unit) ~= nil,
            })
        end
    end
    
    return results
end

return GachaSystem
```

---

## 2.2 Banner System

### BannerSystem.lua

```lua
local BannerSystem = {}

BannerSystem.BannerTypes = {
    STANDARD = {Name = "Standard", CostType = "Gems", Cost = 100, Multi = 1000},
    LIMITED = {Name = "Limited", CostType = "Gems", Cost = 150, Multi = 1350},
    COLLAB = {Name = "Collaboration", CostType = "Gems", Cost = 150, Multi = 1350},
    BEGINNER = {Name = "Beginner", CostType = "Gems", Cost = 50, Multi = 450, MaxPulls = 50},
    FRIEND = {Name = "Friendship", CostType = "FriendPoints", Cost = 200, Multi = 2000},
    TICKET = {Name = "Ticket", CostType = "SummonTicket", Cost = 1, Multi = 10},
}

BannerSystem.ActiveBanners = {}

function BannerSystem.CreateBanner(config)
    local banner = {
        Id = config.Id or game:GetService("HttpService"):GenerateGUID(false),
        Type = config.Type or "STANDARD",
        Name = config.Name or "Standard Banner",
        Description = config.Description or "",
        StartTime = config.StartTime or os.time(),
        EndTime = config.EndTime or (os.time() + 604800), -- 1 week default
        RateUpUnits = config.RateUpUnits or {},
        RateBoosts = config.RateBoosts or {},
        BannedUnits = config.BannedUnits or {},
        PityType = config.PityType or "STANDARD",
        GuaranteedRarity = config.GuaranteedRarity, -- For 10-pull guarantee
        ImageId = config.ImageId or "",
    }
    
    BannerSystem.ActiveBanners[banner.Id] = banner
    return banner
end

function BannerSystem.GetActiveBanners()
    local now = os.time()
    local active = {}
    
    for id, banner in pairs(BannerSystem.ActiveBanners) do
        if banner.StartTime <= now and banner.EndTime > now then
            table.insert(active, banner)
        end
    end
    
    -- Sort by type priority
    table.sort(active, function(a, b)
        local priority = {LIMITED = 1, COLLAB = 2, BEGINNER = 3, STANDARD = 4, FRIEND = 5, TICKET = 6}
        return (priority[a.Type] or 99) < (priority[b.Type] or 99)
    end)
    
    return active
end

function BannerSystem.GetBanner(bannerId)
    return BannerSystem.ActiveBanners[bannerId]
end

function BannerSystem.GetCost(banner, isMulti)
    local typeData = BannerSystem.BannerTypes[banner.Type]
    if not typeData then return nil, nil end
    
    return typeData.CostType, isMulti and typeData.Multi or typeData.Cost
end

function BannerSystem.CanPull(playerData, banner, isMulti)
    local costType, cost = BannerSystem.GetCost(banner, isMulti)
    if not costType then return false, "Invalid banner" end
    
    -- Check beginner banner limit
    if banner.Type == "BEGINNER" then
        local pulls = playerData.BannerPulls and playerData.BannerPulls[banner.Id] or 0
        local maxPulls = BannerSystem.BannerTypes.BEGINNER.MaxPulls
        if pulls >= maxPulls then
            return false, "Beginner banner limit reached"
        end
    end
    
    -- Check currency
    local currency = playerData[costType] or 0
    if currency < cost then
        return false, "Insufficient " .. costType
    end
    
    return true, nil
end

function BannerSystem.GetTimeRemaining(banner)
    local remaining = banner.EndTime - os.time()
    if remaining <= 0 then return "Ended" end
    
    local days = math.floor(remaining / 86400)
    local hours = math.floor((remaining % 86400) / 3600)
    local mins = math.floor((remaining % 3600) / 60)
    
    if days > 0 then
        return string.format("%dd %dh", days, hours)
    elseif hours > 0 then
        return string.format("%dh %dm", hours, mins)
    else
        return string.format("%dm", mins)
    end
end

return BannerSystem
```

---

## 2.3 Pity System

### PitySystem.lua

```lua
local PitySystem = {}

PitySystem.Config = {
    STANDARD = {
        SoftPityStart = 75,
        HardPity = 90,
        SoftPityRateIncrease = 0.06, -- +6% per pull after soft pity
        GuaranteedRarity = "LEGENDARY",
    },
    LIMITED = {
        SoftPityStart = 65,
        HardPity = 80,
        SoftPityRateIncrease = 0.08,
        GuaranteedRarity = "LEGENDARY",
        FeaturedGuarantee = true, -- 50/50 then guaranteed
    },
    EPIC = {
        SoftPityStart = 8,
        HardPity = 10,
        SoftPityRateIncrease = 0.15,
        GuaranteedRarity = "EPIC",
    },
}

function PitySystem.GetPityData(playerData, bannerId, pityType)
    playerData.Pity = playerData.Pity or {}
    playerData.Pity[bannerId] = playerData.Pity[bannerId] or {
        Counter = 0,
        LostFeatured = false, -- For 50/50 system
        EpicCounter = 0,
    }
    return playerData.Pity[bannerId]
end

function PitySystem.CalculateRateBoost(pityData, pityType)
    local config = PitySystem.Config[pityType]
    if not config then return {} end
    
    local boosts = {}
    local counter = pityData.Counter
    
    -- Soft pity calculation
    if counter >= config.SoftPityStart then
        local pullsIntoPity = counter - config.SoftPityStart + 1
        local boost = 1 + (pullsIntoPity * config.SoftPityRateIncrease)
        boosts[config.GuaranteedRarity] = boost
    end
    
    -- Epic pity for 10-pull guarantee
    if pityData.EpicCounter >= (PitySystem.Config.EPIC.SoftPityStart or 8) then
        boosts["EPIC"] = boosts["EPIC"] or 1
        boosts["EPIC"] = boosts["EPIC"] * 2
    end
    
    return boosts
end

function PitySystem.CheckHardPity(pityData, pityType)
    local config = PitySystem.Config[pityType]
    if not config then return false end
    
    return pityData.Counter >= config.HardPity
end

function PitySystem.ProcessPull(pityData, pityType, resultRarity, isFeatured)
    local config = PitySystem.Config[pityType]
    if not config then return end
    
    pityData.Counter = pityData.Counter + 1
    pityData.EpicCounter = pityData.EpicCounter + 1
    
    -- Reset counters on high rarity pull
    local rarityOrder = {COMMON = 1, UNCOMMON = 2, RARE = 3, EPIC = 4, LEGENDARY = 5, MYTHIC = 6}
    local guaranteedOrder = rarityOrder[config.GuaranteedRarity] or 5
    
    if rarityOrder[resultRarity] >= guaranteedOrder then
        pityData.Counter = 0
        
        -- Handle 50/50 system for limited banners
        if config.FeaturedGuarantee then
            if isFeatured then
                pityData.LostFeatured = false
            else
                pityData.LostFeatured = true
            end
        end
    end
    
    if rarityOrder[resultRarity] >= 4 then -- EPIC or higher
        pityData.EpicCounter = 0
    end
end

function PitySystem.ShouldGetFeatured(pityData, pityType)
    local config = PitySystem.Config[pityType]
    if not config or not config.FeaturedGuarantee then return false end
    
    return pityData.LostFeatured
end

function PitySystem.GetPityDisplay(pityData, pityType)
    local config = PitySystem.Config[pityType]
    if not config then return "N/A" end
    
    return string.format("%d/%d", pityData.Counter, config.HardPity)
end

return PitySystem
```

---

## 2.4 Duplicate System

### DuplicateSystem.lua

```lua
local DuplicateSystem = {}

-- Shard rewards by rarity when pulling duplicates
DuplicateSystem.ShardRewards = {
    COMMON = {Shards = 5, UniversalShards = 0},
    UNCOMMON = {Shards = 10, UniversalShards = 1},
    RARE = {Shards = 25, UniversalShards = 3},
    EPIC = {Shards = 50, UniversalShards = 10},
    LEGENDARY = {Shards = 100, UniversalShards = 25},
    MYTHIC = {Shards = 200, UniversalShards = 50},
}

-- Shards needed to unlock/upgrade
DuplicateSystem.UnlockCosts = {
    COMMON = 50,
    UNCOMMON = 100,
    RARE = 200,
    EPIC = 400,
    LEGENDARY = 800,
    MYTHIC = 1600,
}

-- Constellation/dupe bonus unlocks
DuplicateSystem.ConstellationBonuses = {
    [1] = {Type = "STAT", Stat = "Damage", Value = 0.05},
    [2] = {Type = "SKILL", SkillId = "Enhanced1"},
    [3] = {Type = "STAT", Stat = "AttackSpeed", Value = 0.08},
    [4] = {Type = "SKILL", SkillId = "Enhanced2"},
    [5] = {Type = "STAT", Stat = "Range", Value = 0.10},
    [6] = {Type = "SKILL", SkillId = "Ultimate"},
}

function DuplicateSystem.ProcessDuplicate(playerData, unitName, rarity)
    local rewards = DuplicateSystem.ShardRewards[rarity]
    if not rewards then return nil end
    
    -- Initialize shard storage
    playerData.UnitShards = playerData.UnitShards or {}
    playerData.UnitShards[unitName] = (playerData.UnitShards[unitName] or 0) + rewards.Shards
    playerData.UniversalShards = (playerData.UniversalShards or 0) + rewards.UniversalShards
    
    -- Track constellation level
    playerData.Constellations = playerData.Constellations or {}
    local currentConstellation = playerData.Constellations[unitName] or 0
    
    -- Auto-upgrade constellation if enough dupes
    if currentConstellation < 6 then
        playerData.Constellations[unitName] = currentConstellation + 1
        return {
            Type = "CONSTELLATION_UP",
            UnitName = unitName,
            NewLevel = currentConstellation + 1,
            Bonus = DuplicateSystem.ConstellationBonuses[currentConstellation + 1],
            ShardsGained = rewards.Shards,
            UniversalShardsGained = rewards.UniversalShards,
        }
    end
    
    return {
        Type = "SHARDS_ONLY",
        UnitName = unitName,
        ShardsGained = rewards.Shards,
        UniversalShardsGained = rewards.UniversalShards,
    }
end

function DuplicateSystem.CanUnlockWithShards(playerData, unitName, rarity)
    local cost = DuplicateSystem.UnlockCosts[rarity]
    if not cost then return false end
    
    local shards = playerData.UnitShards and playerData.UnitShards[unitName] or 0
    local universal = playerData.UniversalShards or 0
    
    return (shards + universal) >= cost
end

function DuplicateSystem.UnlockWithShards(playerData, unitName, rarity)
    local cost = DuplicateSystem.UnlockCosts[rarity]
    if not DuplicateSystem.CanUnlockWithShards(playerData, unitName, rarity) then
        return false, "Insufficient shards"
    end
    
    local shards = playerData.UnitShards and playerData.UnitShards[unitName] or 0
    local fromUnit = math.min(shards, cost)
    local fromUniversal = cost - fromUnit
    
    playerData.UnitShards[unitName] = shards - fromUnit
    playerData.UniversalShards = (playerData.UniversalShards or 0) - fromUniversal
    
    return true, nil
end

function DuplicateSystem.GetConstellationBonus(unitName, constellationLevel)
    if constellationLevel < 1 or constellationLevel > 6 then return nil end
    return DuplicateSystem.ConstellationBonuses[constellationLevel]
end

function DuplicateSystem.CalculateTotalStatBonus(constellationLevel)
    local bonuses = {Damage = 0, AttackSpeed = 0, Range = 0}
    
    for i = 1, math.min(constellationLevel, 6) do
        local bonus = DuplicateSystem.ConstellationBonuses[i]
        if bonus and bonus.Type == "STAT" then
            bonuses[bonus.Stat] = (bonuses[bonus.Stat] or 0) + bonus.Value
        end
    end
    
    return bonuses
end

return DuplicateSystem
```

---

## 2.5 Mastery System

### MasterySystem.lua

```lua
local MasterySystem = {}

-- Mastery XP requirements per level
MasterySystem.LevelRequirements = {}
for i = 1, 50 do
    MasterySystem.LevelRequirements[i] = math.floor(100 * (1.15 ^ (i - 1)))
end

-- XP sources
MasterySystem.XPSources = {
    WAVE_CLEAR = 10,
    ELITE_KILL = 25,
    BOSS_KILL = 100,
    MISSION_COMPLETE = 50,
    DAILY_USE = 200, -- First use of day
}

-- Mastery rewards per milestone
MasterySystem.Rewards = {
    [5] = {Type = "SKIN", SkinId = "Mastery1"},
    [10] = {Type = "STAT", Stat = "Damage", Value = 0.02},
    [15] = {Type = "ABILITY", AbilityId = "MasterySkill1"},
    [20] = {Type = "STAT", Stat = "AttackSpeed", Value = 0.03},
    [25] = {Type = "TITLE", TitleId = "Apprentice"},
    [30] = {Type = "SKIN", SkinId = "Mastery2"},
    [35] = {Type = "STAT", Stat = "Range", Value = 0.05},
    [40] = {Type = "ABILITY", AbilityId = "MasterySkill2"},
    [45] = {Type = "TITLE", TitleId = "Master"},
    [50] = {Type = "SKIN", SkinId = "MasteryMax"},
}

function MasterySystem.GetMasteryData(playerData, unitName)
    playerData.Mastery = playerData.Mastery or {}
    playerData.Mastery[unitName] = playerData.Mastery[unitName] or {
        Level = 1,
        XP = 0,
        TotalXP = 0,
    }
    return playerData.Mastery[unitName]
end

function MasterySystem.AddXP(playerData, unitName, source)
    local mastery = MasterySystem.GetMasteryData(playerData, unitName)
    local xpAmount = MasterySystem.XPSources[source] or 0
    
    if mastery.Level >= 50 then return nil end -- Max level
    
    mastery.XP = mastery.XP + xpAmount
    mastery.TotalXP = mastery.TotalXP + xpAmount
    
    local levelUps = {}
    
    -- Check for level ups
    while mastery.Level < 50 do
        local required = MasterySystem.LevelRequirements[mastery.Level]
        if mastery.XP >= required then
            mastery.XP = mastery.XP - required
            mastery.Level = mastery.Level + 1
            
            local reward = MasterySystem.Rewards[mastery.Level]
            table.insert(levelUps, {
                NewLevel = mastery.Level,
                Reward = reward,
            })
        else
            break
        end
    end
    
    return levelUps
end

function MasterySystem.GetProgress(playerData, unitName)
    local mastery = MasterySystem.GetMasteryData(playerData, unitName)
    
    if mastery.Level >= 50 then
        return {Level = 50, Progress = 1, XP = 0, Required = 0, IsMax = true}
    end
    
    local required = MasterySystem.LevelRequirements[mastery.Level]
    return {
        Level = mastery.Level,
        Progress = mastery.XP / required,
        XP = mastery.XP,
        Required = required,
        IsMax = false,
    }
end

function MasterySystem.GetTotalStatBonuses(playerData, unitName)
    local mastery = MasterySystem.GetMasteryData(playerData, unitName)
    local bonuses = {}
    
    for level, reward in pairs(MasterySystem.Rewards) do
        if mastery.Level >= level and reward.Type == "STAT" then
            bonuses[reward.Stat] = (bonuses[reward.Stat] or 0) + reward.Value
        end
    end
    
    return bonuses
end

function MasterySystem.GetUnlockedAbilities(playerData, unitName)
    local mastery = MasterySystem.GetMasteryData(playerData, unitName)
    local abilities = {}
    
    for level, reward in pairs(MasterySystem.Rewards) do
        if mastery.Level >= level and reward.Type == "ABILITY" then
            table.insert(abilities, reward.AbilityId)
        end
    end
    
    return abilities
end

return MasterySystem
```

---

## 2.6 Account Level System

### AccountLevelSystem.lua

```lua
local AccountLevelSystem = {}

-- XP requirements per level (1-100)
AccountLevelSystem.LevelRequirements = {}
for i = 1, 100 do
    AccountLevelSystem.LevelRequirements[i] = math.floor(500 * (1.08 ^ (i - 1)))
end

-- XP sources
AccountLevelSystem.XPSources = {
    MAP_CLEAR = 100,
    FIRST_CLEAR = 500,
    ACHIEVEMENT = 50,
    DAILY_LOGIN = 100,
    WEEKLY_MISSION = 200,
    EVENT_PARTICIPATION = 150,
}

-- Level unlock milestones
AccountLevelSystem.Unlocks = {
    [5] = {Type = "FEATURE", FeatureId = "GuildJoin"},
    [10] = {Type = "FEATURE", FeatureId = "PvPMode"},
    [15] = {Type = "FEATURE", FeatureId = "Expeditions"},
    [20] = {Type = "SLOTS", SlotType = "TeamSlot", Count = 1},
    [25] = {Type = "FEATURE", FeatureId = "Crafting"},
    [30] = {Type = "FEATURE", FeatureId = "WorldBoss"},
    [35] = {Type = "SLOTS", SlotType = "TeamSlot", Count = 1},
    [40] = {Type = "FEATURE", FeatureId = "Ascension"},
    [50] = {Type = "SLOTS", SlotType = "TeamSlot", Count = 1},
    [60] = {Type = "FEATURE", FeatureId = "Transcendence"},
    [75] = {Type = "TITLE", TitleId = "Veteran"},
    [100] = {Type = "TITLE", TitleId = "Legend"},
}

-- Stamina cap increases
AccountLevelSystem.StaminaCaps = {}
for i = 1, 100 do
    AccountLevelSystem.StaminaCaps[i] = 100 + (i * 2)
end

function AccountLevelSystem.GetAccountData(playerData)
    playerData.Account = playerData.Account or {
        Level = 1,
        XP = 0,
        TotalXP = 0,
    }
    return playerData.Account
end

function AccountLevelSystem.AddXP(playerData, source, multiplier)
    local account = AccountLevelSystem.GetAccountData(playerData)
    local xpAmount = (AccountLevelSystem.XPSources[source] or 0) * (multiplier or 1)
    
    if account.Level >= 100 then return nil end
    
    account.XP = account.XP + xpAmount
    account.TotalXP = account.TotalXP + xpAmount
    
    local levelUps = {}
    
    while account.Level < 100 do
        local required = AccountLevelSystem.LevelRequirements[account.Level]
        if account.XP >= required then
            account.XP = account.XP - required
            account.Level = account.Level + 1
            
            local unlock = AccountLevelSystem.Unlocks[account.Level]
            table.insert(levelUps, {
                NewLevel = account.Level,
                Unlock = unlock,
                NewStaminaCap = AccountLevelSystem.StaminaCaps[account.Level],
            })
        else
            break
        end
    end
    
    return levelUps
end

function AccountLevelSystem.GetStaminaCap(playerData)
    local account = AccountLevelSystem.GetAccountData(playerData)
    return AccountLevelSystem.StaminaCaps[account.Level] or 100
end

function AccountLevelSystem.IsFeatureUnlocked(playerData, featureId)
    local account = AccountLevelSystem.GetAccountData(playerData)
    
    for level, unlock in pairs(AccountLevelSystem.Unlocks) do
        if unlock.Type == "FEATURE" and unlock.FeatureId == featureId then
            return account.Level >= level
        end
    end
    
    return true -- Feature not gated
end

function AccountLevelSystem.GetProgress(playerData)
    local account = AccountLevelSystem.GetAccountData(playerData)
    
    if account.Level >= 100 then
        return {Level = 100, Progress = 1, IsMax = true}
    end
    
    local required = AccountLevelSystem.LevelRequirements[account.Level]
    return {
        Level = account.Level,
        Progress = account.XP / required,
        XP = account.XP,
        Required = required,
        IsMax = false,
    }
end

return AccountLevelSystem
```

---

## 2.7 Achievement System

### AchievementSystem.lua

```lua
local AchievementSystem = {}

AchievementSystem.Categories = {
    COLLECTION = "Collection",
    COMBAT = "Combat",
    PROGRESSION = "Progression",
    SOCIAL = "Social",
    SPECIAL = "Special",
}

AchievementSystem.Achievements = {
    -- Collection
    COLLECT_10 = {
        Category = "COLLECTION",
        Name = "Starter Collection",
        Description = "Own 10 different units",
        Target = 10,
        Rewards = {Gems = 100},
    },
    COLLECT_50 = {
        Category = "COLLECTION",
        Name = "Growing Army",
        Description = "Own 50 different units",
        Target = 50,
        Rewards = {Gems = 500, SummonTicket = 1},
    },
    COLLECT_LEGENDARY = {
        Category = "COLLECTION",
        Name = "Lucky Find",
        Description = "Obtain a Legendary unit",
        Target = 1,
        Rewards = {Gems = 200},
    },
    COLLECT_MYTHIC = {
        Category = "COLLECTION",
        Name = "Mythical Discovery",
        Description = "Obtain a Mythic unit",
        Target = 1,
        Rewards = {Gems = 1000},
    },
    
    -- Combat
    DEFEAT_ENEMIES_1000 = {
        Category = "COMBAT",
        Name = "Monster Slayer",
        Description = "Defeat 1,000 enemies",
        Target = 1000,
        Rewards = {Gold = 5000},
    },
    DEFEAT_ENEMIES_100000 = {
        Category = "COMBAT",
        Name = "Genocide Route",
        Description = "Defeat 100,000 enemies",
        Target = 100000,
        Rewards = {Gems = 500, Title = "Destroyer"},
    },
    DEFEAT_BOSSES_10 = {
        Category = "COMBAT",
        Name = "Boss Hunter",
        Description = "Defeat 10 bosses",
        Target = 10,
        Rewards = {Gems = 150},
    },
    
    -- Progression
    ACCOUNT_LEVEL_50 = {
        Category = "PROGRESSION",
        Name = "Dedicated Player",
        Description = "Reach Account Level 50",
        Target = 50,
        Rewards = {Gems = 500},
    },
    MAX_MASTERY = {
        Category = "PROGRESSION",
        Name = "True Master",
        Description = "Reach Mastery Level 50 with any unit",
        Target = 1,
        Rewards = {Gems = 300, Title = "Master"},
    },
    
    -- Social
    JOIN_GUILD = {
        Category = "SOCIAL",
        Name = "Team Player",
        Description = "Join a guild",
        Target = 1,
        Rewards = {Gems = 50},
    },
    ADD_FRIENDS_10 = {
        Category = "SOCIAL",
        Name = "Popular",
        Description = "Add 10 friends",
        Target = 10,
        Rewards = {Gems = 100},
    },
}

function AchievementSystem.GetAchievementData(playerData)
    playerData.Achievements = playerData.Achievements or {
        Completed = {},
        Progress = {},
    }
    return playerData.Achievements
end

function AchievementSystem.UpdateProgress(playerData, achievementId, value)
    local data = AchievementSystem.GetAchievementData(playerData)
    local achievement = AchievementSystem.Achievements[achievementId]
    
    if not achievement or data.Completed[achievementId] then
        return nil
    end
    
    data.Progress[achievementId] = (data.Progress[achievementId] or 0) + value
    
    if data.Progress[achievementId] >= achievement.Target then
        data.Completed[achievementId] = os.time()
        return {
            AchievementId = achievementId,
            Achievement = achievement,
            Rewards = achievement.Rewards,
        }
    end
    
    return nil
end

function AchievementSystem.SetProgress(playerData, achievementId, value)
    local data = AchievementSystem.GetAchievementData(playerData)
    local achievement = AchievementSystem.Achievements[achievementId]
    
    if not achievement or data.Completed[achievementId] then
        return nil
    end
    
    data.Progress[achievementId] = value
    
    if data.Progress[achievementId] >= achievement.Target then
        data.Completed[achievementId] = os.time()
        return {
            AchievementId = achievementId,
            Achievement = achievement,
            Rewards = achievement.Rewards,
        }
    end
    
    return nil
end

function AchievementSystem.GetProgress(playerData, achievementId)
    local data = AchievementSystem.GetAchievementData(playerData)
    local achievement = AchievementSystem.Achievements[achievementId]
    
    if not achievement then return nil end
    
    return {
        Progress = data.Progress[achievementId] or 0,
        Target = achievement.Target,
        IsCompleted = data.Completed[achievementId] ~= nil,
        CompletedAt = data.Completed[achievementId],
    }
end

function AchievementSystem.GetAllByCategory(category)
    local result = {}
    for id, achievement in pairs(AchievementSystem.Achievements) do
        if achievement.Category == category then
            result[id] = achievement
        end
    end
    return result
end

function AchievementSystem.GetCompletionStats(playerData)
    local data = AchievementSystem.GetAchievementData(playerData)
    local total = 0
    local completed = 0
    
    for id in pairs(AchievementSystem.Achievements) do
        total = total + 1
        if data.Completed[id] then
            completed = completed + 1
        end
    end
    
    return {Total = total, Completed = completed, Percentage = completed / total}
end

return AchievementSystem
```

---

## 2.8 Server-Side Gacha Service

### ServerScriptService/Services/GachaService.lua

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GachaSystem = require(ReplicatedStorage.Modules.GachaSystem)
local BannerSystem = require(ReplicatedStorage.Modules.BannerSystem)
local PitySystem = require(ReplicatedStorage.Modules.PitySystem)
local DuplicateSystem = require(ReplicatedStorage.Modules.DuplicateSystem)
local PlayerDataManager = require(script.Parent.Parent.PlayerDataManager)

local GachaService = {}

local SummonEvent = ReplicatedStorage.Events:WaitForChild("Summon")
local SummonResultEvent = ReplicatedStorage.Events:WaitForChild("SummonResult")

function GachaService.Initialize()
    -- Initialize gacha pools from TowerData
    local TowerData = require(ReplicatedStorage.TowerData)
    GachaSystem.Initialize(TowerData)
    
    -- Create default banners
    BannerSystem.CreateBanner({
        Id = "STANDARD_PERMANENT",
        Type = "STANDARD",
        Name = "Standard Banner",
        Description = "All units available!",
        EndTime = os.time() + 31536000, -- 1 year
    })
    
    -- Connect event
    SummonEvent.OnServerEvent:Connect(function(player, bannerId, isMulti)
        GachaService.ProcessSummon(player, bannerId, isMulti)
    end)
end

function GachaService.ProcessSummon(player, bannerId, isMulti)
    local playerData = PlayerDataManager.GetData(player)
    if not playerData then return end
    
    local banner = BannerSystem.GetBanner(bannerId)
    if not banner then
        SummonResultEvent:FireClient(player, {Success = false, Error = "Invalid banner"})
        return
    end
    
    -- Validate pull
    local canPull, err = BannerSystem.CanPull(playerData, banner, isMulti)
    if not canPull then
        SummonResultEvent:FireClient(player, {Success = false, Error = err})
        return
    end
    
    -- Deduct currency
    local costType, cost = BannerSystem.GetCost(banner, isMulti)
    playerData[costType] = playerData[costType] - cost
    
    -- Track banner pulls
    playerData.BannerPulls = playerData.BannerPulls or {}
    playerData.BannerPulls[bannerId] = (playerData.BannerPulls[bannerId] or 0) + (isMulti and 10 or 1)
    
    -- Get pity data
    local pityData = PitySystem.GetPityData(playerData, bannerId, banner.PityType or "STANDARD")
    
    -- Perform summons
    local count = isMulti and 10 or 1
    local results = {}
    
    for i = 1, count do
        -- Calculate rate boosts from pity
        local rateBoosts = PitySystem.CalculateRateBoost(pityData, banner.PityType or "STANDARD")
        
        -- Merge with banner boosts
        for rarity, boost in pairs(banner.RateBoosts or {}) do
            rateBoosts[rarity] = (rateBoosts[rarity] or 1) * boost
        end
        
        -- Check hard pity
        local forceRarity = nil
        if PitySystem.CheckHardPity(pityData, banner.PityType or "STANDARD") then
            forceRarity = PitySystem.Config[banner.PityType or "STANDARD"].GuaranteedRarity
        end
        
        -- Check 10-pull epic guarantee (last pull of multi)
        if isMulti and i == 10 and pityData.EpicCounter >= 9 then
            local hasEpicOrHigher = false
            for _, r in ipairs(results) do
                if r.Rarity == "EPIC" or r.Rarity == "LEGENDARY" or r.Rarity == "MYTHIC" then
                    hasEpicOrHigher = true
                    break
                end
            end
            if not hasEpicOrHigher then
                forceRarity = "EPIC"
            end
        end
        
        -- Roll
        local rng = Random.new()
        local rarity = forceRarity or GachaSystem.RollRarity(rng, rateBoosts)
        
        -- Check featured guarantee for limited banners
        local rateUpUnits = banner.RateUpUnits
        if PitySystem.ShouldGetFeatured(pityData, banner.PityType) and rarity == "LEGENDARY" then
            rateUpUnits = banner.RateUpUnits -- Force rate-up
        end
        
        local unit = GachaSystem.RollUnit(rng, rarity, banner.BannedUnits, rateUpUnits)
        local isFeatured = rateUpUnits and table.find(rateUpUnits, unit) ~= nil
        
        -- Update pity
        PitySystem.ProcessPull(pityData, banner.PityType or "STANDARD", rarity, isFeatured)
        
        -- Check if new or duplicate
        local isNew = not playerData.OwnedUnits[unit]
        local dupeResult = nil
        
        if isNew then
            playerData.OwnedUnits[unit] = true
            playerData.Units = playerData.Units or {}
            table.insert(playerData.Units, {
                Name = unit,
                Rarity = rarity,
                ObtainedAt = os.time(),
            })
        else
            dupeResult = DuplicateSystem.ProcessDuplicate(playerData, unit, rarity)
        end
        
        table.insert(results, {
            UnitName = unit,
            Rarity = rarity,
            IsNew = isNew,
            IsFeatured = isFeatured,
            DupeResult = dupeResult,
        })
    end
    
    -- Save data
    PlayerDataManager.SaveData(player)
    
    -- Send results
    SummonResultEvent:FireClient(player, {
        Success = true,
        Results = results,
        NewPity = PitySystem.GetPityDisplay(pityData, banner.PityType or "STANDARD"),
    })
end

return GachaService
```

---

## Integration Points

### PlayerDataManager Schema Updates

```lua
-- Add to default player data template:
DefaultPlayerData = {
    -- Existing fields...
    
    -- Gacha & Summoning
    Gems = 0,
    FriendPoints = 0,
    SummonTicket = 0,
    OwnedUnits = {}, -- {[unitName] = true}
    Units = {}, -- Array of unit instances
    UnitShards = {}, -- {[unitName] = count}
    UniversalShards = 0,
    Constellations = {}, -- {[unitName] = level 0-6}
    Pity = {}, -- {[bannerId] = {Counter, LostFeatured, EpicCounter}}
    BannerPulls = {}, -- {[bannerId] = count}
    
    -- Progression
    Account = {Level = 1, XP = 0, TotalXP = 0},
    Mastery = {}, -- {[unitName] = {Level, XP, TotalXP}}
    Achievements = {Completed = {}, Progress = {}},
}
```

### RemoteEvents to Create

```lua
-- ReplicatedStorage/Events (create as RemoteEvent instances)
local events = {
    "Summon",           -- Client -> Server: Request summon
    "SummonResult",     -- Server -> Client: Summon results
    "BannerInfo",       -- Server -> Client: Active banners
    "AchievementUnlock", -- Server -> Client: Achievement notification
    "LevelUp",          -- Server -> Client: Level up notification
}
```

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| RNG manipulation | High | Server-authoritative rolls only, no client input to RNG |
| Currency duplication | Critical | Validate currency before deduction, atomic transactions |
| Pity exploitation | Medium | Server tracks all pity, validate on each pull |
| Rate display mismatch | Medium | Single source of truth for rates (GachaSystem) |
| Banner timing exploits | Low | Server-side time checks, no client trust |

---

## Testing Checklist

- [ ] Single pull deducts correct currency
- [ ] Multi pull deducts correct currency and gives 10 results
- [ ] Pity counter increments correctly
- [ ] Hard pity triggers at correct threshold
- [ ] 50/50 system works for limited banners
- [ ] Duplicate units convert to shards
- [ ] Constellation upgrades apply correctly
- [ ] Mastery XP accumulates and levels up
- [ ] Account XP accumulates and unlocks features
- [ ] Achievements track and complete correctly
- [ ] Beginner banner respects pull limit
- [ ] Rate-up units have increased appearance rate

---

## VFX Integration Notes

See `SUMMON_VFX_GUIDE.md` for detailed summoning animation specs. Key integration:

```lua
-- Client summon handler triggers VFX sequence
local function PlaySummonSequence(results)
    for i, result in ipairs(results) do
        local vfxType = GetVFXTypeForRarity(result.Rarity)
        SummonVFX.PlayReveal(vfxType, result.UnitName, result.IsNew)
        task.wait(0.8) -- Stagger reveals
    end
end
```
