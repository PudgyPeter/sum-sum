--[[
	XPManager.lua
	Server-side XP distribution and tracking system
	
	Usage:
		local XPManager = require(script.Parent.XPManager)
		XPManager.Register(player, tower, instanceId)
		XPManager.AwardToTower(player, tower, amount)
		XPManager.AwardToAll(player, amount)
		XPManager.Flush() -- Call at end of wave or periodically
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EvolutionSystem = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("EvolutionSystem"))
local PlayerDataManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PlayerDataManager"))

local XPManager = {}

-- Track deployed units: {[player] = {[tower] = instanceId}}
local deployedUnits = {}

-- Pending XP to be flushed: {[player] = {[instanceId] = xpAmount}}
local pendingXP = {}

-- Callbacks for evolution events
local evolutionCallbacks = {}

-- Register a tower with its unit instance ID
function XPManager.Register(player: Player, tower: any, instanceId: string)
	if not player or not tower or not instanceId then
		warn("[XPManager] Invalid registration parameters")
		return
	end
	
	deployedUnits[player] = deployedUnits[player] or {}
	deployedUnits[player][tower] = instanceId
	
	print(string.format("[XPManager] Registered tower %s for player %s (instance: %s)", 
		tower.Name, player.Name, instanceId))
end

-- Unregister a tower (when sold/destroyed)
function XPManager.Unregister(player: Player, tower: any)
	if deployedUnits[player] then
		deployedUnits[player][tower] = nil
	end
end

-- Award XP to a specific tower
function XPManager.AwardToTower(player: Player, tower: any, amount: number)
	if not player or not tower or amount <= 0 then
		return
	end
	
	local instanceId = deployedUnits[player] and deployedUnits[player][tower]
	if not instanceId then
		return
	end
	
	pendingXP[player] = pendingXP[player] or {}
	pendingXP[player][instanceId] = (pendingXP[player][instanceId] or 0) + amount
end

-- Award XP to all deployed towers for a player
function XPManager.AwardToAll(player: Player, amount: number)
	if not player or amount <= 0 then
		return
	end
	
	for tower, instanceId in pairs(deployedUnits[player] or {}) do
		pendingXP[player] = pendingXP[player] or {}
		pendingXP[player][instanceId] = (pendingXP[player][instanceId] or 0) + amount
	end
end

-- Award XP to all players' deployed towers
function XPManager.AwardToAllPlayers(amount: number)
	for player in pairs(deployedUnits) do
		XPManager.AwardToAll(player, amount)
	end
end

-- Award XP based on event type
function XPManager.AwardForEvent(player: Player, tower: any, eventType: string)
	local amount = EvolutionSystem.XPGain[eventType]
	if amount then
		XPManager.AwardToTower(player, tower, amount)
	end
end

-- Award event XP to all player towers
function XPManager.AwardForEventToAll(player: Player, eventType: string)
	local amount = EvolutionSystem.XPGain[eventType]
	if amount then
		XPManager.AwardToAll(player, amount)
	end
end

-- Award wave complete XP to all players
function XPManager.AwardWaveComplete()
	local amount = EvolutionSystem.XPGain.WaveComplete
	if amount then
		XPManager.AwardToAllPlayers(amount)
	end
end

-- Award act complete XP to all players
function XPManager.AwardActComplete()
	local amount = EvolutionSystem.XPGain.ActComplete
	if amount then
		XPManager.AwardToAllPlayers(amount)
	end
end

-- Flush pending XP to player data using PlayerDataManager
-- Returns table of evolutions that occurred: {[player] = {{instanceId, unitId, newStage}}}
function XPManager.Flush(): {[Player]: {{instanceId: string, unitId: string, newStage: number}}}
	local evolutions = {}
	
	for player, instances in pairs(pendingXP) do
		-- Skip if player left
		if not player or not player.Parent then
			continue
		end
		
		for instanceId, xp in pairs(instances) do
			-- Get current unit data
			local unitData = PlayerDataManager.GetUnitInstance(player, instanceId)
			if unitData then
				local oldXP = unitData.XP or 0
				local oldStage = unitData.EvolutionStage or 0
				local newXP = oldXP + xp
				
				-- Update XP in PlayerData
				PlayerDataManager.UpdateUnitXP(player, instanceId, xp)
				
				-- Check for evolution
				local newStage = EvolutionSystem.GetStage(unitData.UnitId, newXP)
				if newStage > oldStage then
					-- Update evolution stage
					PlayerDataManager.UpdateUnitEvolutionStage(player, instanceId, newStage)
					
					evolutions[player] = evolutions[player] or {}
					table.insert(evolutions[player], {
						instanceId = instanceId,
						unitId = unitData.UnitId,
						newStage = newStage,
					})
					
					print(string.format("[XPManager] %s's %s evolved to stage %d! (XP: %d)", 
						player.Name, unitData.UnitId, newStage, newXP))
					
					-- Fire callbacks
					for _, callback in ipairs(evolutionCallbacks) do
						task.spawn(callback, player, unitData, newStage)
					end
				end
			end
		end
	end
	
	-- Clear pending XP
	pendingXP = {}
	
	return evolutions
end

-- Get pending XP for a tower
function XPManager.GetPendingXP(player: Player, tower: any): number
	local instanceId = deployedUnits[player] and deployedUnits[player][tower]
	if not instanceId then
		return 0
	end
	
	return pendingXP[player] and pendingXP[player][instanceId] or 0
end

-- Get total pending XP for a player
function XPManager.GetTotalPendingXP(player: Player): number
	local total = 0
	for _, xp in pairs(pendingXP[player] or {}) do
		total = total + xp
	end
	return total
end

-- Get all deployed towers for a player
function XPManager.GetDeployedTowers(player: Player): {[any]: string}
	return deployedUnits[player] or {}
end

-- Register callback for evolution events
function XPManager.OnEvolution(callback: (Player, {[string]: any}, number) -> ())
	table.insert(evolutionCallbacks, callback)
end

-- Cleanup when player leaves
function XPManager.CleanupPlayer(player: Player)
	deployedUnits[player] = nil
	pendingXP[player] = nil
end

-- Cleanup when tower is destroyed
function XPManager.CleanupTower(player: Player, tower: any)
	if deployedUnits[player] then
		deployedUnits[player][tower] = nil
	end
end

return XPManager
