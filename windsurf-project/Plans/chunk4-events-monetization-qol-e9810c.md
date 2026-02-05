# Chunk 4: Events + Monetization + QoL + Audio/Visual Implementation Plan

Full implementation details for events, daily systems, monetization, quality of life, and audio/visual features.

---

## File Index (New Files to Create)

| File Path | Purpose |
|-----------|---------|
| `ReplicatedStorage/Modules/EventSystem.lua` | Event management and scheduling |
| `ReplicatedStorage/Modules/DailyLoginSystem.lua` | Daily login rewards |
| `ReplicatedStorage/Modules/MissionSystem.lua` | Daily/weekly missions |
| `ReplicatedStorage/Modules/BattlePassSystem.lua` | Season pass progression |
| `ReplicatedStorage/Modules/VIPSystem.lua` | VIP benefits and tiers |
| `ReplicatedStorage/Modules/SettingsSystem.lua` | Player settings management |
| `ReplicatedStorage/Modules/NotificationSystem.lua` | In-game notifications |
| `ReplicatedStorage/Modules/TutorialSystem.lua` | New player tutorials |
| `ReplicatedStorage/Modules/AudioSystem.lua` | Sound and music management |
| `ReplicatedStorage/Modules/VFXSystem.lua` | Visual effects management |
| `StarterPlayerScripts/SettingsUI.lua` | Client settings interface |
| `StarterPlayerScripts/NotificationHandler.lua` | Client notification display |

---

## 4.1 Event System

### EventSystem.lua

```lua
local EventSystem = {}

EventSystem.EventTypes = {
    LIMITED_BANNER = {Name = "Limited Banner", Duration = 1209600}, -- 2 weeks
    COLLAB = {Name = "Collaboration", Duration = 2419200}, -- 4 weeks
    HOLIDAY = {Name = "Holiday Event", Duration = 604800}, -- 1 week
    RAID = {Name = "Raid Event", Duration = 604800},
    CHALLENGE = {Name = "Challenge Event", Duration = 259200}, -- 3 days
    DOUBLE_DROP = {Name = "Double Drops", Duration = 86400}, -- 1 day
    DOUBLE_XP = {Name = "Double XP", Duration = 86400},
}

EventSystem.ActiveEvents = {}
EventSystem.ScheduledEvents = {}

function EventSystem.CreateEvent(config)
    local event = {
        Id = config.Id or game:GetService("HttpService"):GenerateGUID(false),
        Type = config.Type,
        Name = config.Name,
        Description = config.Description or "",
        StartTime = config.StartTime,
        EndTime = config.EndTime,
        Rewards = config.Rewards or {},
        Milestones = config.Milestones or {},
        BannerIds = config.BannerIds or {},
        MapIds = config.MapIds or {},
        ShopItems = config.ShopItems or {},
        Multipliers = config.Multipliers or {},
        IsActive = false,
    }
    
    if event.StartTime <= os.time() and event.EndTime > os.time() then
        event.IsActive = true
        EventSystem.ActiveEvents[event.Id] = event
    else
        EventSystem.ScheduledEvents[event.Id] = event
    end
    
    return event
end

function EventSystem.GetActiveEvents()
    local now = os.time()
    local active = {}
    
    -- Check scheduled events
    for id, event in pairs(EventSystem.ScheduledEvents) do
        if event.StartTime <= now then
            if event.EndTime > now then
                event.IsActive = true
                EventSystem.ActiveEvents[id] = event
            end
            EventSystem.ScheduledEvents[id] = nil
        end
    end
    
    -- Filter expired active events
    for id, event in pairs(EventSystem.ActiveEvents) do
        if event.EndTime > now then
            table.insert(active, event)
        else
            EventSystem.ActiveEvents[id] = nil
        end
    end
    
    return active
end

function EventSystem.GetEventMultiplier(multiplierType)
    local total = 1.0
    
    for _, event in pairs(EventSystem.ActiveEvents) do
        if event.Multipliers[multiplierType] then
            total = total * event.Multipliers[multiplierType]
        end
    end
    
    return total
end

function EventSystem.GetEventProgress(playerData, eventId)
    playerData.EventProgress = playerData.EventProgress or {}
    playerData.EventProgress[eventId] = playerData.EventProgress[eventId] or {
        Points = 0,
        ClaimedMilestones = {},
        Completions = {},
    }
    return playerData.EventProgress[eventId]
end

function EventSystem.AddEventPoints(playerData, eventId, points)
    local event = EventSystem.ActiveEvents[eventId]
    if not event then return nil end
    
    local progress = EventSystem.GetEventProgress(playerData, eventId)
    progress.Points = progress.Points + points
    
    -- Check milestone unlocks
    local newMilestones = {}
    for _, milestone in ipairs(event.Milestones) do
        if progress.Points >= milestone.RequiredPoints and not progress.ClaimedMilestones[milestone.Id] then
            table.insert(newMilestones, milestone)
        end
    end
    
    return newMilestones
end

function EventSystem.ClaimMilestone(playerData, eventId, milestoneId)
    local event = EventSystem.ActiveEvents[eventId]
    if not event then return false, "Event not active" end
    
    local progress = EventSystem.GetEventProgress(playerData, eventId)
    
    if progress.ClaimedMilestones[milestoneId] then
        return false, "Already claimed"
    end
    
    local milestone = nil
    for _, m in ipairs(event.Milestones) do
        if m.Id == milestoneId then
            milestone = m
            break
        end
    end
    
    if not milestone then return false, "Invalid milestone" end
    if progress.Points < milestone.RequiredPoints then return false, "Not enough points" end
    
    progress.ClaimedMilestones[milestoneId] = os.time()
    return true, milestone.Rewards
end

function EventSystem.GetTimeRemaining(event)
    local remaining = event.EndTime - os.time()
    if remaining <= 0 then return "Ended" end
    
    local days = math.floor(remaining / 86400)
    local hours = math.floor((remaining % 86400) / 3600)
    
    if days > 0 then
        return string.format("%d days %d hours", days, hours)
    else
        local mins = math.floor((remaining % 3600) / 60)
        return string.format("%d hours %d mins", hours, mins)
    end
end

return EventSystem
```

---

## 4.2 Daily Login System

### DailyLoginSystem.lua

```lua
local DailyLoginSystem = {}

DailyLoginSystem.MonthlyRewards = {
    [1] = {Gold = 1000},
    [2] = {Gems = 20},
    [3] = {Gold = 2000},
    [4] = {SummonTicket = 1},
    [5] = {Gems = 30},
    [6] = {Gold = 3000},
    [7] = {Gems = 50, SummonTicket = 1}, -- Weekly milestone
    [8] = {Gold = 4000},
    [9] = {Gems = 30},
    [10] = {EnhancementStone = 5},
    [11] = {Gold = 5000},
    [12] = {Gems = 40},
    [13] = {SummonTicket = 2},
    [14] = {Gems = 100, Gold = 10000}, -- 2-week milestone
    [15] = {Gold = 6000},
    [16] = {Gems = 50},
    [17] = {EnhancementStone = 10},
    [18] = {Gold = 7000},
    [19] = {Gems = 60},
    [20] = {SummonTicket = 3},
    [21] = {Gems = 150, SelectTicket = 1}, -- 3-week milestone
    [22] = {Gold = 10000},
    [23] = {Gems = 70},
    [24] = {EnhancementStone = 15},
    [25] = {Gold = 12000},
    [26] = {Gems = 80},
    [27] = {SummonTicket = 5},
    [28] = {Gems = 300, SummonTicket = 10, EpicUnitBox = 1}, -- Monthly milestone
}

DailyLoginSystem.ComebackRewards = {
    [3] = {Gems = 100, Gold = 5000}, -- 3 days away
    [7] = {Gems = 200, SummonTicket = 3}, -- 7 days away
    [14] = {Gems = 500, SummonTicket = 5, EpicUnitBox = 1}, -- 14 days away
}

function DailyLoginSystem.GetLoginData(playerData)
    playerData.Login = playerData.Login or {
        TotalDays = 0,
        CurrentStreak = 0,
        BestStreak = 0,
        MonthDay = 0,
        LastLogin = 0,
        ClaimedToday = false,
        MonthReset = 0,
    }
    return playerData.Login
end

function DailyLoginSystem.ProcessLogin(playerData)
    local loginData = DailyLoginSystem.GetLoginData(playerData)
    local now = os.time()
    local today = math.floor(now / 86400)
    local lastDay = math.floor(loginData.LastLogin / 86400)
    
    -- Check if already claimed today
    if loginData.ClaimedToday and lastDay == today then
        return nil, "Already claimed"
    end
    
    local result = {
        Rewards = {},
        StreakBonus = nil,
        ComebackBonus = nil,
        NewStreak = 0,
    }
    
    -- Check for comeback
    local daysAway = today - lastDay
    if daysAway >= 3 and loginData.LastLogin > 0 then
        for threshold, rewards in pairs(DailyLoginSystem.ComebackRewards) do
            if daysAway >= threshold then
                result.ComebackBonus = rewards
            end
        end
    end
    
    -- Update streak
    if daysAway == 1 then
        loginData.CurrentStreak = loginData.CurrentStreak + 1
    elseif daysAway > 1 then
        loginData.CurrentStreak = 1
    end
    
    loginData.BestStreak = math.max(loginData.BestStreak, loginData.CurrentStreak)
    result.NewStreak = loginData.CurrentStreak
    
    -- Check month reset
    local thisMonth = os.date("*t", now).month
    local lastMonth = loginData.MonthReset
    if thisMonth ~= lastMonth then
        loginData.MonthDay = 0
        loginData.MonthReset = thisMonth
    end
    
    -- Advance month day
    loginData.MonthDay = math.min(loginData.MonthDay + 1, 28)
    loginData.TotalDays = loginData.TotalDays + 1
    loginData.LastLogin = now
    loginData.ClaimedToday = true
    
    -- Get daily reward
    result.Rewards = DailyLoginSystem.MonthlyRewards[loginData.MonthDay] or {Gold = 1000}
    result.Day = loginData.MonthDay
    
    return result, nil
end

function DailyLoginSystem.GetCalendarStatus(playerData)
    local loginData = DailyLoginSystem.GetLoginData(playerData)
    local status = {}
    
    for day = 1, 28 do
        status[day] = {
            Rewards = DailyLoginSystem.MonthlyRewards[day],
            Claimed = day <= loginData.MonthDay,
            IsToday = day == loginData.MonthDay + 1,
            IsMilestone = (day == 7 or day == 14 or day == 21 or day == 28),
        }
    end
    
    return status
end

function DailyLoginSystem.ResetDailyFlag(playerData)
    local loginData = DailyLoginSystem.GetLoginData(playerData)
    local today = math.floor(os.time() / 86400)
    local lastDay = math.floor(loginData.LastLogin / 86400)
    
    if today ~= lastDay then
        loginData.ClaimedToday = false
    end
end

return DailyLoginSystem
```

---

## 4.3 Mission System

### MissionSystem.lua

```lua
local MissionSystem = {}

MissionSystem.DailyMissions = {
    COMPLETE_STAGES_3 = {
        Name = "Complete 3 Stages",
        Description = "Clear any 3 stages",
        Target = 3,
        TrackingKey = "StagesCompleted",
        Rewards = {Gems = 10, Gold = 500},
    },
    DEFEAT_ENEMIES_100 = {
        Name = "Defeat 100 Enemies",
        Description = "Defeat 100 enemies in combat",
        Target = 100,
        TrackingKey = "EnemiesDefeated",
        Rewards = {Gold = 1000},
    },
    USE_ABILITIES_10 = {
        Name = "Use 10 Abilities",
        Description = "Activate unit abilities 10 times",
        Target = 10,
        TrackingKey = "AbilitiesUsed",
        Rewards = {Gems = 5},
    },
    SUMMON_1 = {
        Name = "Perform a Summon",
        Description = "Summon at least once",
        Target = 1,
        TrackingKey = "Summons",
        Rewards = {Gold = 2000},
    },
    SPEND_STAMINA_50 = {
        Name = "Spend 50 Stamina",
        Description = "Use 50 stamina on stages",
        Target = 50,
        TrackingKey = "StaminaSpent",
        Rewards = {Gems = 10},
    },
}

MissionSystem.WeeklyMissions = {
    COMPLETE_STAGES_20 = {
        Name = "Complete 20 Stages",
        Target = 20,
        TrackingKey = "StagesCompleted",
        Rewards = {Gems = 100, SummonTicket = 1},
    },
    DEFEAT_BOSSES_5 = {
        Name = "Defeat 5 Bosses",
        Target = 5,
        TrackingKey = "BossesDefeated",
        Rewards = {Gems = 50, Gold = 10000},
    },
    PVP_MATCHES_10 = {
        Name = "Complete 10 PvP Matches",
        Target = 10,
        TrackingKey = "PvPMatches",
        Rewards = {PvPTokens = 100, Gems = 30},
    },
    GUILD_CONTRIBUTE = {
        Name = "Contribute to Guild",
        Target = 1,
        TrackingKey = "GuildContribution",
        Rewards = {Gems = 50},
    },
    SUMMON_10 = {
        Name = "Perform 10 Summons",
        Target = 10,
        TrackingKey = "Summons",
        Rewards = {SummonTicket = 2},
    },
}

MissionSystem.AllClearRewards = {
    Daily = {Gems = 30, Gold = 5000},
    Weekly = {Gems = 200, SummonTicket = 3},
}

function MissionSystem.GetMissionData(playerData)
    playerData.Missions = playerData.Missions or {
        DailyProgress = {},
        DailyClaimed = {},
        WeeklyProgress = {},
        WeeklyClaimed = {},
        DayReset = 0,
        WeekReset = 0,
        DailyAllClear = false,
        WeeklyAllClear = false,
    }
    
    local now = os.time()
    local today = math.floor(now / 86400)
    local thisWeek = math.floor(now / 604800)
    
    -- Reset daily
    if playerData.Missions.DayReset ~= today then
        playerData.Missions.DailyProgress = {}
        playerData.Missions.DailyClaimed = {}
        playerData.Missions.DailyAllClear = false
        playerData.Missions.DayReset = today
    end
    
    -- Reset weekly
    if playerData.Missions.WeekReset ~= thisWeek then
        playerData.Missions.WeeklyProgress = {}
        playerData.Missions.WeeklyClaimed = {}
        playerData.Missions.WeeklyAllClear = false
        playerData.Missions.WeekReset = thisWeek
    end
    
    return playerData.Missions
end

function MissionSystem.UpdateProgress(playerData, trackingKey, amount)
    local missionData = MissionSystem.GetMissionData(playerData)
    amount = amount or 1
    
    local completed = {}
    
    -- Update daily missions
    for missionId, mission in pairs(MissionSystem.DailyMissions) do
        if mission.TrackingKey == trackingKey then
            missionData.DailyProgress[missionId] = (missionData.DailyProgress[missionId] or 0) + amount
            if missionData.DailyProgress[missionId] >= mission.Target and not missionData.DailyClaimed[missionId] then
                table.insert(completed, {Type = "Daily", Id = missionId, Mission = mission})
            end
        end
    end
    
    -- Update weekly missions
    for missionId, mission in pairs(MissionSystem.WeeklyMissions) do
        if mission.TrackingKey == trackingKey then
            missionData.WeeklyProgress[missionId] = (missionData.WeeklyProgress[missionId] or 0) + amount
            if missionData.WeeklyProgress[missionId] >= mission.Target and not missionData.WeeklyClaimed[missionId] then
                table.insert(completed, {Type = "Weekly", Id = missionId, Mission = mission})
            end
        end
    end
    
    return completed
end

function MissionSystem.ClaimMission(playerData, missionType, missionId)
    local missionData = MissionSystem.GetMissionData(playerData)
    
    local missions = missionType == "Daily" and MissionSystem.DailyMissions or MissionSystem.WeeklyMissions
    local progress = missionType == "Daily" and missionData.DailyProgress or missionData.WeeklyProgress
    local claimed = missionType == "Daily" and missionData.DailyClaimed or missionData.WeeklyClaimed
    
    local mission = missions[missionId]
    if not mission then return false, "Invalid mission" end
    
    if claimed[missionId] then return false, "Already claimed" end
    if (progress[missionId] or 0) < mission.Target then return false, "Not complete" end
    
    claimed[missionId] = true
    return true, mission.Rewards
end

function MissionSystem.ClaimAllClear(playerData, missionType)
    local missionData = MissionSystem.GetMissionData(playerData)
    
    local missions = missionType == "Daily" and MissionSystem.DailyMissions or MissionSystem.WeeklyMissions
    local claimed = missionType == "Daily" and missionData.DailyClaimed or missionData.WeeklyClaimed
    local allClearKey = missionType == "Daily" and "DailyAllClear" or "WeeklyAllClear"
    
    if missionData[allClearKey] then return false, "Already claimed" end
    
    -- Check all missions claimed
    for missionId in pairs(missions) do
        if not claimed[missionId] then
            return false, "Not all missions claimed"
        end
    end
    
    missionData[allClearKey] = true
    return true, MissionSystem.AllClearRewards[missionType]
end

function MissionSystem.GetMissionStatus(playerData)
    local missionData = MissionSystem.GetMissionData(playerData)
    
    local status = {
        Daily = {},
        Weekly = {},
        DailyAllClear = missionData.DailyAllClear,
        WeeklyAllClear = missionData.WeeklyAllClear,
    }
    
    for id, mission in pairs(MissionSystem.DailyMissions) do
        status.Daily[id] = {
            Mission = mission,
            Progress = missionData.DailyProgress[id] or 0,
            Claimed = missionData.DailyClaimed[id] or false,
        }
    end
    
    for id, mission in pairs(MissionSystem.WeeklyMissions) do
        status.Weekly[id] = {
            Mission = mission,
            Progress = missionData.WeeklyProgress[id] or 0,
            Claimed = missionData.WeeklyClaimed[id] or false,
        }
    end
    
    return status
end

return MissionSystem
```

---

## 4.4 Battle Pass System

### BattlePassSystem.lua

```lua
local BattlePassSystem = {}

BattlePassSystem.Config = {
    MaxLevel = 50,
    XPPerLevel = 1000,
    SeasonDuration = 2592000, -- 30 days
    PremiumCost = 500, -- Gems
}

BattlePassSystem.XPSources = {
    DAILY_MISSION = 100,
    WEEKLY_MISSION = 300,
    STAGE_CLEAR = 50,
    PVP_WIN = 75,
    EVENT_PARTICIPATION = 150,
}

-- Rewards for each level (Free and Premium tracks)
BattlePassSystem.Rewards = {}
for i = 1, 50 do
    BattlePassSystem.Rewards[i] = {
        Free = nil,
        Premium = nil,
    }
end

-- Define specific rewards
BattlePassSystem.Rewards[1] = {Free = {Gold = 1000}, Premium = {Gems = 20}}
BattlePassSystem.Rewards[5] = {Free = {Gems = 20}, Premium = {SummonTicket = 1}}
BattlePassSystem.Rewards[10] = {Free = {SummonTicket = 1}, Premium = {Gems = 50, EnhancementStone = 5}}
BattlePassSystem.Rewards[15] = {Free = {Gold = 5000}, Premium = {SummonTicket = 2}}
BattlePassSystem.Rewards[20] = {Free = {Gems = 30}, Premium = {ExclusiveSkin = "BP_Skin_1"}}
BattlePassSystem.Rewards[25] = {Free = {Gold = 10000}, Premium = {Gems = 100}}
BattlePassSystem.Rewards[30] = {Free = {SummonTicket = 2}, Premium = {EpicUnitBox = 1}}
BattlePassSystem.Rewards[35] = {Free = {Gems = 50}, Premium = {SummonTicket = 3}}
BattlePassSystem.Rewards[40] = {Free = {Gold = 15000}, Premium = {Gems = 150}}
BattlePassSystem.Rewards[45] = {Free = {SummonTicket = 3}, Premium = {ExclusiveUnit = "BP_Unit"}}
BattlePassSystem.Rewards[50] = {Free = {Gems = 100}, Premium = {Gems = 300, ExclusiveTitle = "Season Champion", ExclusiveFrame = true}}

function BattlePassSystem.GetPassData(playerData)
    playerData.BattlePass = playerData.BattlePass or {
        Level = 1,
        XP = 0,
        IsPremium = false,
        ClaimedFree = {},
        ClaimedPremium = {},
        SeasonId = 0,
    }
    return playerData.BattlePass
end

function BattlePassSystem.AddXP(playerData, source)
    local passData = BattlePassSystem.GetPassData(playerData)
    local xpAmount = BattlePassSystem.XPSources[source] or 0
    
    if passData.Level >= BattlePassSystem.Config.MaxLevel then
        return nil
    end
    
    passData.XP = passData.XP + xpAmount
    
    local levelUps = {}
    while passData.Level < BattlePassSystem.Config.MaxLevel do
        if passData.XP >= BattlePassSystem.Config.XPPerLevel then
            passData.XP = passData.XP - BattlePassSystem.Config.XPPerLevel
            passData.Level = passData.Level + 1
            
            local rewards = BattlePassSystem.Rewards[passData.Level]
            if rewards then
                table.insert(levelUps, {
                    Level = passData.Level,
                    FreeReward = rewards.Free,
                    PremiumReward = passData.IsPremium and rewards.Premium or nil,
                })
            end
        else
            break
        end
    end
    
    return levelUps
end

function BattlePassSystem.PurchasePremium(playerData)
    local passData = BattlePassSystem.GetPassData(playerData)
    
    if passData.IsPremium then
        return false, "Already premium"
    end
    
    if (playerData.Gems or 0) < BattlePassSystem.Config.PremiumCost then
        return false, "Insufficient gems"
    end
    
    playerData.Gems = playerData.Gems - BattlePassSystem.Config.PremiumCost
    passData.IsPremium = true
    
    -- Return all unclaimed premium rewards
    local unclaimedRewards = {}
    for level = 1, passData.Level do
        local rewards = BattlePassSystem.Rewards[level]
        if rewards and rewards.Premium and not passData.ClaimedPremium[level] then
            table.insert(unclaimedRewards, {Level = level, Rewards = rewards.Premium})
        end
    end
    
    return true, unclaimedRewards
end

function BattlePassSystem.ClaimReward(playerData, level, isPremium)
    local passData = BattlePassSystem.GetPassData(playerData)
    
    if level > passData.Level then
        return false, "Level not reached"
    end
    
    local rewards = BattlePassSystem.Rewards[level]
    if not rewards then
        return false, "No reward at this level"
    end
    
    if isPremium then
        if not passData.IsPremium then
            return false, "Premium pass required"
        end
        if passData.ClaimedPremium[level] then
            return false, "Already claimed"
        end
        passData.ClaimedPremium[level] = true
        return true, rewards.Premium
    else
        if passData.ClaimedFree[level] then
            return false, "Already claimed"
        end
        passData.ClaimedFree[level] = true
        return true, rewards.Free
    end
end

function BattlePassSystem.GetProgress(playerData)
    local passData = BattlePassSystem.GetPassData(playerData)
    
    return {
        Level = passData.Level,
        XP = passData.XP,
        XPRequired = BattlePassSystem.Config.XPPerLevel,
        IsPremium = passData.IsPremium,
        MaxLevel = BattlePassSystem.Config.MaxLevel,
    }
end

return BattlePassSystem
```

---

## 4.5 VIP System

### VIPSystem.lua

```lua
local VIPSystem = {}

VIPSystem.Tiers = {
    [0] = {Name = "None", RequiredSpend = 0, Benefits = {}},
    [1] = {
        Name = "Bronze VIP",
        RequiredSpend = 5, -- $5
        Benefits = {
            GoldBonus = 0.05,
            XPBonus = 0.05,
            DailyGems = 10,
        },
    },
    [2] = {
        Name = "Silver VIP",
        RequiredSpend = 20,
        Benefits = {
            GoldBonus = 0.10,
            XPBonus = 0.10,
            DailyGems = 25,
            ExtraExpeditionSlot = 1,
        },
    },
    [3] = {
        Name = "Gold VIP",
        RequiredSpend = 50,
        Benefits = {
            GoldBonus = 0.15,
            XPBonus = 0.15,
            DailyGems = 50,
            ExtraExpeditionSlot = 1,
            ExclusiveBanner = true,
        },
    },
    [4] = {
        Name = "Platinum VIP",
        RequiredSpend = 100,
        Benefits = {
            GoldBonus = 0.20,
            XPBonus = 0.20,
            DailyGems = 75,
            ExtraExpeditionSlot = 2,
            ExclusiveBanner = true,
            PityReduction = 5,
        },
    },
    [5] = {
        Name = "Diamond VIP",
        RequiredSpend = 250,
        Benefits = {
            GoldBonus = 0.30,
            XPBonus = 0.30,
            DailyGems = 100,
            ExtraExpeditionSlot = 2,
            ExclusiveBanner = true,
            PityReduction = 10,
            ExclusiveTitle = "Whale",
            ReducedCooldowns = 0.10,
        },
    },
}

function VIPSystem.GetVIPData(playerData)
    playerData.VIP = playerData.VIP or {
        TotalSpent = 0,
        Tier = 0,
        DailyGemsClaimed = false,
        DayReset = 0,
    }
    
    -- Reset daily claim
    local today = math.floor(os.time() / 86400)
    if playerData.VIP.DayReset ~= today then
        playerData.VIP.DailyGemsClaimed = false
        playerData.VIP.DayReset = today
    end
    
    return playerData.VIP
end

function VIPSystem.AddSpend(playerData, amountUSD)
    local vipData = VIPSystem.GetVIPData(playerData)
    vipData.TotalSpent = vipData.TotalSpent + amountUSD
    
    -- Check tier upgrades
    local newTier = 0
    for tier, data in pairs(VIPSystem.Tiers) do
        if vipData.TotalSpent >= data.RequiredSpend then
            newTier = math.max(newTier, tier)
        end
    end
    
    local upgraded = newTier > vipData.Tier
    vipData.Tier = newTier
    
    return upgraded, VIPSystem.Tiers[newTier]
end

function VIPSystem.GetTier(playerData)
    local vipData = VIPSystem.GetVIPData(playerData)
    return vipData.Tier, VIPSystem.Tiers[vipData.Tier]
end

function VIPSystem.GetBenefit(playerData, benefitKey)
    local tier, tierData = VIPSystem.GetTier(playerData)
    if tierData and tierData.Benefits then
        return tierData.Benefits[benefitKey]
    end
    return nil
end

function VIPSystem.ClaimDailyGems(playerData)
    local vipData = VIPSystem.GetVIPData(playerData)
    
    if vipData.DailyGemsClaimed then
        return false, "Already claimed"
    end
    
    local dailyGems = VIPSystem.GetBenefit(playerData, "DailyGems")
    if not dailyGems or dailyGems <= 0 then
        return false, "No VIP daily gems"
    end
    
    vipData.DailyGemsClaimed = true
    return true, dailyGems
end

function VIPSystem.ApplyBonuses(playerData, baseRewards)
    local bonusedRewards = {}
    
    for key, value in pairs(baseRewards) do
        if key == "Gold" then
            local bonus = VIPSystem.GetBenefit(playerData, "GoldBonus") or 0
            bonusedRewards[key] = math.floor(value * (1 + bonus))
        elseif key == "XP" then
            local bonus = VIPSystem.GetBenefit(playerData, "XPBonus") or 0
            bonusedRewards[key] = math.floor(value * (1 + bonus))
        else
            bonusedRewards[key] = value
        end
    end
    
    return bonusedRewards
end

return VIPSystem
```

---

## 4.6 Settings System

### SettingsSystem.lua

```lua
local SettingsSystem = {}

SettingsSystem.Defaults = {
    -- Audio
    MasterVolume = 1.0,
    MusicVolume = 0.8,
    SFXVolume = 1.0,
    VoiceVolume = 1.0,
    
    -- Graphics
    QualityLevel = "High", -- Low, Medium, High, Ultra
    ParticleEffects = true,
    ScreenShake = true,
    DamageNumbers = true,
    
    -- Gameplay
    AutoSkillEnabled = false,
    SpeedMultiplier = 1, -- 1, 2, 4
    ConfirmSummons = true,
    ConfirmPurchases = true,
    
    -- UI
    ShowMinimap = true,
    ShowFPS = false,
    ShowPing = false,
    CompactUI = false,
    
    -- Notifications
    PushNotifications = true,
    EventReminders = true,
    StaminaReminders = true,
    FriendNotifications = true,
    
    -- Privacy
    ShowOnlineStatus = true,
    AllowFriendRequests = true,
    ShowInLeaderboard = true,
}

SettingsSystem.Constraints = {
    MasterVolume = {Min = 0, Max = 1},
    MusicVolume = {Min = 0, Max = 1},
    SFXVolume = {Min = 0, Max = 1},
    VoiceVolume = {Min = 0, Max = 1},
    QualityLevel = {Options = {"Low", "Medium", "High", "Ultra"}},
    SpeedMultiplier = {Options = {1, 2, 4}},
}

function SettingsSystem.GetSettings(playerData)
    playerData.Settings = playerData.Settings or {}
    
    -- Fill in defaults for any missing settings
    for key, default in pairs(SettingsSystem.Defaults) do
        if playerData.Settings[key] == nil then
            playerData.Settings[key] = default
        end
    end
    
    return playerData.Settings
end

function SettingsSystem.SetSetting(playerData, key, value)
    if SettingsSystem.Defaults[key] == nil then
        return false, "Invalid setting"
    end
    
    -- Validate constraints
    local constraint = SettingsSystem.Constraints[key]
    if constraint then
        if constraint.Min and constraint.Max then
            if type(value) ~= "number" or value < constraint.Min or value > constraint.Max then
                return false, "Value out of range"
            end
        elseif constraint.Options then
            if not table.find(constraint.Options, value) then
                return false, "Invalid option"
            end
        end
    end
    
    local settings = SettingsSystem.GetSettings(playerData)
    settings[key] = value
    return true, nil
end

function SettingsSystem.ResetToDefaults(playerData)
    playerData.Settings = {}
    for key, default in pairs(SettingsSystem.Defaults) do
        playerData.Settings[key] = default
    end
    return playerData.Settings
end

function SettingsSystem.GetSetting(playerData, key)
    local settings = SettingsSystem.GetSettings(playerData)
    return settings[key]
end

return SettingsSystem
```

---

## 4.7 Notification System

### NotificationSystem.lua

```lua
local NotificationSystem = {}

NotificationSystem.Types = {
    INFO = {Icon = "ℹ️", Color = Color3.fromRGB(100, 150, 255), Duration = 3},
    SUCCESS = {Icon = "✓", Color = Color3.fromRGB(100, 255, 100), Duration = 3},
    WARNING = {Icon = "⚠️", Color = Color3.fromRGB(255, 200, 50), Duration = 4},
    ERROR = {Icon = "✗", Color = Color3.fromRGB(255, 100, 100), Duration = 5},
    REWARD = {Icon = "🎁", Color = Color3.fromRGB(255, 215, 0), Duration = 4},
    LEVEL_UP = {Icon = "⬆️", Color = Color3.fromRGB(150, 255, 150), Duration = 5},
    ACHIEVEMENT = {Icon = "🏆", Color = Color3.fromRGB(255, 215, 0), Duration = 5},
    SUMMON = {Icon = "✨", Color = Color3.fromRGB(200, 150, 255), Duration = 4},
}

NotificationSystem.Queue = {}
NotificationSystem.MaxVisible = 5

function NotificationSystem.Create(notificationType, title, message, data)
    local typeConfig = NotificationSystem.Types[notificationType] or NotificationSystem.Types.INFO
    
    local notification = {
        Id = game:GetService("HttpService"):GenerateGUID(false),
        Type = notificationType,
        Title = title,
        Message = message,
        Icon = typeConfig.Icon,
        Color = typeConfig.Color,
        Duration = typeConfig.Duration,
        Data = data,
        CreatedAt = os.time(),
    }
    
    table.insert(NotificationSystem.Queue, notification)
    return notification
end

function NotificationSystem.CreateRewardNotification(rewards)
    local rewardText = {}
    for key, value in pairs(rewards) do
        table.insert(rewardText, string.format("+%d %s", value, key))
    end
    
    return NotificationSystem.Create(
        "REWARD",
        "Rewards Received!",
        table.concat(rewardText, ", "),
        {Rewards = rewards}
    )
end

function NotificationSystem.CreateLevelUpNotification(levelType, newLevel, unlocks)
    local message = string.format("%s Level %d!", levelType, newLevel)
    if unlocks then
        message = message .. " New unlocks available!"
    end
    
    return NotificationSystem.Create(
        "LEVEL_UP",
        "Level Up!",
        message,
        {LevelType = levelType, NewLevel = newLevel, Unlocks = unlocks}
    )
end

function NotificationSystem.CreateAchievementNotification(achievement)
    return NotificationSystem.Create(
        "ACHIEVEMENT",
        "Achievement Unlocked!",
        achievement.Name,
        {Achievement = achievement}
    )
end

function NotificationSystem.GetPending()
    local pending = {}
    for i = 1, math.min(#NotificationSystem.Queue, NotificationSystem.MaxVisible) do
        table.insert(pending, NotificationSystem.Queue[i])
    end
    return pending
end

function NotificationSystem.Dismiss(notificationId)
    for i, notification in ipairs(NotificationSystem.Queue) do
        if notification.Id == notificationId then
            table.remove(NotificationSystem.Queue, i)
            return true
        end
    end
    return false
end

function NotificationSystem.ClearAll()
    NotificationSystem.Queue = {}
end

return NotificationSystem
```

---

## 4.8 Audio System

### AudioSystem.lua

```lua
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local AudioSystem = {}

AudioSystem.MusicTracks = {
    MENU = {Id = "rbxassetid://menu_music", Volume = 0.6, Looped = true},
    BATTLE = {Id = "rbxassetid://battle_music", Volume = 0.7, Looped = true},
    BOSS = {Id = "rbxassetid://boss_music", Volume = 0.8, Looped = true},
    VICTORY = {Id = "rbxassetid://victory_music", Volume = 0.7, Looped = false},
    DEFEAT = {Id = "rbxassetid://defeat_music", Volume = 0.6, Looped = false},
    EVENT = {Id = "rbxassetid://event_music", Volume = 0.7, Looped = true},
}

AudioSystem.SFX = {
    -- UI
    BUTTON_CLICK = {Id = "rbxassetid://button_click", Volume = 0.5},
    BUTTON_HOVER = {Id = "rbxassetid://button_hover", Volume = 0.3},
    MENU_OPEN = {Id = "rbxassetid://menu_open", Volume = 0.4},
    MENU_CLOSE = {Id = "rbxassetid://menu_close", Volume = 0.4},
    
    -- Combat
    HIT_NORMAL = {Id = "rbxassetid://hit_normal", Volume = 0.6},
    HIT_CRIT = {Id = "rbxassetid://hit_crit", Volume = 0.8},
    ABILITY_CAST = {Id = "rbxassetid://ability_cast", Volume = 0.7},
    ENEMY_DEATH = {Id = "rbxassetid://enemy_death", Volume = 0.5},
    BOSS_ROAR = {Id = "rbxassetid://boss_roar", Volume = 0.9},
    
    -- Gacha
    SUMMON_START = {Id = "rbxassetid://summon_start", Volume = 0.7},
    SUMMON_COMMON = {Id = "rbxassetid://summon_common", Volume = 0.6},
    SUMMON_RARE = {Id = "rbxassetid://summon_rare", Volume = 0.7},
    SUMMON_EPIC = {Id = "rbxassetid://summon_epic", Volume = 0.8},
    SUMMON_LEGENDARY = {Id = "rbxassetid://summon_legendary", Volume = 1.0},
    SUMMON_MYTHIC = {Id = "rbxassetid://summon_mythic", Volume = 1.0},
    
    -- Rewards
    COIN_COLLECT = {Id = "rbxassetid://coin_collect", Volume = 0.5},
    LEVEL_UP = {Id = "rbxassetid://level_up", Volume = 0.8},
    ACHIEVEMENT = {Id = "rbxassetid://achievement", Volume = 0.8},
    
    -- Notifications
    NOTIFICATION = {Id = "rbxassetid://notification", Volume = 0.4},
    ERROR = {Id = "rbxassetid://error", Volume = 0.5},
}

AudioSystem.CurrentMusic = nil
AudioSystem.Settings = {
    MasterVolume = 1.0,
    MusicVolume = 0.8,
    SFXVolume = 1.0,
}

function AudioSystem.Initialize()
    -- Create sound groups
    local musicGroup = Instance.new("SoundGroup")
    musicGroup.Name = "Music"
    musicGroup.Volume = AudioSystem.Settings.MusicVolume
    musicGroup.Parent = SoundService
    
    local sfxGroup = Instance.new("SoundGroup")
    sfxGroup.Name = "SFX"
    sfxGroup.Volume = AudioSystem.Settings.SFXVolume
    sfxGroup.Parent = SoundService
    
    AudioSystem.MusicGroup = musicGroup
    AudioSystem.SFXGroup = sfxGroup
end

function AudioSystem.UpdateSettings(settings)
    AudioSystem.Settings = settings
    
    if AudioSystem.MusicGroup then
        AudioSystem.MusicGroup.Volume = settings.MasterVolume * settings.MusicVolume
    end
    if AudioSystem.SFXGroup then
        AudioSystem.SFXGroup.Volume = settings.MasterVolume * settings.SFXVolume
    end
end

function AudioSystem.PlayMusic(trackId, fadeTime)
    local track = AudioSystem.MusicTracks[trackId]
    if not track then return end
    
    fadeTime = fadeTime or 1
    
    -- Fade out current music
    if AudioSystem.CurrentMusic then
        local oldMusic = AudioSystem.CurrentMusic
        local fadeOut = TweenService:Create(oldMusic, TweenInfo.new(fadeTime), {Volume = 0})
        fadeOut:Play()
        fadeOut.Completed:Connect(function()
            oldMusic:Destroy()
        end)
    end
    
    -- Create and play new music
    local sound = Instance.new("Sound")
    sound.SoundId = track.Id
    sound.Volume = 0
    sound.Looped = track.Looped
    sound.SoundGroup = AudioSystem.MusicGroup
    sound.Parent = SoundService
    sound:Play()
    
    -- Fade in
    local targetVolume = track.Volume
    local fadeIn = TweenService:Create(sound, TweenInfo.new(fadeTime), {Volume = targetVolume})
    fadeIn:Play()
    
    AudioSystem.CurrentMusic = sound
end

function AudioSystem.StopMusic(fadeTime)
    fadeTime = fadeTime or 1
    
    if AudioSystem.CurrentMusic then
        local music = AudioSystem.CurrentMusic
        local fadeOut = TweenService:Create(music, TweenInfo.new(fadeTime), {Volume = 0})
        fadeOut:Play()
        fadeOut.Completed:Connect(function()
            music:Destroy()
        end)
        AudioSystem.CurrentMusic = nil
    end
end

function AudioSystem.PlaySFX(sfxId, position)
    local sfx = AudioSystem.SFX[sfxId]
    if not sfx then return end
    
    local sound = Instance.new("Sound")
    sound.SoundId = sfx.Id
    sound.Volume = sfx.Volume
    sound.SoundGroup = AudioSystem.SFXGroup
    
    if position then
        -- 3D sound
        local part = Instance.new("Part")
        part.Anchored = true
        part.CanCollide = false
        part.Transparency = 1
        part.Position = position
        part.Parent = workspace
        sound.Parent = part
        sound.Ended:Connect(function()
            part:Destroy()
        end)
    else
        sound.Parent = SoundService
        sound.Ended:Connect(function()
            sound:Destroy()
        end)
    end
    
    sound:Play()
    return sound
end

function AudioSystem.PlaySummonSFX(rarity)
    local sfxMap = {
        COMMON = "SUMMON_COMMON",
        UNCOMMON = "SUMMON_COMMON",
        RARE = "SUMMON_RARE",
        EPIC = "SUMMON_EPIC",
        LEGENDARY = "SUMMON_LEGENDARY",
        MYTHIC = "SUMMON_MYTHIC",
    }
    
    AudioSystem.PlaySFX(sfxMap[rarity] or "SUMMON_COMMON")
end

return AudioSystem
```

---

## 4.9 VFX System

### VFXSystem.lua

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local VFXSystem = {}

VFXSystem.Particles = {
    HIT_NORMAL = {Asset = "HitParticle", Duration = 0.5, Scale = 1},
    HIT_CRIT = {Asset = "CritParticle", Duration = 0.7, Scale = 1.5},
    DEATH = {Asset = "DeathParticle", Duration = 1.0, Scale = 1},
    LEVEL_UP = {Asset = "LevelUpParticle", Duration = 2.0, Scale = 2},
    SUMMON_COMMON = {Asset = "SummonParticle_Common", Duration = 1.5, Scale = 1},
    SUMMON_RARE = {Asset = "SummonParticle_Rare", Duration = 2.0, Scale = 1.2},
    SUMMON_EPIC = {Asset = "SummonParticle_Epic", Duration = 2.5, Scale = 1.5},
    SUMMON_LEGENDARY = {Asset = "SummonParticle_Legendary", Duration = 3.0, Scale = 2},
    SUMMON_MYTHIC = {Asset = "SummonParticle_Mythic", Duration = 3.5, Scale = 2.5},
    TYPE_ADVANTAGE = {Asset = "TypeAdvantageParticle", Duration = 0.5, Scale = 1},
    TYPE_DISADVANTAGE = {Asset = "TypeDisadvantageParticle", Duration = 0.5, Scale = 1},
    HEAL = {Asset = "HealParticle", Duration = 1.0, Scale = 1},
    BUFF = {Asset = "BuffParticle", Duration = 1.5, Scale = 1},
    DEBUFF = {Asset = "DebuffParticle", Duration = 1.5, Scale = 1},
}

VFXSystem.DamageNumberColors = {
    NORMAL = Color3.fromRGB(255, 255, 255),
    CRIT = Color3.fromRGB(255, 200, 50),
    HEAL = Color3.fromRGB(100, 255, 100),
    BLOCKED = Color3.fromRGB(150, 150, 150),
    SUPER_EFFECTIVE = Color3.fromRGB(255, 100, 100),
    NOT_EFFECTIVE = Color3.fromRGB(100, 100, 255),
}

function VFXSystem.PlayParticle(particleId, position, customScale)
    local particleConfig = VFXSystem.Particles[particleId]
    if not particleConfig then return end
    
    local particleTemplate = ReplicatedStorage:FindFirstChild("VFX") and 
        ReplicatedStorage.VFX:FindFirstChild(particleConfig.Asset)
    
    if not particleTemplate then
        warn("Missing particle asset: " .. particleConfig.Asset)
        return
    end
    
    local particle = particleTemplate:Clone()
    particle.Position = position
    
    local scale = particleConfig.Scale * (customScale or 1)
    if particle:IsA("Part") then
        particle.Size = particle.Size * scale
    end
    
    particle.Parent = workspace.VFX or workspace
    
    -- Auto cleanup
    task.delay(particleConfig.Duration, function()
        if particle and particle.Parent then
            particle:Destroy()
        end
    end)
    
    return particle
end

function VFXSystem.ShowDamageNumber(position, amount, damageType)
    local color = VFXSystem.DamageNumberColors[damageType] or VFXSystem.DamageNumberColors.NORMAL
    
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Size = UDim2.new(0, 100, 0, 50)
    billboardGui.StudsOffset = Vector3.new(0, 2, 0)
    billboardGui.Adornee = nil
    billboardGui.AlwaysOnTop = true
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = tostring(math.floor(amount))
    label.TextColor3 = color
    label.TextStrokeTransparency = 0.5
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Parent = billboardGui
    
    -- Create attachment part
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 1
    part.Size = Vector3.new(0.1, 0.1, 0.1)
    part.Position = position
    part.Parent = workspace.VFX or workspace
    
    billboardGui.Adornee = part
    billboardGui.Parent = part
    
    -- Animate
    local startPos = position
    local endPos = position + Vector3.new(math.random(-1, 1), 3, math.random(-1, 1))
    
    local tween = TweenService:Create(part, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = endPos
    })
    
    local fadeTween = TweenService:Create(label, TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0.5), {
        TextTransparency = 1,
        TextStrokeTransparency = 1
    })
    
    tween:Play()
    fadeTween:Play()
    
    fadeTween.Completed:Connect(function()
        part:Destroy()
    end)
end

function VFXSystem.PlayTypeIndicator(position, isAdvantage)
    local particleId = isAdvantage and "TYPE_ADVANTAGE" or "TYPE_DISADVANTAGE"
    VFXSystem.PlayParticle(particleId, position)
    
    local text = isAdvantage and "Super Effective!" or "Not Very Effective..."
    local color = isAdvantage and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(100, 100, 255)
    
    -- Could show floating text here similar to damage numbers
end

function VFXSystem.PlaySummonSequence(rarity, callback)
    local rarityParticles = {
        COMMON = "SUMMON_COMMON",
        UNCOMMON = "SUMMON_COMMON",
        RARE = "SUMMON_RARE",
        EPIC = "SUMMON_EPIC",
        LEGENDARY = "SUMMON_LEGENDARY",
        MYTHIC = "SUMMON_MYTHIC",
    }
    
    local particleId = rarityParticles[rarity] or "SUMMON_COMMON"
    local config = VFXSystem.Particles[particleId]
    
    -- Play the particle at screen center (would need proper positioning)
    -- This is a simplified version
    
    task.delay(config.Duration * 0.7, function()
        if callback then callback() end
    end)
end

function VFXSystem.ScreenShake(intensity, duration)
    -- Implementation would use CurrentCamera manipulation
    local camera = workspace.CurrentCamera
    if not camera then return end
    
    local originalCFrame = camera.CFrame
    local startTime = tick()
    
    local connection
    connection = game:GetService("RunService").RenderStepped:Connect(function()
        local elapsed = tick() - startTime
        if elapsed >= duration then
            connection:Disconnect()
            return
        end
        
        local decay = 1 - (elapsed / duration)
        local offset = Vector3.new(
            (math.random() - 0.5) * intensity * decay,
            (math.random() - 0.5) * intensity * decay,
            0
        )
        
        camera.CFrame = camera.CFrame * CFrame.new(offset)
    end)
end

return VFXSystem
```

---

## Integration Points

### PlayerDataManager Schema Updates

```lua
-- Add to default player data template:
DefaultPlayerData = {
    -- Existing fields...
    
    -- Events
    EventProgress = {}, -- {[eventId] = {Points, ClaimedMilestones, Completions}}
    
    -- Daily Login
    Login = {TotalDays = 0, CurrentStreak = 0, MonthDay = 0, LastLogin = 0},
    
    -- Missions
    Missions = {DailyProgress = {}, WeeklyProgress = {}, DailyClaimed = {}, WeeklyClaimed = {}},
    
    -- Battle Pass
    BattlePass = {Level = 1, XP = 0, IsPremium = false, ClaimedFree = {}, ClaimedPremium = {}},
    
    -- VIP
    VIP = {TotalSpent = 0, Tier = 0},
    
    -- Settings
    Settings = {}, -- Filled with defaults
}
```

### RemoteEvents to Create

```lua
local events = {
    -- Daily Login
    "ClaimDailyLogin",
    "DailyLoginResult",
    
    -- Missions
    "ClaimMission",
    "MissionUpdate",
    
    -- Battle Pass
    "ClaimBattlePassReward",
    "PurchasePremiumPass",
    "BattlePassUpdate",
    
    -- Settings
    "UpdateSetting",
    "SyncSettings",
    
    -- Notifications
    "ShowNotification",
    
    -- Events
    "ClaimEventMilestone",
    "EventUpdate",
}
```

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Daily reset timing | Medium | Use UTC, server-side time |
| Battle pass reward duplication | High | Track claimed rewards server-side |
| VIP tier manipulation | Critical | Server validates all purchases |
| Mission progress exploits | Medium | Server validates all tracking updates |
| Audio asset loading | Low | Preload critical assets, fallback sounds |
| VFX performance | Medium | Pool particles, limit active count |

---

## Testing Checklist

- [ ] Daily login resets at correct time
- [ ] Login streak tracks correctly across days
- [ ] Monthly calendar resets each month
- [ ] Daily missions reset daily
- [ ] Weekly missions reset weekly
- [ ] Battle pass XP accumulates correctly
- [ ] Battle pass rewards can only be claimed once
- [ ] VIP tier upgrades on purchase
- [ ] VIP daily gems can only be claimed once/day
- [ ] Settings persist across sessions
- [ ] Audio volume respects settings
- [ ] VFX scales with quality settings
- [ ] Notifications queue properly
- [ ] Event points track correctly
- [ ] Event milestones can only be claimed once
