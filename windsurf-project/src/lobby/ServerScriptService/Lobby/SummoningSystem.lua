--[[
	SummoningSystem.lua
	Handles tower summoning (gacha) mechanics.
	All costs and rates are configured in GameConfig.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TowerData = require(Shared:WaitForChild("TowerData"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local PlayerDataManager = require(script.Parent.PlayerDataManager)

local SummoningSystem = {}

-- Perform a single summon
function SummoningSystem.SingleSummon(player)
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then return nil, "Player data not found" end
	
	local gems = playerData:FindFirstChild("Gems")
	local pityCounter = playerData:FindFirstChild("PityCounter")
	local mythicPityCounter = playerData:FindFirstChild("MythicPityCounter")
	
	if not gems or not pityCounter then
		return nil, "Missing player data"
	end
	
	local cost = GameConfig.Summoning.SingleSummonCost
	
	-- Check if player has enough gems
	if gems.Value < cost then
		return nil, "Not enough gems"
	end
	
	-- Deduct gems
	PlayerDataManager.ModifyGems(player, -cost)
	
	-- Increment pity counters
	pityCounter.Value = pityCounter.Value + 1
	if mythicPityCounter then
		mythicPityCounter.Value = mythicPityCounter.Value + 1
	end
	
	-- Get random tower (pass both pity counters)
	local tower = TowerData.GetRandomTower(pityCounter.Value, mythicPityCounter and mythicPityCounter.Value or 0)
	
	-- Reset pity counters based on rarity
	if tower.Rarity == "Mythic" then
		pityCounter.Value = 0
		if mythicPityCounter then
			mythicPityCounter.Value = 0
		end
	elseif tower.Rarity == "Legendary" then
		pityCounter.Value = 0
	end
	
	-- Create unit instance (new system with traits)
	local instanceId = PlayerDataManager.CreateUnitInstance(player, tower.ID, tower.Rarity)
	
	-- Increment total summons
	local totalSummons = playerData:FindFirstChild("TotalSummons")
	if totalSummons then
		totalSummons.Value = totalSummons.Value + 1
	end
	
	-- Get the created unit data for return
	local unitData = PlayerDataManager.GetUnitInstance(player, instanceId)
	
	print("[Summon]", player.Name, "summoned:", tower.Name, "(" .. tower.Rarity .. ") InstanceId:", instanceId)
	
	-- Return both tower info and instance data
	return {
		Tower = tower,
		InstanceId = instanceId,
		Traits = unitData and unitData.Traits or {},
	}, nil
end

-- Perform a multi summon
function SummoningSystem.MultiSummon(player)
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then return nil, "Player data not found" end
	
	local gems = playerData:FindFirstChild("Gems")
	local pityCounter = playerData:FindFirstChild("PityCounter")
	local mythicPityCounter = playerData:FindFirstChild("MythicPityCounter")
	
	if not gems or not pityCounter then
		return nil, "Missing player data"
	end
	
	local cost = GameConfig.Summoning.MultiSummonCost
	local pullCount = GameConfig.Summoning.MultiSummonCount
	
	-- Check if player has enough gems
	if gems.Value < cost then
		return nil, "Not enough gems"
	end
	
	-- Deduct gems
	PlayerDataManager.ModifyGems(player, -cost)
	
	-- Perform summons
	local results = {}
	for i = 1, pullCount do
		-- Increment pity counters
		pityCounter.Value = pityCounter.Value + 1
		if mythicPityCounter then
			mythicPityCounter.Value = mythicPityCounter.Value + 1
		end
		
		-- Get random tower
		local tower = TowerData.GetRandomTower(pityCounter.Value, mythicPityCounter and mythicPityCounter.Value or 0)
		
		-- Reset pity counters based on rarity
		if tower.Rarity == "Mythic" then
			pityCounter.Value = 0
			if mythicPityCounter then
				mythicPityCounter.Value = 0
			end
		elseif tower.Rarity == "Legendary" then
			pityCounter.Value = 0
		end
		
		-- Create unit instance (new system with traits)
		local instanceId = PlayerDataManager.CreateUnitInstance(player, tower.ID, tower.Rarity)
		
		-- Increment total summons
		local totalSummons = playerData:FindFirstChild("TotalSummons")
		if totalSummons then
			totalSummons.Value = totalSummons.Value + 1
		end
		
		-- Get the created unit data
		local unitData = PlayerDataManager.GetUnitInstance(player, instanceId)
		
		table.insert(results, {
			Tower = tower,
			InstanceId = instanceId,
			Traits = unitData and unitData.Traits or {},
		})
	end
	
	print("[Summon]", player.Name, "performed multi-summon (", pullCount, "towers)")
	
	return results, nil
end

-- Get summon costs (from GameConfig)
function SummoningSystem.GetCosts()
	return {
		Single = GameConfig.Summoning.SingleSummonCost,
		Multi = GameConfig.Summoning.MultiSummonCost,
		MultiCount = GameConfig.Summoning.MultiSummonCount,
	}
end

-- Get pity thresholds
function SummoningSystem.GetPityInfo()
	return {
		LegendaryThreshold = GameConfig.Summoning.LegendaryPityThreshold,
		MythicThreshold = GameConfig.Summoning.MythicPityThreshold,
	}
end

return SummoningSystem
