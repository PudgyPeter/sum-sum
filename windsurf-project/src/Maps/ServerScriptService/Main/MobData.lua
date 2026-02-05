-- MobData.lua
-- Defines all mob stats and properties for easy editing
-- Stats include health, speed, damage, rewards, and wave scaling

local MobData = {}

-- Mob definitions with all configurable stats
MobData.Mobs = {
	-- Basic mob
	PudgePete = {
		BaseHealth = 100,           -- Starting health at wave 1
		BaseSpeed = 16,             -- Movement speed
		BaseDamage = 1,             -- Damage dealt to base if reaches end
		BaseReward = 10,            -- Cash reward for killing (before wave multiplier)
		
		-- Wave scaling
		HealthScaling = 0.3,        -- +30% health per wave (wave 2 = 130%, wave 3 = 160%)
		SpeedScaling = 0,           -- No speed scaling by default
		DamageScaling = 0.1,        -- +10% damage per wave
		RewardScaling = 0.2,        -- +20% reward per wave
		
		-- Visual/identification
		DisplayName = "Pudge Pete",
		Description = "A basic enemy unit",
	},
	
	-- Faster, weaker mob
	CurioussGorge = {
		BaseHealth = 80,
		BaseSpeed = 20,
		BaseDamage = 1,
		BaseReward = 12,
		
		HealthScaling = 0.3,
		SpeedScaling = 0,
		DamageScaling = 0.1,
		RewardScaling = 0.2,
		
		DisplayName = "Curious Gorge",
		Description = "A faster but weaker enemy",
	},
	
	-- Stronger, slower mob
	illxstrate = {
		BaseHealth = 150,
		BaseSpeed = 12,
		BaseDamage = 2,
		BaseReward = 20,
		
		HealthScaling = 0.3,
		SpeedScaling = 0,
		DamageScaling = 0.1,
		RewardScaling = 0.2,
		
		DisplayName = "Illxstrate",
		Description = "A tanky enemy with high health",
	},
}

-- Get mob data by name
function MobData.GetMobData(mobName)
	return MobData.Mobs[mobName]
end

-- Calculate scaled health for a mob at a specific wave
function MobData.GetScaledHealth(mobName, waveNumber)
	local mobData = MobData.GetMobData(mobName)
	if not mobData then
		warn("MobData: Unknown mob type:", mobName)
		return 100 -- Default fallback
	end
	
	local multiplier = 1 + ((waveNumber - 1) * mobData.HealthScaling)
	return mobData.BaseHealth * multiplier
end

-- Calculate scaled speed for a mob at a specific wave
function MobData.GetScaledSpeed(mobName, waveNumber)
	local mobData = MobData.GetMobData(mobName)
	if not mobData then
		return 16 -- Default fallback
	end
	
	local multiplier = 1 + ((waveNumber - 1) * mobData.SpeedScaling)
	return mobData.BaseSpeed * multiplier
end

-- Calculate scaled damage for a mob at a specific wave
function MobData.GetScaledDamage(mobName, waveNumber)
	local mobData = MobData.GetMobData(mobName)
	if not mobData then
		return 1 -- Default fallback
	end
	
	local multiplier = 1 + ((waveNumber - 1) * mobData.DamageScaling)
	return mobData.BaseDamage * multiplier
end

-- Calculate scaled reward for a mob at a specific wave
function MobData.GetScaledReward(mobName, waveNumber)
	local mobData = MobData.GetMobData(mobName)
	if not mobData then
		return 10 -- Default fallback
	end
	
	local multiplier = 1 + ((waveNumber - 1) * mobData.RewardScaling)
	return math.floor(mobData.BaseReward * multiplier)
end

-- Get all scaled stats at once
function MobData.GetScaledStats(mobName, waveNumber)
	local mobData = MobData.GetMobData(mobName)
	if not mobData then
		warn("MobData: Unknown mob type:", mobName)
		return {
			Health = 100,
			Speed = 16,
			Damage = 1,
			Reward = 10,
		}
	end
	
	return {
		Health = MobData.GetScaledHealth(mobName, waveNumber),
		Speed = MobData.GetScaledSpeed(mobName, waveNumber),
		Damage = MobData.GetScaledDamage(mobName, waveNumber),
		Reward = MobData.GetScaledReward(mobName, waveNumber),
		DisplayName = mobData.DisplayName,
		Description = mobData.Description,
	}
end

-- Check if mob exists
function MobData.MobExists(mobName)
	return MobData.Mobs[mobName] ~= nil
end

-- Get list of all mob names
function MobData.GetAllMobNames()
	local names = {}
	for name, _ in pairs(MobData.Mobs) do
		table.insert(names, name)
	end
	return names
end

print("MobData module loaded - " .. #MobData.GetAllMobNames() .. " mob types defined")

return MobData
