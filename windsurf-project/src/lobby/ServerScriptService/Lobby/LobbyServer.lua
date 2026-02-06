local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

-- Load GameConfig
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

-- Publish DataStore config so all maps can read it (single source of truth)
local CONFIG_STORE_NAME = "GameConfigStore" -- This name NEVER changes
local ConfigStore = DataStoreService:GetDataStore(CONFIG_STORE_NAME)

local function PublishDataStoreConfig()
	local config = {
		PlayerDataStoreName = GameConfig.DataStore.PlayerDataStoreName,
		LoadoutStoreName = GameConfig.DataStore.LoadoutStoreName,
		Version = GameConfig.DataStore.PlayerDataStoreName:match("_v(%d+)") or "1",
	}
	
	local success, err = pcall(function()
		ConfigStore:SetAsync("DataStoreConfig", config)
	end)
	
	if success then
		print("[LobbyServer] Published DataStore config: v" .. config.Version)
	else
		warn("[LobbyServer] Failed to publish DataStore config:", err)
	end
end

-- Publish config on server start
PublishDataStoreConfig()

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local SummoningSystem = require(script.Parent.SummoningSystem)
local TeleportManager = require(script.Parent.TeleportManager)
local MapProgressService = require(script.Parent.MapProgressService)
local PartyService = require(script.Parent.PartyService)
local TraitSystem = require(Shared:WaitForChild("TraitSystem"))
local RelicSystem = require(Shared:WaitForChild("RelicSystem"))
local EvolutionSystem = require(Shared:WaitForChild("EvolutionSystem"))

-- Get pre-created RemoteEvents and RemoteFunctions folders
local events = ReplicatedStorage:WaitForChild("Events")
local functions = ReplicatedStorage:WaitForChild("Functions")

-- Summoning functions
local SingleSummonFunction = functions:WaitForChild("SingleSummon")
local MultiSummonFunction = functions:WaitForChild("MultiSummon")

-- Inventory functions
local GetInventoryFunction = functions:WaitForChild("GetInventory")
local GetLoadoutFunction = functions:WaitForChild("GetLoadout")
local AddToLoadoutFunction = functions:WaitForChild("AddToLoadout")
local RemoveFromLoadoutFunction = functions:WaitForChild("RemoveFromLoadout")
local SetLoadoutSlotFunction = functions:WaitForChild("SetLoadoutSlot")

-- Player join setup
Players.PlayerAdded:Connect(function(player)
	PlayerDataManager.SetupPlayer(player)
end)

-- Handle players who joined before this script ran (race condition fix)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		PlayerDataManager.SetupPlayer(player)
	end)
end

-- Single summon handler
SingleSummonFunction.OnServerInvoke = function(player)
	local result, err = SummoningSystem.SingleSummon(player)
	if result then
		local tower = result.Tower
		return {
			Success = true,
			Tower = {
				ID = tower.ID,
				Name = tower.Name,
				Rarity = tower.Rarity,
				Description = tower.Description,
				ModelName = tower.ModelName,
			},
			InstanceId = result.InstanceId,
			Traits = result.Traits,
		}
	else
		return {
			Success = false,
			Error = err
		}
	end
end

-- Multi summon handler
MultiSummonFunction.OnServerInvoke = function(player)
	local results, err = SummoningSystem.MultiSummon(player)
	if results then
		local towerData = {}
		for _, result in ipairs(results) do
			local tower = result.Tower
			table.insert(towerData, {
				ID = tower.ID,
				Name = tower.Name,
				Rarity = tower.Rarity,
				Description = tower.Description,
				ModelName = tower.ModelName,
				InstanceId = result.InstanceId,
				Traits = result.Traits,
			})
		end
		return {
			Success = true,
			Towers = towerData
		}
	else
		return {
			Success = false,
			Error = err
		}
	end
end

-- Get inventory handler
GetInventoryFunction.OnServerInvoke = function(player)
	return PlayerDataManager.GetInventory(player)
end

-- Get loadout handler (returns full unit data for each slot)
GetLoadoutFunction.OnServerInvoke = function(player)
	local slots = PlayerDataManager.GetLoadout(player)
	local result = {}
	
	for i = 1, 6 do
		if slots[i] and slots[i] ~= false then
			-- Get full unit data for this instance
			local unitData = PlayerDataManager.GetUnitInstance(player, slots[i])
			if unitData then
				result[i] = {
					InstanceId = slots[i],
					TowerId = unitData.UnitId,
					Rarity = unitData.Rarity,
					XP = unitData.XP,
					EvolutionStage = unitData.EvolutionStage,
					Traits = unitData.Traits,
				}
			else
				result[i] = false
			end
		else
			result[i] = false
		end
	end
	
	return result
end

-- Add to loadout handler
AddToLoadoutFunction.OnServerInvoke = function(player, towerId)
	return PlayerDataManager.AddToLoadout(player, towerId)
end

-- Remove from loadout handler
RemoveFromLoadoutFunction.OnServerInvoke = function(player, towerId)
	return PlayerDataManager.RemoveFromLoadout(player, towerId)
end

-- Set loadout slot handler (for swap system)
SetLoadoutSlotFunction.OnServerInvoke = function(player, towerId, slotNumber)
	print("[LobbyServer] SetLoadoutSlot called - towerId:", towerId, "slotNumber:", slotNumber, "type:", type(slotNumber))
	-- First remove the tower if it's already in another slot
	PlayerDataManager.RemoveFromLoadout(player, towerId)
	-- Then add to the specified slot
	local success, result = PlayerDataManager.AddToLoadout(player, towerId, slotNumber)
	print("[LobbyServer] AddToLoadout result - success:", success, "result:", result)
	return success, result
end

--------------------------------------------------------------------------------
-- UNIT MANAGEMENT FUNCTIONS
--------------------------------------------------------------------------------

-- Create remote functions for unit management (if they don't exist)
local function getOrCreateFunction(name)
	local func = functions:FindFirstChild(name)
	if not func then
		func = Instance.new("RemoteFunction")
		func.Name = name
		func.Parent = functions
	end
	return func
end

local GetUnitDetailsFunction = getOrCreateFunction("GetUnitDetails")
local RerollTraitFunction = getOrCreateFunction("RerollTrait")
local GetRelicInventoryFunction = getOrCreateFunction("GetRelicInventory")
local EquipRelicFunction = getOrCreateFunction("EquipRelic")
local UnequipRelicFunction = getOrCreateFunction("UnequipRelic")
local EvolveUnitFunction = getOrCreateFunction("EvolveUnit")
local GetEvolutionInfoFunction = getOrCreateFunction("GetEvolutionInfo")
local SellUnitsFunction = getOrCreateFunction("SellUnits")
local LockUnitFunction = getOrCreateFunction("LockUnit")

-- Get unit details handler
GetUnitDetailsFunction.OnServerInvoke = function(player, instanceId)
	local unitData = PlayerDataManager.GetUnitInstance(player, instanceId)
	if not unitData then
		return {Success = false, Error = "Unit not found"}
	end
	
	-- Add trait descriptions
	local traitDescriptions = TraitSystem.GetDescriptions(unitData.Traits or {})
	local traitBonuses = TraitSystem.Calculate(unitData.Traits or {})
	
	-- Add evolution info
	local evolutionData = EvolutionSystem.GetStageData(unitData.UnitId, unitData.EvolutionStage or 0)
	local nextStageXP = EvolutionSystem.GetXPForNextStage(unitData.UnitId, unitData.EvolutionStage or 0)
	local canEvolve, evolveReason = EvolutionSystem.CanEvolve(unitData.UnitId, unitData.XP or 0, unitData.EvolutionStage or 0)
	
	return {
		Success = true,
		Unit = unitData,
		TraitDescriptions = traitDescriptions,
		TraitBonuses = traitBonuses,
		EvolutionData = evolutionData,
		NextStageXP = nextStageXP,
		CanEvolve = canEvolve,
		EvolveReason = evolveReason,
	}
end

-- Reroll trait handler
RerollTraitFunction.OnServerInvoke = function(player, instanceId, traitToReroll)
	local unitData = PlayerDataManager.GetUnitInstance(player, instanceId)
	if not unitData then
		return {Success = false, Error = "Unit not found"}
	end
	
	-- Check if trait exists on unit
	if not table.find(unitData.Traits or {}, traitToReroll) then
		return {Success = false, Error = "Trait not found on unit"}
	end
	
	-- Check cost
	local cost = GameConfig.Traits.RerollCost
	if not PlayerDataManager.CanAfford(player, "Coins", cost) then
		return {Success = false, Error = "Not enough Coins (need " .. cost .. ")"}
	end
	
	-- Deduct cost
	PlayerDataManager.ModifyCurrency(player, "Coins", -cost)
	
	-- Reroll the trait
	local newTraits = TraitSystem.Reroll(unitData.Traits, traitToReroll, unitData.Rarity or "Common")
	PlayerDataManager.UpdateUnitTraits(player, instanceId, newTraits)
	
	-- Get updated unit data
	local updatedUnit = PlayerDataManager.GetUnitInstance(player, instanceId)
	
	return {
		Success = true,
		NewTraits = newTraits,
		TraitDescriptions = TraitSystem.GetDescriptions(newTraits),
		TraitBonuses = TraitSystem.Calculate(newTraits),
		Unit = updatedUnit,
	}
end

--------------------------------------------------------------------------------
-- SELL & LOCK FUNCTIONS
--------------------------------------------------------------------------------

-- Sell units handler
SellUnitsFunction.OnServerInvoke = function(player, instanceIds)
	if not instanceIds or type(instanceIds) ~= "table" then
		return {Success = false, Error = "Invalid instance IDs"}
	end
	
	local success, totalCoins, soldCount, skippedLocked, skippedLoadout = PlayerDataManager.SellUnits(player, instanceIds)
	
	if success then
		return {
			Success = true,
			TotalCoins = totalCoins,
			SoldCount = soldCount,
			SkippedLocked = skippedLocked,
			SkippedLoadout = skippedLoadout,
		}
	else
		return {Success = false, Error = totalCoins} -- totalCoins contains error message on failure
	end
end

-- Lock/unlock unit handler
LockUnitFunction.OnServerInvoke = function(player, instanceId, locked)
	if not instanceId then
		return {Success = false, Error = "Invalid instance ID"}
	end
	
	local success = PlayerDataManager.SetUnitLocked(player, instanceId, locked)
	
	if success then
		return {Success = true, Locked = locked}
	else
		return {Success = false, Error = "Failed to update lock status"}
	end
end

--------------------------------------------------------------------------------
-- RELIC FUNCTIONS
--------------------------------------------------------------------------------

-- Get relic inventory handler
GetRelicInventoryFunction.OnServerInvoke = function(player)
	return PlayerDataManager.GetRelicInventory(player)
end

-- Equip relic handler
EquipRelicFunction.OnServerInvoke = function(player, instanceId, relicId)
	-- Get the relic
	local relic = PlayerDataManager.GetRelic(player, relicId)
	if not relic then
		return {Success = false, Error = "Relic not found"}
	end
	
	-- Get the unit
	local unitData = PlayerDataManager.GetUnitInstance(player, instanceId)
	if not unitData then
		return {Success = false, Error = "Unit not found"}
	end
	
	-- Equip the relic
	local success = PlayerDataManager.EquipRelic(player, instanceId, relicId, relic.Slot)
	if success then
		return {Success = true, Slot = relic.Slot}
	else
		return {Success = false, Error = "Failed to equip relic"}
	end
end

-- Unequip relic handler
UnequipRelicFunction.OnServerInvoke = function(player, instanceId, slot)
	local success = PlayerDataManager.UnequipRelic(player, instanceId, slot)
	if success then
		return {Success = true}
	else
		return {Success = false, Error = "Failed to unequip relic"}
	end
end

--------------------------------------------------------------------------------
-- EVOLUTION FUNCTIONS
--------------------------------------------------------------------------------

-- Get evolution info handler
GetEvolutionInfoFunction.OnServerInvoke = function(player, instanceId)
	local unitData = PlayerDataManager.GetUnitInstance(player, instanceId)
	if not unitData then
		return {Success = false, Error = "Unit not found"}
	end
	
	local currentStage = unitData.EvolutionStage or 0
	local xp = unitData.XP or 0
	
	-- Get all stage data for this unit
	local stages = {}
	for i = 0, EvolutionSystem.MaxStageWithTrial do
		local stageData = EvolutionSystem.GetStageData(unitData.UnitId, i)
		if stageData then
			stages[i] = stageData
		end
	end
	
	local canEvolve, evolveReason = EvolutionSystem.CanEvolve(unitData.UnitId, xp, currentStage)
	local progress = EvolutionSystem.GetProgress(unitData.UnitId, xp, currentStage)
	
	return {
		Success = true,
		CurrentStage = currentStage,
		XP = xp,
		Stages = stages,
		CanEvolve = canEvolve,
		EvolveReason = evolveReason,
		Progress = progress,
	}
end

-- Evolve unit handler
EvolveUnitFunction.OnServerInvoke = function(player, instanceId)
	local unitData = PlayerDataManager.GetUnitInstance(player, instanceId)
	if not unitData then
		return {Success = false, Error = "Unit not found"}
	end
	
	local currentStage = unitData.EvolutionStage or 0
	local xp = unitData.XP or 0
	
	-- Check if can evolve
	local canEvolve, reason = EvolutionSystem.CanEvolve(unitData.UnitId, xp, currentStage)
	if not canEvolve then
		return {Success = false, Error = reason or "Cannot evolve"}
	end
	
	-- Check cost if any
	local cost = GameConfig.Evolution.EvolveCost
	if cost > 0 then
		local currency = GameConfig.Evolution.EvolveCurrency
		if not PlayerDataManager.CanAfford(player, currency, cost) then
			return {Success = false, Error = "Not enough " .. currency .. " (need " .. cost .. ")"}
		end
		PlayerDataManager.ModifyCurrency(player, currency, -cost)
	end
	
	-- Evolve the unit
	local newStage = currentStage + 1
	local success = PlayerDataManager.SetEvolutionStage(player, instanceId, newStage)
	
	if success then
		local newStageData = EvolutionSystem.GetStageData(unitData.UnitId, newStage)
		return {
			Success = true,
			NewStage = newStage,
			StageData = newStageData,
		}
	else
		return {Success = false, Error = "Failed to evolve unit"}
	end
end

print("Lobby server initialized")
