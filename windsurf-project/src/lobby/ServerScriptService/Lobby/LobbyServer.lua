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

print("Lobby server initialized")
