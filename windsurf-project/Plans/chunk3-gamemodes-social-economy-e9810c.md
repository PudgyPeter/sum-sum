# Chunk 3: Game Modes + Social Features + Economy Implementation Plan

Full implementation details for game modes, social systems, guilds, and economy.

---

## File Index (New Files to Create)

| File Path | Purpose |
|-----------|---------|
| `ReplicatedStorage/Modules/GameModeSystem.lua` | Game mode definitions and rules |
| `ReplicatedStorage/Modules/EndlessModeSystem.lua` | Endless/survival mode logic |
| `ReplicatedStorage/Modules/PvPSystem.lua` | PvP arena mechanics |
| `ReplicatedStorage/Modules/ExpeditionSystem.lua` | Auto-battle expeditions |
| `ReplicatedStorage/Modules/GuildSystem.lua` | Guild management |
| `ReplicatedStorage/Modules/GuildBossSystem.lua` | Cooperative boss raids |
| `ReplicatedStorage/Modules/FriendSystem.lua` | Friend list and interactions |
| `ReplicatedStorage/Modules/ChatSystem.lua` | In-game chat channels |
| `ReplicatedStorage/Modules/EconomySystem.lua` | Currency and shop management |
| `ReplicatedStorage/Modules/TradingSystem.lua` | Player-to-player trading |
| `ServerScriptService/Services/GuildService.lua` | Server-side guild handler |
| `ServerScriptService/Services/EconomyService.lua` | Server-side economy handler |

---

## 3.1 Game Mode System

### GameModeSystem.lua

```lua
local GameModeSystem = {}

GameModeSystem.Modes = {
    STORY = {
        Name = "Story Mode",
        Description = "Progress through the main campaign",
        StaminaCost = 10,
        Rewards = {XP = true, Gold = true, Drops = true},
        Features = {"Checkpoints", "StarRating", "FirstClearBonus"},
    },
    ENDLESS = {
        Name = "Endless Mode",
        Description = "Survive as long as possible",
        StaminaCost = 15,
        Rewards = {XP = true, Gold = true, Leaderboard = true},
        Features = {"WaveScaling", "BonusWaves", "Modifiers"},
    },
    CHALLENGE = {
        Name = "Challenge Mode",
        Description = "Complete stages with restrictions",
        StaminaCost = 20,
        Rewards = {XP = true, Gold = true, UniqueDrops = true},
        Features = {"Restrictions", "TimeLimits", "BonusObjectives"},
    },
    RAID = {
        Name = "Raid Boss",
        Description = "Team up against powerful bosses",
        StaminaCost = 25,
        Rewards = {RaidTokens = true, GuildXP = true},
        Features = {"Multiplayer", "DamageRanking", "PhaseMechanics"},
    },
    PVP = {
        Name = "PvP Arena",
        Description = "Compete against other players",
        StaminaCost = 0,
        Rewards = {PvPTokens = true, Ranking = true},
        Features = {"Matchmaking", "Seasons", "Rewards"},
    },
    TOWER = {
        Name = "Tower of Trials",
        Description = "Climb floors for increasing rewards",
        StaminaCost = 0,
        Rewards = {Gems = true, UniqueDrops = true},
        Features = {"FloorProgress", "ResetCycle", "BossFloors"},
    },
    EXPEDITION = {
        Name = "Expedition",
        Description = "Send units on auto-battle missions",
        StaminaCost = 0,
        Rewards = {Resources = true, XP = true},
        Features = {"AutoBattle", "TimedRewards", "UnitRequirements"},
    },
}

GameModeSystem.Difficulties = {
    NORMAL = {Multiplier = 1.0, RewardMult = 1.0, StarReq = 0},
    HARD = {Multiplier = 1.5, RewardMult = 1.5, StarReq = 50},
    EXTREME = {Multiplier = 2.5, RewardMult = 2.5, StarReq = 150},
    NIGHTMARE = {Multiplier = 4.0, RewardMult = 4.0, StarReq = 300},
}

function GameModeSystem.GetModeConfig(modeId)
    return GameModeSystem.Modes[modeId]
end

function GameModeSystem.CanAccessDifficulty(playerData, difficulty)
    local diffConfig = GameModeSystem.Difficulties[difficulty]
    if not diffConfig then return false end
    
    local totalStars = playerData.TotalStars or 0
    return totalStars >= diffConfig.StarReq
end

function GameModeSystem.CalculateRewards(baseRewards, difficulty, performance)
    local diffConfig = GameModeSystem.Difficulties[difficulty] or GameModeSystem.Difficulties.NORMAL
    local rewards = {}
    
    for key, value in pairs(baseRewards) do
        if type(value) == "number" then
            rewards[key] = math.floor(value * diffConfig.RewardMult * (performance or 1))
        else
            rewards[key] = value
        end
    end
    
    return rewards
end

function GameModeSystem.CalculateStarRating(waveReached, maxWaves, livesLost, timeBonus)
    local completion = waveReached / maxWaves
    local stars = 0
    
    if completion >= 1.0 then
        stars = 1
        if livesLost == 0 then stars = stars + 1 end
        if timeBonus then stars = stars + 1 end
    end
    
    return stars
end

return GameModeSystem
```

---

## 3.2 Endless Mode System

### EndlessModeSystem.lua

```lua
local EndlessModeSystem = {}

EndlessModeSystem.Config = {
    BaseEnemyHealth = 100,
    BaseEnemyDamage = 10,
    ScalingPerWave = 1.08, -- 8% increase per wave
    BossWaveInterval = 10,
    BonusWaveInterval = 5,
    ModifierStartWave = 15,
}

EndlessModeSystem.Modifiers = {
    SPEED_BOOST = {Name = "Speed Demons", Effect = "Enemies move 30% faster", EnemySpeedMult = 1.3},
    ARMOR_UP = {Name = "Armored Assault", Effect = "Enemies have 50% more HP", EnemyHealthMult = 1.5},
    REGEN = {Name = "Regeneration", Effect = "Enemies heal 1% HP/sec", EnemyRegen = 0.01},
    SWARM = {Name = "Swarm", Effect = "Double enemy count, half HP", EnemyCountMult = 2, EnemyHealthMult = 0.5},
    SHIELDED = {Name = "Shielded", Effect = "Enemies have shields", EnemyShield = true},
    INVISIBLE = {Name = "Cloaked", Effect = "Enemies are invisible", EnemyInvisible = true},
    SPLIT = {Name = "Splitters", Effect = "Enemies split on death", EnemySplit = true},
}

EndlessModeSystem.BonusWaveTypes = {
    GOLD_RUSH = {Name = "Gold Rush", Reward = "Gold", Multiplier = 5},
    XP_BOOST = {Name = "XP Bonanza", Reward = "XP", Multiplier = 3},
    TREASURE = {Name = "Treasure Goblins", Reward = "Items", DropRate = 1.0},
}

function EndlessModeSystem.CalculateWaveStats(waveNumber)
    local config = EndlessModeSystem.Config
    local scaling = config.ScalingPerWave ^ (waveNumber - 1)
    
    return {
        EnemyHealth = math.floor(config.BaseEnemyHealth * scaling),
        EnemyDamage = math.floor(config.BaseEnemyDamage * scaling),
        EnemyCount = math.floor(10 + (waveNumber * 0.5)),
        IsBossWave = (waveNumber % config.BossWaveInterval) == 0,
        IsBonusWave = (waveNumber % config.BonusWaveInterval) == 0 and (waveNumber % config.BossWaveInterval) ~= 0,
    }
end

function EndlessModeSystem.GetActiveModifiers(waveNumber)
    local config = EndlessModeSystem.Config
    if waveNumber < config.ModifierStartWave then return {} end
    
    local modifiers = {}
    local modifierKeys = {}
    for key in pairs(EndlessModeSystem.Modifiers) do
        table.insert(modifierKeys, key)
    end
    
    -- Add one modifier every 10 waves after start
    local modifierCount = math.floor((waveNumber - config.ModifierStartWave) / 10) + 1
    modifierCount = math.min(modifierCount, 3) -- Max 3 modifiers
    
    local rng = Random.new(waveNumber) -- Deterministic per wave
    for i = 1, modifierCount do
        local index = rng:NextInteger(1, #modifierKeys)
        local key = modifierKeys[index]
        if not modifiers[key] then
            modifiers[key] = EndlessModeSystem.Modifiers[key]
        end
    end
    
    return modifiers
end

function EndlessModeSystem.GetBonusWaveType(waveNumber)
    local types = {}
    for key in pairs(EndlessModeSystem.BonusWaveTypes) do
        table.insert(types, key)
    end
    
    local rng = Random.new(waveNumber)
    local key = types[rng:NextInteger(1, #types)]
    return key, EndlessModeSystem.BonusWaveTypes[key]
end

function EndlessModeSystem.CalculateEndlessRewards(waveReached, modifiersActive)
    local baseGold = waveReached * 50
    local baseXP = waveReached * 25
    
    -- Bonus for modifiers survived
    local modifierBonus = 1 + (#modifiersActive * 0.1)
    
    return {
        Gold = math.floor(baseGold * modifierBonus),
        XP = math.floor(baseXP * modifierBonus),
        EndlessTokens = math.floor(waveReached / 5),
    }
end

function EndlessModeSystem.UpdateLeaderboard(playerData, waveReached, mapId)
    playerData.EndlessRecords = playerData.EndlessRecords or {}
    local currentRecord = playerData.EndlessRecords[mapId] or 0
    
    if waveReached > currentRecord then
        playerData.EndlessRecords[mapId] = waveReached
        return true, waveReached - currentRecord -- New record, improvement
    end
    
    return false, 0
end

return EndlessModeSystem
```

---

## 3.3 PvP System

### PvPSystem.lua

```lua
local PvPSystem = {}

PvPSystem.Config = {
    BaseRating = 1000,
    KFactor = 32, -- ELO K-factor
    MatchmakingRange = 200,
    SeasonDuration = 2592000, -- 30 days
    PlacementMatches = 10,
}

PvPSystem.Ranks = {
    {Name = "Bronze", MinRating = 0, Icon = "rbxassetid://bronze"},
    {Name = "Silver", MinRating = 1000, Icon = "rbxassetid://silver"},
    {Name = "Gold", MinRating = 1200, Icon = "rbxassetid://gold"},
    {Name = "Platinum", MinRating = 1400, Icon = "rbxassetid://platinum"},
    {Name = "Diamond", MinRating = 1600, Icon = "rbxassetid://diamond"},
    {Name = "Master", MinRating = 1800, Icon = "rbxassetid://master"},
    {Name = "Grandmaster", MinRating = 2000, Icon = "rbxassetid://grandmaster"},
    {Name = "Legend", MinRating = 2200, Icon = "rbxassetid://legend"},
}

PvPSystem.SeasonRewards = {
    Bronze = {Gems = 100, PvPTokens = 50},
    Silver = {Gems = 200, PvPTokens = 100},
    Gold = {Gems = 400, PvPTokens = 200, SummonTicket = 1},
    Platinum = {Gems = 600, PvPTokens = 350, SummonTicket = 2},
    Diamond = {Gems = 1000, PvPTokens = 500, SummonTicket = 3},
    Master = {Gems = 1500, PvPTokens = 750, SummonTicket = 5},
    Grandmaster = {Gems = 2000, PvPTokens = 1000, SummonTicket = 7, ExclusiveSkin = true},
    Legend = {Gems = 3000, PvPTokens = 1500, SummonTicket = 10, ExclusiveSkin = true, Title = "Legend"},
}

function PvPSystem.GetPvPData(playerData)
    playerData.PvP = playerData.PvP or {
        Rating = PvPSystem.Config.BaseRating,
        Wins = 0,
        Losses = 0,
        Streak = 0,
        BestStreak = 0,
        MatchesPlayed = 0,
        SeasonHighest = PvPSystem.Config.BaseRating,
    }
    return playerData.PvP
end

function PvPSystem.GetRank(rating)
    local rank = PvPSystem.Ranks[1]
    for _, r in ipairs(PvPSystem.Ranks) do
        if rating >= r.MinRating then
            rank = r
        else
            break
        end
    end
    return rank
end

function PvPSystem.CalculateELO(winnerRating, loserRating)
    local expectedWinner = 1 / (1 + 10 ^ ((loserRating - winnerRating) / 400))
    local expectedLoser = 1 - expectedWinner
    
    local winnerGain = math.floor(PvPSystem.Config.KFactor * (1 - expectedWinner))
    local loserLoss = math.floor(PvPSystem.Config.KFactor * expectedLoser)
    
    -- Minimum gain/loss
    winnerGain = math.max(winnerGain, 5)
    loserLoss = math.max(loserLoss, 5)
    
    return winnerGain, loserLoss
end

function PvPSystem.ProcessMatchResult(winnerData, loserData)
    local winnerPvP = PvPSystem.GetPvPData(winnerData)
    local loserPvP = PvPSystem.GetPvPData(loserData)
    
    local gain, loss = PvPSystem.CalculateELO(winnerPvP.Rating, loserPvP.Rating)
    
    -- Streak bonus
    local streakBonus = math.min(winnerPvP.Streak, 5) * 2
    gain = gain + streakBonus
    
    -- Update winner
    winnerPvP.Rating = winnerPvP.Rating + gain
    winnerPvP.Wins = winnerPvP.Wins + 1
    winnerPvP.Streak = winnerPvP.Streak + 1
    winnerPvP.BestStreak = math.max(winnerPvP.BestStreak, winnerPvP.Streak)
    winnerPvP.MatchesPlayed = winnerPvP.MatchesPlayed + 1
    winnerPvP.SeasonHighest = math.max(winnerPvP.SeasonHighest, winnerPvP.Rating)
    
    -- Update loser
    loserPvP.Rating = math.max(0, loserPvP.Rating - loss)
    loserPvP.Losses = loserPvP.Losses + 1
    loserPvP.Streak = 0
    loserPvP.MatchesPlayed = loserPvP.MatchesPlayed + 1
    
    return {
        WinnerGain = gain,
        LoserLoss = loss,
        WinnerNewRating = winnerPvP.Rating,
        LoserNewRating = loserPvP.Rating,
        WinnerRank = PvPSystem.GetRank(winnerPvP.Rating),
        LoserRank = PvPSystem.GetRank(loserPvP.Rating),
    }
end

function PvPSystem.FindMatch(playerData, matchmakingPool)
    local pvpData = PvPSystem.GetPvPData(playerData)
    local rating = pvpData.Rating
    local range = PvPSystem.Config.MatchmakingRange
    
    local candidates = {}
    for _, candidate in ipairs(matchmakingPool) do
        local candidateRating = PvPSystem.GetPvPData(candidate).Rating
        if math.abs(candidateRating - rating) <= range then
            table.insert(candidates, candidate)
        end
    end
    
    if #candidates == 0 then
        -- Expand range
        range = range * 2
        for _, candidate in ipairs(matchmakingPool) do
            local candidateRating = PvPSystem.GetPvPData(candidate).Rating
            if math.abs(candidateRating - rating) <= range then
                table.insert(candidates, candidate)
            end
        end
    end
    
    if #candidates > 0 then
        return candidates[math.random(1, #candidates)]
    end
    
    return nil
end

function PvPSystem.GetSeasonRewards(playerData)
    local pvpData = PvPSystem.GetPvPData(playerData)
    local rank = PvPSystem.GetRank(pvpData.SeasonHighest)
    return PvPSystem.SeasonRewards[rank.Name]
end

return PvPSystem
```

---

## 3.4 Expedition System

### ExpeditionSystem.lua

```lua
local ExpeditionSystem = {}

ExpeditionSystem.Expeditions = {
    GOLD_MINE = {
        Name = "Gold Mine",
        Duration = 3600, -- 1 hour
        Slots = 3,
        Rewards = {Gold = {Min = 500, Max = 1500}},
        RequiredPower = 1000,
    },
    XP_TRAINING = {
        Name = "Training Grounds",
        Duration = 7200, -- 2 hours
        Slots = 4,
        Rewards = {XP = {Min = 200, Max = 600}},
        RequiredPower = 1500,
    },
    MATERIAL_HUNT = {
        Name = "Material Gathering",
        Duration = 14400, -- 4 hours
        Slots = 5,
        Rewards = {Materials = {Min = 3, Max = 8}},
        RequiredPower = 2000,
    },
    RARE_EXPEDITION = {
        Name = "Rare Discovery",
        Duration = 28800, -- 8 hours
        Slots = 6,
        Rewards = {Gems = {Min = 10, Max = 50}, RareItem = 0.1},
        RequiredPower = 5000,
    },
    BOSS_HUNT = {
        Name = "Boss Hunt",
        Duration = 43200, -- 12 hours
        Slots = 6,
        Rewards = {BossTokens = {Min = 5, Max = 15}, LegendaryItem = 0.05},
        RequiredPower = 10000,
    },
}

ExpeditionSystem.MaxActiveExpeditions = 3

function ExpeditionSystem.GetExpeditionData(playerData)
    playerData.Expeditions = playerData.Expeditions or {
        Active = {}, -- {[slotIndex] = {ExpeditionId, Units, StartTime, EndTime}}
        Completed = 0,
    }
    return playerData.Expeditions
end

function ExpeditionSystem.CalculateTeamPower(units, unitDataLookup)
    local totalPower = 0
    for _, unitId in ipairs(units) do
        local unitData = unitDataLookup[unitId]
        if unitData then
            totalPower = totalPower + (unitData.Power or 100)
        end
    end
    return totalPower
end

function ExpeditionSystem.CanStartExpedition(playerData, expeditionId, units, unitDataLookup)
    local config = ExpeditionSystem.Expeditions[expeditionId]
    if not config then return false, "Invalid expedition" end
    
    local expData = ExpeditionSystem.GetExpeditionData(playerData)
    
    -- Check active expedition limit
    local activeCount = 0
    for _ in pairs(expData.Active) do activeCount = activeCount + 1 end
    if activeCount >= ExpeditionSystem.MaxActiveExpeditions then
        return false, "Max expeditions reached"
    end
    
    -- Check unit count
    if #units < 1 or #units > config.Slots then
        return false, "Invalid unit count"
    end
    
    -- Check units not already on expedition
    for _, unitId in ipairs(units) do
        for _, active in pairs(expData.Active) do
            if table.find(active.Units, unitId) then
                return false, "Unit already on expedition"
            end
        end
    end
    
    -- Check power requirement
    local teamPower = ExpeditionSystem.CalculateTeamPower(units, unitDataLookup)
    if teamPower < config.RequiredPower then
        return false, string.format("Need %d power (have %d)", config.RequiredPower, teamPower)
    end
    
    return true, nil
end

function ExpeditionSystem.StartExpedition(playerData, expeditionId, units, unitDataLookup)
    local canStart, err = ExpeditionSystem.CanStartExpedition(playerData, expeditionId, units, unitDataLookup)
    if not canStart then return false, err end
    
    local config = ExpeditionSystem.Expeditions[expeditionId]
    local expData = ExpeditionSystem.GetExpeditionData(playerData)
    
    -- Find empty slot
    local slot = 1
    while expData.Active[slot] do slot = slot + 1 end
    
    local now = os.time()
    expData.Active[slot] = {
        ExpeditionId = expeditionId,
        Units = units,
        StartTime = now,
        EndTime = now + config.Duration,
        TeamPower = ExpeditionSystem.CalculateTeamPower(units, unitDataLookup),
    }
    
    return true, slot
end

function ExpeditionSystem.ClaimExpedition(playerData, slot)
    local expData = ExpeditionSystem.GetExpeditionData(playerData)
    local expedition = expData.Active[slot]
    
    if not expedition then return false, "No expedition in slot" end
    if os.time() < expedition.EndTime then return false, "Expedition not complete" end
    
    local config = ExpeditionSystem.Expeditions[expedition.ExpeditionId]
    local rewards = {}
    
    -- Calculate rewards with power bonus
    local powerRatio = expedition.TeamPower / config.RequiredPower
    local bonusMult = math.min(powerRatio, 2.0) -- Cap at 2x
    
    local rng = Random.new()
    for rewardType, range in pairs(config.Rewards) do
        if type(range) == "table" then
            local amount = rng:NextInteger(range.Min, range.Max)
            rewards[rewardType] = math.floor(amount * bonusMult)
        elseif type(range) == "number" then
            -- Chance-based reward
            if rng:NextNumber() < range * bonusMult then
                rewards[rewardType] = 1
            end
        end
    end
    
    -- Clear expedition
    expData.Active[slot] = nil
    expData.Completed = expData.Completed + 1
    
    return true, rewards
end

function ExpeditionSystem.GetTimeRemaining(expedition)
    local remaining = expedition.EndTime - os.time()
    if remaining <= 0 then return "Complete" end
    
    local hours = math.floor(remaining / 3600)
    local mins = math.floor((remaining % 3600) / 60)
    return string.format("%dh %dm", hours, mins)
end

return ExpeditionSystem
```

---

## 3.5 Guild System

### GuildSystem.lua

```lua
local GuildSystem = {}

GuildSystem.Config = {
    MaxMembers = 50,
    CreateCost = 1000, -- Gold
    NameMinLength = 3,
    NameMaxLength = 20,
    DescriptionMaxLength = 200,
}

GuildSystem.Ranks = {
    MEMBER = {Name = "Member", Level = 1, Permissions = {}},
    OFFICER = {Name = "Officer", Level = 2, Permissions = {"Invite", "Kick"}},
    CO_LEADER = {Name = "Co-Leader", Level = 3, Permissions = {"Invite", "Kick", "Promote", "EditInfo"}},
    LEADER = {Name = "Leader", Level = 4, Permissions = {"All"}},
}

GuildSystem.LevelRequirements = {}
for i = 1, 20 do
    GuildSystem.LevelRequirements[i] = math.floor(1000 * (1.5 ^ (i - 1)))
end

GuildSystem.LevelBonuses = {
    [5] = {MemberSlots = 10},
    [10] = {MemberSlots = 10, GoldBonus = 0.05},
    [15] = {MemberSlots = 10, XPBonus = 0.05},
    [20] = {MemberSlots = 20, GoldBonus = 0.05, XPBonus = 0.05, ExclusivePerks = true},
}

function GuildSystem.CreateGuild(creatorId, name, description)
    -- Validate name
    if #name < GuildSystem.Config.NameMinLength or #name > GuildSystem.Config.NameMaxLength then
        return nil, "Invalid name length"
    end
    
    if description and #description > GuildSystem.Config.DescriptionMaxLength then
        return nil, "Description too long"
    end
    
    local guild = {
        Id = game:GetService("HttpService"):GenerateGUID(false),
        Name = name,
        Description = description or "",
        LeaderId = creatorId,
        Members = {
            [creatorId] = {
                JoinedAt = os.time(),
                Rank = "LEADER",
                Contribution = 0,
            }
        },
        Level = 1,
        XP = 0,
        CreatedAt = os.time(),
        Settings = {
            JoinType = "Request", -- Open, Request, Closed
            MinLevel = 1,
        },
        Announcements = {},
    }
    
    return guild, nil
end

function GuildSystem.GetMemberCount(guild)
    local count = 0
    for _ in pairs(guild.Members) do count = count + 1 end
    return count
end

function GuildSystem.GetMaxMembers(guild)
    local base = GuildSystem.Config.MaxMembers
    local bonus = 0
    
    for level, bonuses in pairs(GuildSystem.LevelBonuses) do
        if guild.Level >= level and bonuses.MemberSlots then
            bonus = bonus + bonuses.MemberSlots
        end
    end
    
    return base + bonus
end

function GuildSystem.CanJoin(guild, playerId, playerLevel)
    if guild.Members[playerId] then
        return false, "Already a member"
    end
    
    if GuildSystem.GetMemberCount(guild) >= GuildSystem.GetMaxMembers(guild) then
        return false, "Guild is full"
    end
    
    if playerLevel < guild.Settings.MinLevel then
        return false, "Level requirement not met"
    end
    
    return true, nil
end

function GuildSystem.AddMember(guild, playerId)
    guild.Members[playerId] = {
        JoinedAt = os.time(),
        Rank = "MEMBER",
        Contribution = 0,
    }
end

function GuildSystem.RemoveMember(guild, playerId)
    if playerId == guild.LeaderId then
        return false, "Cannot remove leader"
    end
    
    guild.Members[playerId] = nil
    return true, nil
end

function GuildSystem.HasPermission(guild, playerId, permission)
    local member = guild.Members[playerId]
    if not member then return false end
    
    local rank = GuildSystem.Ranks[member.Rank]
    if not rank then return false end
    
    if table.find(rank.Permissions, "All") then return true end
    return table.find(rank.Permissions, permission) ~= nil
end

function GuildSystem.PromoteMember(guild, playerId)
    local member = guild.Members[playerId]
    if not member then return false, "Not a member" end
    
    local currentRank = GuildSystem.Ranks[member.Rank]
    local rankOrder = {"MEMBER", "OFFICER", "CO_LEADER"}
    
    local currentIndex = table.find(rankOrder, member.Rank)
    if currentIndex and currentIndex < #rankOrder then
        member.Rank = rankOrder[currentIndex + 1]
        return true, member.Rank
    end
    
    return false, "Cannot promote further"
end

function GuildSystem.AddGuildXP(guild, amount)
    guild.XP = guild.XP + amount
    
    local levelUps = {}
    while guild.Level < 20 do
        local required = GuildSystem.LevelRequirements[guild.Level]
        if guild.XP >= required then
            guild.XP = guild.XP - required
            guild.Level = guild.Level + 1
            
            local bonus = GuildSystem.LevelBonuses[guild.Level]
            table.insert(levelUps, {NewLevel = guild.Level, Bonus = bonus})
        else
            break
        end
    end
    
    return levelUps
end

function GuildSystem.GetGuildBonuses(guild)
    local bonuses = {GoldBonus = 0, XPBonus = 0}
    
    for level, levelBonuses in pairs(GuildSystem.LevelBonuses) do
        if guild.Level >= level then
            if levelBonuses.GoldBonus then
                bonuses.GoldBonus = bonuses.GoldBonus + levelBonuses.GoldBonus
            end
            if levelBonuses.XPBonus then
                bonuses.XPBonus = bonuses.XPBonus + levelBonuses.XPBonus
            end
        end
    end
    
    return bonuses
end

return GuildSystem
```

---

## 3.6 Guild Boss System

### GuildBossSystem.lua

```lua
local GuildBossSystem = {}

GuildBossSystem.Bosses = {
    WORLD_SERPENT = {
        Name = "World Serpent",
        BaseHealth = 10000000,
        Phases = 3,
        TimeLimit = 300, -- 5 minutes per attempt
        ResetCooldown = 86400, -- 24 hours
        Rewards = {GuildXP = 500, RaidTokens = 50},
    },
    DEMON_LORD = {
        Name = "Demon Lord",
        BaseHealth = 25000000,
        Phases = 4,
        TimeLimit = 300,
        ResetCooldown = 86400,
        Rewards = {GuildXP = 1000, RaidTokens = 100},
        RequiredGuildLevel = 5,
    },
    ANCIENT_DRAGON = {
        Name = "Ancient Dragon",
        BaseHealth = 50000000,
        Phases = 5,
        TimeLimit = 300,
        ResetCooldown = 86400,
        Rewards = {GuildXP = 2000, RaidTokens = 200},
        RequiredGuildLevel = 10,
    },
}

GuildBossSystem.DamageRankRewards = {
    [1] = {BonusTokens = 100, Title = "Raid MVP"},
    [2] = {BonusTokens = 75},
    [3] = {BonusTokens = 50},
    [4] = {BonusTokens = 30},
    [5] = {BonusTokens = 20},
}

function GuildBossSystem.GetBossData(guildData, bossId)
    guildData.BossProgress = guildData.BossProgress or {}
    guildData.BossProgress[bossId] = guildData.BossProgress[bossId] or {
        CurrentHealth = GuildBossSystem.Bosses[bossId].BaseHealth,
        Phase = 1,
        DamageDealt = {}, -- {[playerId] = totalDamage}
        LastReset = 0,
        Attempts = {},
    }
    return guildData.BossProgress[bossId]
end

function GuildBossSystem.CanAttempt(guildData, guildLevel, bossId, playerId)
    local boss = GuildBossSystem.Bosses[bossId]
    if not boss then return false, "Invalid boss" end
    
    if boss.RequiredGuildLevel and guildLevel < boss.RequiredGuildLevel then
        return false, "Guild level too low"
    end
    
    local bossData = GuildBossSystem.GetBossData(guildData, bossId)
    
    -- Check if player already attempted today
    local today = math.floor(os.time() / 86400)
    if bossData.Attempts[playerId] == today then
        return false, "Already attempted today"
    end
    
    -- Check if boss is defeated and on cooldown
    if bossData.CurrentHealth <= 0 then
        local timeSinceReset = os.time() - bossData.LastReset
        if timeSinceReset < boss.ResetCooldown then
            return false, "Boss respawning"
        end
    end
    
    return true, nil
end

function GuildBossSystem.RecordDamage(guildData, bossId, playerId, damage)
    local bossData = GuildBossSystem.GetBossData(guildData, bossId)
    local boss = GuildBossSystem.Bosses[bossId]
    
    -- Record attempt
    local today = math.floor(os.time() / 86400)
    bossData.Attempts[playerId] = today
    
    -- Apply damage
    local actualDamage = math.min(damage, bossData.CurrentHealth)
    bossData.CurrentHealth = bossData.CurrentHealth - actualDamage
    bossData.DamageDealt[playerId] = (bossData.DamageDealt[playerId] or 0) + actualDamage
    
    local result = {
        DamageDealt = actualDamage,
        RemainingHealth = bossData.CurrentHealth,
        TotalContribution = bossData.DamageDealt[playerId],
    }
    
    -- Check phase transition
    local healthPercent = bossData.CurrentHealth / boss.BaseHealth
    local newPhase = math.ceil((1 - healthPercent) * boss.Phases) + 1
    newPhase = math.min(newPhase, boss.Phases)
    
    if newPhase > bossData.Phase then
        bossData.Phase = newPhase
        result.PhaseChanged = true
        result.NewPhase = newPhase
    end
    
    -- Check defeat
    if bossData.CurrentHealth <= 0 then
        result.BossDefeated = true
        result.Rankings = GuildBossSystem.CalculateRankings(bossData)
    end
    
    return result
end

function GuildBossSystem.CalculateRankings(bossData)
    local rankings = {}
    for playerId, damage in pairs(bossData.DamageDealt) do
        table.insert(rankings, {PlayerId = playerId, Damage = damage})
    end
    
    table.sort(rankings, function(a, b) return a.Damage > b.Damage end)
    
    for i, entry in ipairs(rankings) do
        entry.Rank = i
        entry.Rewards = GuildBossSystem.DamageRankRewards[i] or {BonusTokens = 10}
    end
    
    return rankings
end

function GuildBossSystem.ResetBoss(guildData, bossId)
    local boss = GuildBossSystem.Bosses[bossId]
    guildData.BossProgress[bossId] = {
        CurrentHealth = boss.BaseHealth,
        Phase = 1,
        DamageDealt = {},
        LastReset = os.time(),
        Attempts = {},
    }
end

return GuildBossSystem
```

---

## 3.7 Economy System

### EconomySystem.lua

```lua
local EconomySystem = {}

EconomySystem.Currencies = {
    Gold = {Name = "Gold", Icon = "💰", Cap = 99999999, Tradeable = true},
    Gems = {Name = "Gems", Icon = "💎", Cap = 999999, Tradeable = false},
    PvPTokens = {Name = "Arena Tokens", Icon = "⚔️", Cap = 99999, Tradeable = false},
    RaidTokens = {Name = "Raid Tokens", Icon = "🏰", Cap = 99999, Tradeable = false},
    EventTokens = {Name = "Event Tokens", Icon = "🎉", Cap = 99999, Tradeable = false},
    FriendPoints = {Name = "Friend Points", Icon = "❤️", Cap = 99999, Tradeable = false},
}

EconomySystem.ExchangeRates = {
    GoldToGems = 10000, -- 10000 gold = 1 gem (limited daily)
    GemsToGold = 100, -- 1 gem = 100 gold
}

EconomySystem.DailyLimits = {
    GoldToGemsExchange = 10, -- Max 10 gems from gold per day
}

function EconomySystem.GetCurrency(playerData, currencyType)
    return playerData[currencyType] or 0
end

function EconomySystem.AddCurrency(playerData, currencyType, amount)
    local config = EconomySystem.Currencies[currencyType]
    if not config then return false, "Invalid currency" end
    
    local current = playerData[currencyType] or 0
    playerData[currencyType] = math.min(current + amount, config.Cap)
    
    return true, playerData[currencyType]
end

function EconomySystem.RemoveCurrency(playerData, currencyType, amount)
    local current = playerData[currencyType] or 0
    if current < amount then
        return false, "Insufficient funds"
    end
    
    playerData[currencyType] = current - amount
    return true, playerData[currencyType]
end

function EconomySystem.CanAfford(playerData, costs)
    for currencyType, amount in pairs(costs) do
        if (playerData[currencyType] or 0) < amount then
            return false, currencyType
        end
    end
    return true, nil
end

function EconomySystem.ProcessPurchase(playerData, costs, rewards)
    local canAfford, missing = EconomySystem.CanAfford(playerData, costs)
    if not canAfford then
        return false, "Insufficient " .. missing
    end
    
    -- Deduct costs
    for currencyType, amount in pairs(costs) do
        EconomySystem.RemoveCurrency(playerData, currencyType, amount)
    end
    
    -- Add rewards
    for currencyType, amount in pairs(rewards or {}) do
        EconomySystem.AddCurrency(playerData, currencyType, amount)
    end
    
    return true, nil
end

function EconomySystem.ExchangeCurrency(playerData, fromType, toType, amount)
    local rate = nil
    local limit = nil
    
    if fromType == "Gold" and toType == "Gems" then
        rate = EconomySystem.ExchangeRates.GoldToGems
        limit = EconomySystem.DailyLimits.GoldToGemsExchange
    elseif fromType == "Gems" and toType == "Gold" then
        rate = 1 / EconomySystem.ExchangeRates.GemsToGold
    end
    
    if not rate then
        return false, "Exchange not available"
    end
    
    local cost = math.ceil(amount * rate)
    local current = playerData[fromType] or 0
    
    if current < cost then
        return false, "Insufficient " .. fromType
    end
    
    -- Check daily limit
    if limit then
        playerData.DailyExchanges = playerData.DailyExchanges or {}
        local key = fromType .. "To" .. toType
        local today = math.floor(os.time() / 86400)
        
        if playerData.DailyExchanges[key .. "_Day"] ~= today then
            playerData.DailyExchanges[key .. "_Day"] = today
            playerData.DailyExchanges[key] = 0
        end
        
        if (playerData.DailyExchanges[key] or 0) + amount > limit then
            return false, "Daily limit reached"
        end
        
        playerData.DailyExchanges[key] = (playerData.DailyExchanges[key] or 0) + amount
    end
    
    EconomySystem.RemoveCurrency(playerData, fromType, cost)
    EconomySystem.AddCurrency(playerData, toType, amount)
    
    return true, nil
end

return EconomySystem
```

---

## 3.8 Shop System

### ShopSystem.lua

```lua
local ShopSystem = {}

ShopSystem.Categories = {
    DAILY = "Daily Deals",
    GEMS = "Gem Shop",
    GOLD = "Gold Shop",
    TOKEN = "Token Exchange",
    SPECIAL = "Special Offers",
}

ShopSystem.Items = {
    -- Daily Deals (rotate daily)
    DAILY_GOLD_PACK = {
        Category = "DAILY",
        Name = "Gold Pack",
        Cost = {Gems = 50},
        Rewards = {Gold = 10000},
        DailyLimit = 3,
    },
    DAILY_XP_BOOST = {
        Category = "DAILY",
        Name = "XP Booster (2hr)",
        Cost = {Gems = 30},
        Rewards = {XPBoost2h = 1},
        DailyLimit = 1,
    },
    DAILY_STAMINA = {
        Category = "DAILY",
        Name = "Stamina Refill",
        Cost = {Gems = 50},
        Rewards = {StaminaRefill = 1},
        DailyLimit = 5,
    },
    
    -- Gem Shop
    SUMMON_TICKET = {
        Category = "GEMS",
        Name = "Summon Ticket",
        Cost = {Gems = 100},
        Rewards = {SummonTicket = 1},
    },
    UNIVERSAL_SHARDS_10 = {
        Category = "GEMS",
        Name = "Universal Shards x10",
        Cost = {Gems = 200},
        Rewards = {UniversalShards = 10},
    },
    
    -- Gold Shop
    ENHANCEMENT_MATERIAL = {
        Category = "GOLD",
        Name = "Enhancement Stone",
        Cost = {Gold = 5000},
        Rewards = {EnhancementStone = 1},
        DailyLimit = 10,
    },
    
    -- Token Exchange
    PVP_EPIC_BOX = {
        Category = "TOKEN",
        Name = "Epic Unit Box",
        Cost = {PvPTokens = 500},
        Rewards = {EpicUnitBox = 1},
        WeeklyLimit = 1,
    },
    RAID_LEGENDARY_SHARD = {
        Category = "TOKEN",
        Name = "Legendary Shards x50",
        Cost = {RaidTokens = 300},
        Rewards = {LegendaryShards = 50},
        WeeklyLimit = 2,
    },
}

function ShopSystem.GetPurchaseData(playerData)
    playerData.ShopPurchases = playerData.ShopPurchases or {
        Daily = {},
        Weekly = {},
        DayReset = 0,
        WeekReset = 0,
    }
    
    -- Reset daily
    local today = math.floor(os.time() / 86400)
    if playerData.ShopPurchases.DayReset ~= today then
        playerData.ShopPurchases.Daily = {}
        playerData.ShopPurchases.DayReset = today
    end
    
    -- Reset weekly
    local thisWeek = math.floor(os.time() / 604800)
    if playerData.ShopPurchases.WeekReset ~= thisWeek then
        playerData.ShopPurchases.Weekly = {}
        playerData.ShopPurchases.WeekReset = thisWeek
    end
    
    return playerData.ShopPurchases
end

function ShopSystem.CanPurchase(playerData, itemId)
    local item = ShopSystem.Items[itemId]
    if not item then return false, "Invalid item" end
    
    local purchaseData = ShopSystem.GetPurchaseData(playerData)
    
    -- Check limits
    if item.DailyLimit then
        local purchased = purchaseData.Daily[itemId] or 0
        if purchased >= item.DailyLimit then
            return false, "Daily limit reached"
        end
    end
    
    if item.WeeklyLimit then
        local purchased = purchaseData.Weekly[itemId] or 0
        if purchased >= item.WeeklyLimit then
            return false, "Weekly limit reached"
        end
    end
    
    -- Check currency
    for currency, amount in pairs(item.Cost) do
        if (playerData[currency] or 0) < amount then
            return false, "Insufficient " .. currency
        end
    end
    
    return true, nil
end

function ShopSystem.Purchase(playerData, itemId)
    local canPurchase, err = ShopSystem.CanPurchase(playerData, itemId)
    if not canPurchase then return false, err end
    
    local item = ShopSystem.Items[itemId]
    local purchaseData = ShopSystem.GetPurchaseData(playerData)
    
    -- Deduct cost
    for currency, amount in pairs(item.Cost) do
        playerData[currency] = (playerData[currency] or 0) - amount
    end
    
    -- Track purchase
    if item.DailyLimit then
        purchaseData.Daily[itemId] = (purchaseData.Daily[itemId] or 0) + 1
    end
    if item.WeeklyLimit then
        purchaseData.Weekly[itemId] = (purchaseData.Weekly[itemId] or 0) + 1
    end
    
    return true, item.Rewards
end

function ShopSystem.GetRemainingPurchases(playerData, itemId)
    local item = ShopSystem.Items[itemId]
    if not item then return nil end
    
    local purchaseData = ShopSystem.GetPurchaseData(playerData)
    
    if item.DailyLimit then
        local purchased = purchaseData.Daily[itemId] or 0
        return item.DailyLimit - purchased, "daily"
    end
    
    if item.WeeklyLimit then
        local purchased = purchaseData.Weekly[itemId] or 0
        return item.WeeklyLimit - purchased, "weekly"
    end
    
    return math.huge, "unlimited"
end

return ShopSystem
```

---

## 3.9 Friend System

### FriendSystem.lua

```lua
local FriendSystem = {}

FriendSystem.Config = {
    MaxFriends = 100,
    FriendPointsPerUse = 10, -- Points when friend unit is used
    DailyFriendPointCap = 200,
}

function FriendSystem.GetFriendData(playerData)
    playerData.Friends = playerData.Friends or {
        List = {}, -- {[friendId] = {AddedAt, LastUsed, PointsToday}}
        Incoming = {}, -- Pending requests
        Outgoing = {},
        Blocked = {},
        PointsEarnedToday = 0,
        DayReset = 0,
    }
    
    -- Reset daily points
    local today = math.floor(os.time() / 86400)
    if playerData.Friends.DayReset ~= today then
        playerData.Friends.PointsEarnedToday = 0
        playerData.Friends.DayReset = today
        for _, friend in pairs(playerData.Friends.List) do
            friend.PointsToday = 0
        end
    end
    
    return playerData.Friends
end

function FriendSystem.GetFriendCount(playerData)
    local friendData = FriendSystem.GetFriendData(playerData)
    local count = 0
    for _ in pairs(friendData.List) do count = count + 1 end
    return count
end

function FriendSystem.CanAddFriend(playerData, targetId)
    local friendData = FriendSystem.GetFriendData(playerData)
    
    if friendData.List[targetId] then
        return false, "Already friends"
    end
    
    if friendData.Blocked[targetId] then
        return false, "User is blocked"
    end
    
    if FriendSystem.GetFriendCount(playerData) >= FriendSystem.Config.MaxFriends then
        return false, "Friend list full"
    end
    
    return true, nil
end

function FriendSystem.SendRequest(playerData, targetId)
    local canAdd, err = FriendSystem.CanAddFriend(playerData, targetId)
    if not canAdd then return false, err end
    
    local friendData = FriendSystem.GetFriendData(playerData)
    
    if friendData.Outgoing[targetId] then
        return false, "Request already sent"
    end
    
    friendData.Outgoing[targetId] = os.time()
    return true, nil
end

function FriendSystem.AcceptRequest(playerData, requesterId)
    local friendData = FriendSystem.GetFriendData(playerData)
    
    if not friendData.Incoming[requesterId] then
        return false, "No pending request"
    end
    
    local canAdd, err = FriendSystem.CanAddFriend(playerData, requesterId)
    if not canAdd then return false, err end
    
    -- Add to friends list
    friendData.List[requesterId] = {
        AddedAt = os.time(),
        LastUsed = 0,
        PointsToday = 0,
    }
    
    -- Clean up requests
    friendData.Incoming[requesterId] = nil
    
    return true, nil
end

function FriendSystem.RemoveFriend(playerData, friendId)
    local friendData = FriendSystem.GetFriendData(playerData)
    friendData.List[friendId] = nil
    return true
end

function FriendSystem.UseFriendUnit(playerData, friendId)
    local friendData = FriendSystem.GetFriendData(playerData)
    local friend = friendData.List[friendId]
    
    if not friend then return 0 end
    
    -- Check daily cap
    if friendData.PointsEarnedToday >= FriendSystem.Config.DailyFriendPointCap then
        return 0
    end
    
    local points = FriendSystem.Config.FriendPointsPerUse
    friendData.PointsEarnedToday = friendData.PointsEarnedToday + points
    friend.LastUsed = os.time()
    friend.PointsToday = (friend.PointsToday or 0) + points
    
    return points
end

function FriendSystem.GetAvailableFriendUnits(playerData, friendDataMap)
    local friendData = FriendSystem.GetFriendData(playerData)
    local units = {}
    
    for friendId, _ in pairs(friendData.List) do
        local friendPlayerData = friendDataMap[friendId]
        if friendPlayerData and friendPlayerData.SupportUnit then
            table.insert(units, {
                FriendId = friendId,
                Unit = friendPlayerData.SupportUnit,
                LastUsed = friendData.List[friendId].LastUsed,
            })
        end
    end
    
    return units
end

return FriendSystem
```

---

## Integration Points

### PlayerDataManager Schema Updates

```lua
-- Add to default player data template:
DefaultPlayerData = {
    -- Existing fields...
    
    -- Game Modes
    StoryProgress = {}, -- {[mapId] = {Stars, Cleared, FirstClear}}
    EndlessRecords = {}, -- {[mapId] = highestWave}
    TowerProgress = {CurrentFloor = 1, HighestFloor = 1},
    TotalStars = 0,
    
    -- PvP
    PvP = {Rating = 1000, Wins = 0, Losses = 0, Streak = 0, MatchesPlayed = 0},
    
    -- Expeditions
    Expeditions = {Active = {}, Completed = 0},
    
    -- Guild (stored separately in GuildDataStore)
    GuildId = nil,
    
    -- Economy
    Gold = 0,
    Gems = 0,
    PvPTokens = 0,
    RaidTokens = 0,
    EventTokens = 0,
    FriendPoints = 0,
    DailyExchanges = {},
    ShopPurchases = {},
    
    -- Friends
    Friends = {List = {}, Incoming = {}, Outgoing = {}, Blocked = {}},
    SupportUnit = nil, -- Unit shown to friends
}
```

### RemoteEvents to Create

```lua
local events = {
    -- Game Modes
    "StartGameMode",
    "EndGameMode",
    "GameModeResult",
    
    -- PvP
    "QueuePvP",
    "PvPMatchFound",
    "PvPResult",
    
    -- Expeditions
    "StartExpedition",
    "ClaimExpedition",
    "ExpeditionUpdate",
    
    -- Guild
    "CreateGuild",
    "JoinGuild",
    "LeaveGuild",
    "GuildAction",
    "GuildUpdate",
    "GuildBossAttack",
    
    -- Economy
    "Purchase",
    "PurchaseResult",
    "ExchangeCurrency",
    
    -- Friends
    "SendFriendRequest",
    "AcceptFriendRequest",
    "RemoveFriend",
    "FriendListUpdate",
}
```

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Economy inflation | High | Careful reward tuning, sinks, caps |
| Guild data corruption | Critical | Separate DataStore, atomic operations |
| PvP rating manipulation | Medium | Server-authoritative ELO calculation |
| Expedition time exploits | Low | Server-side time tracking |
| Friend point farming | Low | Daily caps, usage cooldowns |
| Shop purchase duplication | Critical | Atomic transactions, validation |

---

## Testing Checklist

- [ ] Story mode saves star ratings correctly
- [ ] Endless mode scales difficulty properly
- [ ] PvP matchmaking finds appropriate opponents
- [ ] ELO calculation works both directions
- [ ] Expeditions track time server-side
- [ ] Expedition rewards scale with power
- [ ] Guild creation deducts gold
- [ ] Guild member limits enforced
- [ ] Guild boss damage tracked correctly
- [ ] Currency caps are enforced
- [ ] Shop daily/weekly limits reset properly
- [ ] Friend requests work bidirectionally
- [ ] Friend points have daily cap
