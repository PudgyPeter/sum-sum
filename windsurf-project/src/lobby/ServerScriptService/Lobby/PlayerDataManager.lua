--[[
	PlayerDataManager.lua
	Manages player data structure, serialization, and in-game values.
	This is the ONLY place that knows about the data schema.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local DataStoreManager = require(script.Parent.DataStoreManager)
local TraitSystem = require(Shared:WaitForChild("TraitSystem"))

local PlayerDataManager = {}

-- Cache of player data for quick access
local playerDataCache = {}

--------------------------------------------------------------------------------
-- SCHEMA DEFINITION
--------------------------------------------------------------------------------

-- Get default data structure for new players
local function getDefaultData()
	return {
		-- Version for future migrations
		SchemaVersion = 2,
		
		-- Currencies
		Gems = GameConfig.GetStartingCurrency("Gems"),
		Coins = GameConfig.GetStartingCurrency("Coins"),
		Tickets = GameConfig.GetStartingCurrency("Tickets"),
		
		-- LEGACY: Inventory array (for migration only)
		Inventory = {},
		
		-- NEW: UnitInstances - each unit is unique with its own data
		-- Format: { ["uuid"] = {UnitId, XP, EvolutionStage, Traits, EquippedRelics, ...} }
		UnitInstances = {},
		
		-- Loadout: indexed by slot number (1-6) to preserve positions
		-- Now references UnitInstance UUIDs instead of tower IDs
		Loadout = {},
		
		-- Relic inventory (separate from unit-equipped relics)
		RelicInventory = {},
		
		-- Map progress: track highest completed act per map
		MapProgress = {},
		
		-- Summoning stats
		SummonHistory = {
			TotalSummons = 0,
			PityCounter = 0, -- Summons since last legendary
			MythicPityCounter = 0, -- Summons since last mythic
		},
		
		-- Stats tracking
		Stats = {
			TotalGamesPlayed = 0,
			TotalWaves = 0,
			TotalMobsKilled = 0,
			TotalGemsEarned = 0,
		},
	}
end

-- Deep merge: fills in missing fields from defaults
-- This ensures old player data gets new fields without losing existing data
local function deepMerge(saved, defaults)
	if saved == nil then
		return defaults
	end
	
	if type(defaults) ~= "table" then
		return saved
	end
	
	local result = {}
	
	-- Copy all saved values
	for key, value in pairs(saved) do
		if type(value) == "table" and type(defaults[key]) == "table" then
			result[key] = deepMerge(value, defaults[key])
		else
			result[key] = value
		end
	end
	
	-- Add missing defaults
	for key, value in pairs(defaults) do
		if result[key] == nil then
			if type(value) == "table" then
				result[key] = deepMerge(nil, value)
			else
				result[key] = value
			end
		end
	end
	
	return result
end

--------------------------------------------------------------------------------
-- SERIALIZATION (Single source of truth)
--------------------------------------------------------------------------------

-- Convert in-game PlayerData folder to saveable table
function PlayerDataManager.SerializePlayerData(player)
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then
		warn("[PlayerData] Cannot serialize - no PlayerData folder for", player.Name)
		return nil
	end
	
	local data = {
		SchemaVersion = 2,
		Gems = playerData.Gems.Value,
		Coins = playerData.Coins and playerData.Coins.Value or 0,
		Tickets = playerData.Tickets and playerData.Tickets.Value or 0,
		Inventory = {}, -- Legacy, kept for safety
		UnitInstances = {},
		Loadout = {},
		RelicInventory = {},
		MapProgress = {},
		SummonHistory = {
			TotalSummons = playerData.TotalSummons.Value,
			PityCounter = playerData.PityCounter.Value,
			MythicPityCounter = playerData.MythicPityCounter and playerData.MythicPityCounter.Value or 0,
		},
		Stats = {
			TotalGamesPlayed = playerData.Stats and playerData.Stats.TotalGamesPlayed and playerData.Stats.TotalGamesPlayed.Value or 0,
			TotalWaves = playerData.Stats and playerData.Stats.TotalWaves and playerData.Stats.TotalWaves.Value or 0,
			TotalMobsKilled = playerData.Stats and playerData.Stats.TotalMobsKilled and playerData.Stats.TotalMobsKilled.Value or 0,
			TotalGemsEarned = playerData.Stats and playerData.Stats.TotalGemsEarned and playerData.Stats.TotalGemsEarned.Value or 0,
		},
	}
	
	-- Serialize map progress
	local mapProgress = playerData:FindFirstChild("MapProgress")
	if mapProgress then
		for _, progress in ipairs(mapProgress:GetChildren()) do
			if progress:IsA("StringValue") then
				local mapId, actStr = progress.Value:match("^(.+):(%d+)$")
				if mapId and actStr then
					data.MapProgress[mapId] = tonumber(actStr)
				end
			end
		end
	end
	
	-- Serialize UnitInstances (new system)
	local unitInstances = playerData:FindFirstChild("UnitInstances")
	if unitInstances then
		for _, instance in ipairs(unitInstances:GetChildren()) do
			if instance:IsA("Folder") then
				local instanceData = {
					UnitId = instance:GetAttribute("UnitId"),
					XP = instance:GetAttribute("XP") or 0,
					EvolutionStage = instance:GetAttribute("EvolutionStage") or 0,
					Traits = {},
					EquippedRelics = {},
					DateObtained = instance:GetAttribute("DateObtained") or 0,
					Locked = instance:GetAttribute("Locked") or false,
					Rarity = instance:GetAttribute("Rarity") or "Common",
				}
				
				-- Serialize traits
				local traitsFolder = instance:FindFirstChild("Traits")
				if traitsFolder then
					for _, trait in ipairs(traitsFolder:GetChildren()) do
						if trait:IsA("StringValue") then
							table.insert(instanceData.Traits, trait.Value)
						end
					end
				end
				
				-- Serialize equipped relics
				local relicsFolder = instance:FindFirstChild("EquippedRelics")
				if relicsFolder then
					for _, relic in ipairs(relicsFolder:GetChildren()) do
						if relic:IsA("StringValue") then
							instanceData.EquippedRelics[relic.Name] = relic.Value
						end
					end
				end
				
				data.UnitInstances[instance.Name] = instanceData
			end
		end
	end
	
	-- Serialize relic inventory
	local relicInventory = playerData:FindFirstChild("RelicInventory")
	if relicInventory then
		for _, relic in ipairs(relicInventory:GetChildren()) do
			if relic:IsA("Folder") then
				local relicData = {
					ID = relic.Name,
					Slot = relic:GetAttribute("Slot"),
					Rarity = relic:GetAttribute("Rarity"),
					Set = relic:GetAttribute("Set"),
					MainStat = relic:GetAttribute("MainStat"),
					MainValue = relic:GetAttribute("MainValue"),
					Level = relic:GetAttribute("Level") or 0,
					MaxLevel = relic:GetAttribute("MaxLevel") or 8,
					Substats = {},
				}
				
				local substats = relic:FindFirstChild("Substats")
				if substats then
					for _, substat in ipairs(substats:GetChildren()) do
						if substat:IsA("NumberValue") then
							relicData.Substats[substat.Name] = substat.Value
						end
					end
				end
				
				table.insert(data.RelicInventory, relicData)
			end
		end
	end
	
	-- Serialize loadout (now stores instance UUIDs, using string keys for DataStore compatibility)
	local loadout = playerData:FindFirstChild("Loadout")
	if loadout then
		for _, slot in ipairs(loadout:GetChildren()) do
			if slot:IsA("StringValue") then
				local slotNumber = tonumber(slot.Name:match("Slot_(%d+)"))
				if slotNumber then
					data.Loadout["Slot_" .. slotNumber] = slot.Value
				end
			end
		end
	end
	
	return data
end

--------------------------------------------------------------------------------
-- PLAYER SETUP
--------------------------------------------------------------------------------

-- Setup player data when they join
function PlayerDataManager.SetupPlayer(player)
	-- Load raw data from DataStore
	local rawData = DataStoreManager.LoadData(player)
	
	-- Merge with defaults (handles missing fields from old saves)
	local data = deepMerge(rawData, getDefaultData())
	
	-- Cache the data
	playerDataCache[player.UserId] = data
	
	-- Create PlayerData folder to store values
	local playerDataFolder = Instance.new("Folder")
	playerDataFolder.Name = "PlayerData"
	playerDataFolder.Parent = player
	
	-- Currencies
	local gems = Instance.new("IntValue")
	gems.Name = "Gems"
	gems.Value = data.Gems
	gems.Parent = playerDataFolder
	
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = data.Coins or 0
	coins.Parent = playerDataFolder
	
	local tickets = Instance.new("IntValue")
	tickets.Name = "Tickets"
	tickets.Value = data.Tickets or 0
	tickets.Parent = playerDataFolder
	
	-- Total summons counter
	local totalSummons = Instance.new("IntValue")
	totalSummons.Name = "TotalSummons"
	totalSummons.Value = data.SummonHistory.TotalSummons
	totalSummons.Parent = playerDataFolder
	
	-- Pity counter (for guaranteed legendary)
	local pityCounter = Instance.new("IntValue")
	pityCounter.Name = "PityCounter"
	pityCounter.Value = data.SummonHistory.PityCounter
	pityCounter.Parent = playerDataFolder
	
	-- Mythic pity counter
	local mythicPityCounter = Instance.new("IntValue")
	mythicPityCounter.Name = "MythicPityCounter"
	mythicPityCounter.Value = data.SummonHistory.MythicPityCounter or 0
	mythicPityCounter.Parent = playerDataFolder
	
	-- Stats folder
	local statsFolder = Instance.new("Folder")
	statsFolder.Name = "Stats"
	statsFolder.Parent = playerDataFolder
	
	local totalGamesPlayed = Instance.new("IntValue")
	totalGamesPlayed.Name = "TotalGamesPlayed"
	totalGamesPlayed.Value = data.Stats.TotalGamesPlayed
	totalGamesPlayed.Parent = statsFolder
	
	local totalWaves = Instance.new("IntValue")
	totalWaves.Name = "TotalWaves"
	totalWaves.Value = data.Stats.TotalWaves
	totalWaves.Parent = statsFolder
	
	local totalMobsKilled = Instance.new("IntValue")
	totalMobsKilled.Name = "TotalMobsKilled"
	totalMobsKilled.Value = data.Stats.TotalMobsKilled
	totalMobsKilled.Parent = statsFolder
	
	local totalGemsEarned = Instance.new("IntValue")
	totalGemsEarned.Name = "TotalGemsEarned"
	totalGemsEarned.Value = data.Stats.TotalGemsEarned
	totalGemsEarned.Parent = statsFolder
	
	-- Map progress folder
	local mapProgress = Instance.new("Folder")
	mapProgress.Name = "MapProgress"
	mapProgress.Parent = playerDataFolder
	
	-- Load map progress
	for mapId, actNumber in pairs(data.MapProgress) do
		local progressValue = Instance.new("StringValue")
		progressValue.Name = mapId
		progressValue.Value = mapId .. ":" .. actNumber
		progressValue.Parent = mapProgress
	end
	
	-- UnitInstances folder (new system - each unit is unique)
	local unitInstances = Instance.new("Folder")
	unitInstances.Name = "UnitInstances"
	unitInstances.Parent = playerDataFolder
	
	-- Load unit instances
	for instanceId, instanceData in pairs(data.UnitInstances or {}) do
		local instanceFolder = Instance.new("Folder")
		instanceFolder.Name = instanceId
		instanceFolder:SetAttribute("UnitId", instanceData.UnitId)
		instanceFolder:SetAttribute("XP", instanceData.XP or 0)
		instanceFolder:SetAttribute("EvolutionStage", instanceData.EvolutionStage or 0)
		instanceFolder:SetAttribute("DateObtained", instanceData.DateObtained or 0)
		instanceFolder:SetAttribute("Locked", instanceData.Locked or false)
		instanceFolder:SetAttribute("Rarity", instanceData.Rarity or "Common")
		instanceFolder.Parent = unitInstances
		
		-- Traits subfolder
		local traitsFolder = Instance.new("Folder")
		traitsFolder.Name = "Traits"
		traitsFolder.Parent = instanceFolder
		
		for i, traitName in ipairs(instanceData.Traits or {}) do
			local traitValue = Instance.new("StringValue")
			traitValue.Name = "Trait_" .. i
			traitValue.Value = traitName
			traitValue.Parent = traitsFolder
		end
		
		-- Equipped relics subfolder
		local relicsFolder = Instance.new("Folder")
		relicsFolder.Name = "EquippedRelics"
		relicsFolder.Parent = instanceFolder
		
		for slotName, relicId in pairs(instanceData.EquippedRelics or {}) do
			local relicValue = Instance.new("StringValue")
			relicValue.Name = slotName
			relicValue.Value = relicId
			relicValue.Parent = relicsFolder
		end
	end
	
	-- RelicInventory folder
	local relicInventory = Instance.new("Folder")
	relicInventory.Name = "RelicInventory"
	relicInventory.Parent = playerDataFolder
	
	-- Load relic inventory
	for _, relicData in ipairs(data.RelicInventory or {}) do
		local relicFolder = Instance.new("Folder")
		relicFolder.Name = relicData.ID
		relicFolder:SetAttribute("Slot", relicData.Slot)
		relicFolder:SetAttribute("Rarity", relicData.Rarity)
		relicFolder:SetAttribute("Set", relicData.Set)
		relicFolder:SetAttribute("MainStat", relicData.MainStat)
		relicFolder:SetAttribute("MainValue", relicData.MainValue)
		relicFolder:SetAttribute("Level", relicData.Level or 0)
		relicFolder:SetAttribute("MaxLevel", relicData.MaxLevel or 8)
		relicFolder.Parent = relicInventory
		
		-- Substats subfolder
		local substatsFolder = Instance.new("Folder")
		substatsFolder.Name = "Substats"
		substatsFolder.Parent = relicFolder
		
		for statName, statValue in pairs(relicData.Substats or {}) do
			local statValueObj = Instance.new("NumberValue")
			statValueObj.Name = statName
			statValueObj.Value = statValue
			statValueObj.Parent = substatsFolder
		end
	end
	
	-- LEGACY: Inventory folder (kept for migration/backward compatibility)
	local inventory = Instance.new("Folder")
	inventory.Name = "Inventory"
	inventory.Parent = playerDataFolder
	
	-- Migrate old inventory to UnitInstances if needed
	if data.SchemaVersion == 1 or (data.Inventory and #data.Inventory > 0 and not next(data.UnitInstances or {})) then
		print("[PlayerData] Migrating legacy inventory to UnitInstances for", player.Name)
		for i, towerId in ipairs(data.Inventory or {}) do
			local newInstanceId = HttpService:GenerateGUID(false)
			local instanceFolder = Instance.new("Folder")
			instanceFolder.Name = newInstanceId
			instanceFolder:SetAttribute("UnitId", towerId)
			instanceFolder:SetAttribute("XP", 0)
			instanceFolder:SetAttribute("EvolutionStage", 0)
			instanceFolder:SetAttribute("DateObtained", os.time())
			instanceFolder:SetAttribute("Locked", false)
			instanceFolder:SetAttribute("Rarity", "Common")
			instanceFolder.Parent = unitInstances
			
			local traitsFolder = Instance.new("Folder")
			traitsFolder.Name = "Traits"
			traitsFolder.Parent = instanceFolder
			
			local relicsFolder = Instance.new("Folder")
			relicsFolder.Name = "EquippedRelics"
			relicsFolder.Parent = instanceFolder
		end
	end
	
	-- Loadout folder (now stores instance UUIDs)
	local loadout = Instance.new("Folder")
	loadout.Name = "Loadout"
	loadout.Parent = playerDataFolder
	
	-- Load loadout (supports both string keys "Slot_N" and legacy numeric keys)
	for key, instanceId in pairs(data.Loadout) do
		local slotNumber
		if type(key) == "string" then
			slotNumber = tonumber(key:match("Slot_(%d+)"))
		else
			slotNumber = key
		end
		
		if slotNumber and slotNumber >= 1 and slotNumber <= 6 then
			local slotValue = Instance.new("StringValue")
			slotValue.Name = "Slot_" .. slotNumber
			slotValue.Value = instanceId
			slotValue.Parent = loadout
		end
	end
	
	print("[PlayerData] Setup complete for", player.Name)
	return playerDataFolder
end

--------------------------------------------------------------------------------
-- SAVE PLAYER DATA
--------------------------------------------------------------------------------

function PlayerDataManager.SavePlayer(player)
	local data = PlayerDataManager.SerializePlayerData(player)
	if data then
		return DataStoreManager.SaveData(player, data)
	end
	return false
end

-- Auto-save on player leaving
Players.PlayerRemoving:Connect(function(player)
	PlayerDataManager.SavePlayer(player)
	playerDataCache[player.UserId] = nil
end)

--------------------------------------------------------------------------------
-- INVENTORY MANAGEMENT
--------------------------------------------------------------------------------

-- Add tower to player's inventory
function PlayerDataManager.AddTowerToInventory(player, towerId)
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then return false end
	
	local inventory = playerData:FindFirstChild("Inventory")
	if not inventory then return false end
	
	-- Create unique name for duplicate towers
	local uniqueName = "Tower_" .. os.time() .. "_" .. math.random(1000, 9999) .. "_" .. towerId
	
	local towerValue = Instance.new("StringValue")
	towerValue.Name = uniqueName
	towerValue.Value = towerId
	towerValue.Parent = inventory
	
	print("[PlayerData] Added", towerId, "to", player.Name, "'s inventory")
	return true
end

-- Remove tower from inventory
function PlayerDataManager.RemoveTowerFromInventory(player, towerInstanceName)
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then return false end
	
	local inventory = playerData:FindFirstChild("Inventory")
	if not inventory then return false end
	
	local tower = inventory:FindFirstChild(towerInstanceName)
	if tower then
		tower:Destroy()
		print("[PlayerData] Removed", towerInstanceName, "from", player.Name, "'s inventory")
		return true
	end
	
	return false
end

--------------------------------------------------------------------------------
-- LOADOUT MANAGEMENT (Indexed slots 1-6)
--------------------------------------------------------------------------------

-- Add unit instance to specific loadout slot (new system - uses instance UUID)
function PlayerDataManager.AddToLoadout(player, instanceId, slotNumber)
	print("[PlayerData] AddToLoadout called - instanceId:", instanceId, "slotNumber:", slotNumber)
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then return false, "No player data" end
	
	local loadout = playerData:FindFirstChild("Loadout")
	if not loadout then return false, "No loadout folder" end
	
	local unitInstances = playerData:FindFirstChild("UnitInstances")
	if not unitInstances then return false, "No unit instances folder" end
	
	-- Verify the instance exists
	local instance = unitInstances:FindFirstChild(instanceId)
	if not instance then
		warn("[PlayerData] Unit instance not found:", instanceId)
		return false, "Unit instance not found"
	end
	
	-- If no slot specified, find first empty slot
	if not slotNumber then
		for i = 1, GameConfig.Loadout.MaxSlots do
			if not loadout:FindFirstChild("Slot_" .. i) then
				slotNumber = i
				break
			end
		end
	end
	
	if not slotNumber then
		warn("[PlayerData] Loadout is full for", player.Name)
		return false, "Loadout is full"
	end
	
	-- Validate slot number
	if slotNumber < 1 or slotNumber > GameConfig.Loadout.MaxSlots then
		return false, "Invalid slot number"
	end
	
	-- Check if instance is already in loadout (in another slot)
	for _, slot in ipairs(loadout:GetChildren()) do
		if slot:IsA("StringValue") and slot.Value == instanceId then
			warn("[PlayerData] Unit already in loadout:", instanceId)
			return false, "Unit already in loadout"
		end
	end
	
	-- Check if same tower TYPE is already in loadout (only one of each tower type allowed)
	local newUnitId = instance:GetAttribute("UnitId")
	for _, slot in ipairs(loadout:GetChildren()) do
		if slot:IsA("StringValue") then
			local existingInstance = unitInstances:FindFirstChild(slot.Value)
			if existingInstance then
				local existingUnitId = existingInstance:GetAttribute("UnitId")
				if existingUnitId == newUnitId then
					warn("[PlayerData] Tower type already in loadout:", newUnitId)
					return false, "You already have this tower type in your loadout"
				end
			end
		end
	end
	
	-- Remove existing unit in this slot if any
	local existingSlot = loadout:FindFirstChild("Slot_" .. slotNumber)
	if existingSlot then
		existingSlot:Destroy()
	end
	
	-- Add to slot
	local slotValue = Instance.new("StringValue")
	slotValue.Name = "Slot_" .. slotNumber
	slotValue.Value = instanceId
	slotValue.Parent = loadout
	
	local unitId = instance:GetAttribute("UnitId")
	print("[PlayerData] Added", unitId, "(", instanceId, ") to", player.Name, "'s loadout slot", slotNumber)
	return true, slotNumber
end

-- Remove unit from loadout (by instance ID or slot number)
function PlayerDataManager.RemoveFromLoadout(player, instanceIdOrSlot)
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then return false end
	
	local loadout = playerData:FindFirstChild("Loadout")
	if not loadout then return false end
	
	-- Check if it's a slot number
	if type(instanceIdOrSlot) == "number" then
		local slot = loadout:FindFirstChild("Slot_" .. instanceIdOrSlot)
		if slot then
			local instanceId = slot.Value
			slot:Destroy()
			print("[PlayerData] Removed slot", instanceIdOrSlot, "from", player.Name, "'s loadout")
			return true, instanceId
		end
	else
		-- It's an instance ID - find and remove it
		for _, slot in ipairs(loadout:GetChildren()) do
			if slot:IsA("StringValue") and slot.Value == instanceIdOrSlot then
				local slotNumber = tonumber(slot.Name:match("Slot_(%d+)"))
				slot:Destroy()
				print("[PlayerData] Removed instance", instanceIdOrSlot, "from", player.Name, "'s loadout")
				return true, slotNumber
			end
		end
	end
	
	return false
end

-- Swap two loadout slots
function PlayerDataManager.SwapLoadoutSlots(player, slot1, slot2)
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then return false end
	
	local loadout = playerData:FindFirstChild("Loadout")
	if not loadout then return false end
	
	local slotObj1 = loadout:FindFirstChild("Slot_" .. slot1)
	local slotObj2 = loadout:FindFirstChild("Slot_" .. slot2)
	
	local value1 = slotObj1 and slotObj1.Value or nil
	local value2 = slotObj2 and slotObj2.Value or nil
	
	-- Clear both slots
	if slotObj1 then slotObj1:Destroy() end
	if slotObj2 then slotObj2:Destroy() end
	
	-- Recreate with swapped values
	if value2 then
		local newSlot1 = Instance.new("StringValue")
		newSlot1.Name = "Slot_" .. slot1
		newSlot1.Value = value2
		newSlot1.Parent = loadout
	end
	
	if value1 then
		local newSlot2 = Instance.new("StringValue")
		newSlot2.Name = "Slot_" .. slot2
		newSlot2.Value = value1
		newSlot2.Parent = loadout
	end
	
	print("[PlayerData] Swapped slots", slot1, "and", slot2, "for", player.Name)
	return true
end

--------------------------------------------------------------------------------
-- CURRENCY MANAGEMENT
--------------------------------------------------------------------------------

-- Modify gems
function PlayerDataManager.ModifyGems(player, amount)
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then return false, 0 end
	
	local gems = playerData:FindFirstChild("Gems")
	if not gems then return false, 0 end
	
	local oldValue = gems.Value
	gems.Value = math.max(0, gems.Value + amount)
	
	-- Track total earned (only positive amounts)
	if amount > 0 then
		local stats = playerData:FindFirstChild("Stats")
		if stats then
			local totalEarned = stats:FindFirstChild("TotalGemsEarned")
			if totalEarned then
				totalEarned.Value = totalEarned.Value + amount
			end
		end
	end
	
	return true, gems.Value
end

-- Get current gem count
function PlayerDataManager.GetGems(player)
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then return 0 end
	
	local gems = playerData:FindFirstChild("Gems")
	return gems and gems.Value or 0
end

-- Generic currency modification (works for Gems, Coins, Tickets, etc.)
function PlayerDataManager.ModifyCurrency(player, currencyName, amount)
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then return false, 0 end
	
	local currency = playerData:FindFirstChild(currencyName)
	if not currency then return false, 0 end
	
	local oldValue = currency.Value
	currency.Value = math.max(0, currency.Value + amount)
	
	return true, currency.Value
end

-- Get any currency value
function PlayerDataManager.GetCurrency(player, currencyName)
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then return 0 end
	
	local currency = playerData:FindFirstChild(currencyName)
	return currency and currency.Value or 0
end

-- Check if player can afford a cost
function PlayerDataManager.CanAfford(player, currencyName, amount)
	return PlayerDataManager.GetCurrency(player, currencyName) >= amount
end

--------------------------------------------------------------------------------
-- DATA RETRIEVAL
--------------------------------------------------------------------------------

-- Get player's inventory as table (now returns UnitInstances data)
function PlayerDataManager.GetInventory(player)
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then 
		warn("[PlayerData] GetInventory: No PlayerData folder for", player.Name)
		return {} 
	end
	
	-- Use new UnitInstances folder
	local unitInstances = playerData:FindFirstChild("UnitInstances")
	if not unitInstances then 
		warn("[PlayerData] GetInventory: No UnitInstances folder for", player.Name)
		return {} 
	end
	
	local towers = {}
	
	for _, instance in ipairs(unitInstances:GetChildren()) do
		if instance:IsA("Folder") then
			local unitId = instance:GetAttribute("UnitId")
			local rarity = instance:GetAttribute("Rarity")
			
			-- Get traits
			local traits = {}
			local traitsFolder = instance:FindFirstChild("Traits")
			if traitsFolder then
				for _, trait in ipairs(traitsFolder:GetChildren()) do
					if trait:IsA("StringValue") then
						table.insert(traits, trait.Value)
					end
				end
			end
			
			table.insert(towers, {
				InstanceId = instance.Name,
				TowerId = unitId,
				Rarity = rarity or "Common",
				XP = instance:GetAttribute("XP") or 0,
				EvolutionStage = instance:GetAttribute("EvolutionStage") or 0,
				Locked = instance:GetAttribute("Locked") or false,
				Traits = traits,
			})
		end
	end
	
	return towers
end

-- Get player's loadout as indexed table (preserves slot positions)
-- Returns a table with all 6 slots, using false for empty slots to ensure proper serialization
function PlayerDataManager.GetLoadout(player)
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then 
		warn("[PlayerData] GetLoadout: No PlayerData folder for", player.Name)
		return {false, false, false, false, false, false} 
	end
	
	local loadout = playerData:FindFirstChild("Loadout")
	if not loadout then 
		warn("[PlayerData] GetLoadout: No Loadout folder for", player.Name)
		return {false, false, false, false, false, false} 
	end
	
	-- Initialize all 6 slots as false (empty) to ensure proper array serialization
	local slots = {false, false, false, false, false, false}
	local children = loadout:GetChildren()
	print("[PlayerData] GetLoadout: Found", #children, "items in Loadout folder for", player.Name)
	
	for _, slot in ipairs(children) do
		if slot:IsA("StringValue") then
			local slotNumber = tonumber(slot.Name:match("Slot_(%d+)"))
			if slotNumber and slotNumber >= 1 and slotNumber <= 6 then
				slots[slotNumber] = slot.Value
				print("[PlayerData] GetLoadout: Slot", slotNumber, "=", slot.Value)
			else
				-- Debug: Show what the slot name actually is
				print("[PlayerData] GetLoadout: Unrecognized slot name:", slot.Name, "Value:", slot.Value)
			end
		end
	end
	
	return slots
end

-- Get loadout as flat array (for backward compatibility)
function PlayerDataManager.GetLoadoutArray(player)
	local slots = PlayerDataManager.GetLoadout(player)
	local array = {}
	
	for i = 1, GameConfig.Loadout.MaxSlots do
		if slots[i] then
			table.insert(array, slots[i])
		end
	end
	
	return array
end

-- Get loadout with full unit data (for UI display)
function PlayerDataManager.GetLoadoutWithData(player)
	local slots = PlayerDataManager.GetLoadout(player)
	local result = {}
	
	for i = 1, GameConfig.Loadout.MaxSlots do
		if slots[i] then
			local unitData = PlayerDataManager.GetUnitInstance(player, slots[i])
			result[i] = unitData
		else
			result[i] = false
		end
	end
	
	return result
end

--------------------------------------------------------------------------------
-- MAP PROGRESS MANAGEMENT
--------------------------------------------------------------------------------

-- Get player's highest completed act for a map
function PlayerDataManager.GetMapProgress(player, mapId)
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then return 0 end
	
	local mapProgress = playerData:FindFirstChild("MapProgress")
	if not mapProgress then return 0 end
	
	local progressValue = mapProgress:FindFirstChild(mapId)
	if progressValue then
		local _, actStr = progressValue.Value:match("^(.+):(%d+)$")
		return actStr and tonumber(actStr) or 0
	end
	
	return 0
end

-- Set player's highest completed act for a map
function PlayerDataManager.SetMapProgress(player, mapId, actNumber)
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then return false end
	
	local mapProgress = playerData:FindFirstChild("MapProgress")
	if not mapProgress then return false end
	
	local currentProgress = PlayerDataManager.GetMapProgress(player, mapId)
	if actNumber <= currentProgress then return true end -- Don't downgrade progress
	
	local progressValue = mapProgress:FindFirstChild(mapId)
	if progressValue then
		progressValue.Value = mapId .. ":" .. actNumber
	else
		local newProgress = Instance.new("StringValue")
		newProgress.Name = mapId
		newProgress.Value = mapId .. ":" .. actNumber
		newProgress.Parent = mapProgress
	end
	
	print("[PlayerData] Set", player.Name, "progress for", mapId, "to Act", actNumber)
	return true
end

-- Get all map progress as table
function PlayerDataManager.GetAllMapProgress(player)
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then return {} end
	
	local mapProgress = playerData:FindFirstChild("MapProgress")
	if not mapProgress then return {} end
	
	local progress = {}
	for _, progressValue in ipairs(mapProgress:GetChildren()) do
		if progressValue:IsA("StringValue") then
			local mapId, actStr = progressValue.Value:match("^(.+):(%d+)$")
			if mapId and actStr then
				progress[mapId] = tonumber(actStr)
			end
		end
	end
	
	return progress
end

--------------------------------------------------------------------------------
-- UNIT INSTANCE MANAGEMENT (New System)
--------------------------------------------------------------------------------

-- Create a new unit instance (e.g., from gacha pull)
function PlayerDataManager.CreateUnitInstance(player, unitId, rarity, traits)
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then return nil end
	
	local unitInstances = playerData:FindFirstChild("UnitInstances")
	if not unitInstances then return nil end
	
	local instanceId = HttpService:GenerateGUID(false)
	traits = traits or TraitSystem.Generate(rarity or "Common")
	
	local instanceFolder = Instance.new("Folder")
	instanceFolder.Name = instanceId
	instanceFolder:SetAttribute("UnitId", unitId)
	instanceFolder:SetAttribute("XP", 0)
	instanceFolder:SetAttribute("EvolutionStage", 0)
	instanceFolder:SetAttribute("DateObtained", os.time())
	instanceFolder:SetAttribute("Locked", false)
	instanceFolder:SetAttribute("Rarity", rarity or "Common")
	instanceFolder.Parent = unitInstances
	
	local traitsFolder = Instance.new("Folder")
	traitsFolder.Name = "Traits"
	traitsFolder.Parent = instanceFolder
	
	for i, traitName in ipairs(traits) do
		local traitValue = Instance.new("StringValue")
		traitValue.Name = "Trait_" .. i
		traitValue.Value = traitName
		traitValue.Parent = traitsFolder
	end
	
	local relicsFolder = Instance.new("Folder")
	relicsFolder.Name = "EquippedRelics"
	relicsFolder.Parent = instanceFolder
	
	print("[PlayerData] Created unit instance:", instanceId, "UnitId:", unitId, "Rarity:", rarity)
	return instanceId
end

-- Get a unit instance by ID
function PlayerDataManager.GetUnitInstance(player, instanceId)
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then return nil end
	
	local unitInstances = playerData:FindFirstChild("UnitInstances")
	if not unitInstances then return nil end
	
	local instance = unitInstances:FindFirstChild(instanceId)
	if not instance then return nil end
	
	local data = {
		InstanceId = instanceId,
		UnitId = instance:GetAttribute("UnitId"),
		XP = instance:GetAttribute("XP") or 0,
		EvolutionStage = instance:GetAttribute("EvolutionStage") or 0,
		DateObtained = instance:GetAttribute("DateObtained") or 0,
		Locked = instance:GetAttribute("Locked") or false,
		Rarity = instance:GetAttribute("Rarity") or "Common",
		Traits = {},
		EquippedRelics = {},
	}
	
	local traitsFolder = instance:FindFirstChild("Traits")
	if traitsFolder then
		for _, trait in ipairs(traitsFolder:GetChildren()) do
			if trait:IsA("StringValue") then
				table.insert(data.Traits, trait.Value)
			end
		end
	end
	
	local relicsFolder = instance:FindFirstChild("EquippedRelics")
	if relicsFolder then
		for _, relic in ipairs(relicsFolder:GetChildren()) do
			if relic:IsA("StringValue") then
				data.EquippedRelics[relic.Name] = relic.Value
			end
		end
	end
	
	return data
end

-- Get all unit instances
function PlayerDataManager.GetAllUnitInstances(player)
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then return {} end
	
	local unitInstances = playerData:FindFirstChild("UnitInstances")
	if not unitInstances then return {} end
	
	local instances = {}
	for _, instance in ipairs(unitInstances:GetChildren()) do
		if instance:IsA("Folder") then
			instances[instance.Name] = PlayerDataManager.GetUnitInstance(player, instance.Name)
		end
	end
	
	return instances
end

-- Update unit traits (for reroll)
function PlayerDataManager.UpdateUnitTraits(player, instanceId, newTraits)
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then return false end
	
	local unitInstances = playerData:FindFirstChild("UnitInstances")
	if not unitInstances then return false end
	
	local instance = unitInstances:FindFirstChild(instanceId)
	if not instance then return false end
	
	local traitsFolder = instance:FindFirstChild("Traits")
	if not traitsFolder then return false end
	
	-- Clear existing traits
	for _, child in ipairs(traitsFolder:GetChildren()) do
		child:Destroy()
	end
	
	-- Add new traits
	for i, traitName in ipairs(newTraits) do
		local traitValue = Instance.new("StringValue")
		traitValue.Name = "Trait_" .. i
		traitValue.Value = traitName
		traitValue.Parent = traitsFolder
	end
	
	return true
end

-- Lock/unlock unit
function PlayerDataManager.SetUnitLocked(player, instanceId, locked)
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then return false end
	
	local unitInstances = playerData:FindFirstChild("UnitInstances")
	if not unitInstances then return false end
	
	local instance = unitInstances:FindFirstChild(instanceId)
	if not instance then return false end
	
	instance:SetAttribute("Locked", locked)
	return true
end

-- Delete unit instance
function PlayerDataManager.DeleteUnitInstance(player, instanceId)
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then return false end
	
	local unitInstances = playerData:FindFirstChild("UnitInstances")
	if not unitInstances then return false end
	
	local instance = unitInstances:FindFirstChild(instanceId)
	if not instance then return false end
	
	if instance:GetAttribute("Locked") then
		warn("[PlayerData] Cannot delete locked unit:", instanceId)
		return false
	end
	
	-- Remove from loadout if equipped
	local loadout = playerData:FindFirstChild("Loadout")
	if loadout then
		for _, slot in ipairs(loadout:GetChildren()) do
			if slot:IsA("StringValue") and slot.Value == instanceId then
				slot:Destroy()
			end
		end
	end
	
	instance:Destroy()
	return true
end

-- Get unit count
function PlayerDataManager.GetUnitCount(player)
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then return 0 end
	
	local unitInstances = playerData:FindFirstChild("UnitInstances")
	if not unitInstances then return 0 end
	
	return #unitInstances:GetChildren()
end

--------------------------------------------------------------------------------
-- RELIC MANAGEMENT
--------------------------------------------------------------------------------

-- Add relic to inventory
function PlayerDataManager.AddRelic(player, relicData)
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then return false end
	
	local relicInventory = playerData:FindFirstChild("RelicInventory")
	if not relicInventory then return false end
	
	local relicFolder = Instance.new("Folder")
	relicFolder.Name = relicData.ID
	relicFolder:SetAttribute("Slot", relicData.Slot)
	relicFolder:SetAttribute("Rarity", relicData.Rarity)
	relicFolder:SetAttribute("Set", relicData.Set)
	relicFolder:SetAttribute("MainStat", relicData.MainStat)
	relicFolder:SetAttribute("MainValue", relicData.MainValue)
	relicFolder:SetAttribute("Level", relicData.Level or 0)
	relicFolder:SetAttribute("MaxLevel", relicData.MaxLevel or 8)
	relicFolder.Parent = relicInventory
	
	local substatsFolder = Instance.new("Folder")
	substatsFolder.Name = "Substats"
	substatsFolder.Parent = relicFolder
	
	for statName, statValue in pairs(relicData.Substats or {}) do
		local statValueObj = Instance.new("NumberValue")
		statValueObj.Name = statName
		statValueObj.Value = statValue
		statValueObj.Parent = substatsFolder
	end
	
	return true
end

-- Equip relic to unit
function PlayerDataManager.EquipRelic(player, instanceId, relicId, slot)
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then return false end
	
	local unitInstances = playerData:FindFirstChild("UnitInstances")
	if not unitInstances then return false end
	
	local instance = unitInstances:FindFirstChild(instanceId)
	if not instance then return false end
	
	local relicsFolder = instance:FindFirstChild("EquippedRelics")
	if not relicsFolder then return false end
	
	local existing = relicsFolder:FindFirstChild(slot)
	if existing then existing:Destroy() end
	
	local relicValue = Instance.new("StringValue")
	relicValue.Name = slot
	relicValue.Value = relicId
	relicValue.Parent = relicsFolder
	
	return true
end

-- Unequip relic
function PlayerDataManager.UnequipRelic(player, instanceId, slot)
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then return false end
	
	local unitInstances = playerData:FindFirstChild("UnitInstances")
	if not unitInstances then return false end
	
	local instance = unitInstances:FindFirstChild(instanceId)
	if not instance then return false end
	
	local relicsFolder = instance:FindFirstChild("EquippedRelics")
	if not relicsFolder then return false end
	
	local relic = relicsFolder:FindFirstChild(slot)
	if relic then
		relic:Destroy()
		return true
	end
	
	return false
end

-- Get all relics in inventory
function PlayerDataManager.GetRelicInventory(player)
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then return {} end
	
	local relicInventory = playerData:FindFirstChild("RelicInventory")
	if not relicInventory then return {} end
	
	local relics = {}
	for _, relicFolder in ipairs(relicInventory:GetChildren()) do
		if relicFolder:IsA("Folder") then
			local relicData = {
				ID = relicFolder.Name,
				Slot = relicFolder:GetAttribute("Slot"),
				Rarity = relicFolder:GetAttribute("Rarity"),
				Set = relicFolder:GetAttribute("Set"),
				MainStat = relicFolder:GetAttribute("MainStat"),
				MainValue = relicFolder:GetAttribute("MainValue"),
				Level = relicFolder:GetAttribute("Level") or 0,
				MaxLevel = relicFolder:GetAttribute("MaxLevel") or 8,
				Substats = {},
			}
			
			local substats = relicFolder:FindFirstChild("Substats")
			if substats then
				for _, substat in ipairs(substats:GetChildren()) do
					if substat:IsA("NumberValue") then
						relicData.Substats[substat.Name] = substat.Value
					end
				end
			end
			
			table.insert(relics, relicData)
		end
	end
	
	return relics
end

-- Get a specific relic by ID
function PlayerDataManager.GetRelic(player, relicId)
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then return nil end
	
	local relicInventory = playerData:FindFirstChild("RelicInventory")
	if not relicInventory then return nil end
	
	local relicFolder = relicInventory:FindFirstChild(relicId)
	if not relicFolder then return nil end
	
	local relicData = {
		ID = relicFolder.Name,
		Slot = relicFolder:GetAttribute("Slot"),
		Rarity = relicFolder:GetAttribute("Rarity"),
		Set = relicFolder:GetAttribute("Set"),
		MainStat = relicFolder:GetAttribute("MainStat"),
		MainValue = relicFolder:GetAttribute("MainValue"),
		Level = relicFolder:GetAttribute("Level") or 0,
		MaxLevel = relicFolder:GetAttribute("MaxLevel") or 8,
		Substats = {},
	}
	
	local substats = relicFolder:FindFirstChild("Substats")
	if substats then
		for _, substat in ipairs(substats:GetChildren()) do
			if substat:IsA("NumberValue") then
				relicData.Substats[substat.Name] = substat.Value
			end
		end
	end
	
	return relicData
end

--------------------------------------------------------------------------------
-- EVOLUTION MANAGEMENT
--------------------------------------------------------------------------------

-- Update unit evolution stage
function PlayerDataManager.SetEvolutionStage(player, instanceId, stage)
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then return false end
	
	local unitInstances = playerData:FindFirstChild("UnitInstances")
	if not unitInstances then return false end
	
	local instance = unitInstances:FindFirstChild(instanceId)
	if not instance then return false end
	
	instance:SetAttribute("EvolutionStage", stage)
	print("[PlayerData] Set evolution stage for", instanceId, "to", stage)
	return true
end

-- Add XP to unit
function PlayerDataManager.AddUnitXP(player, instanceId, xpAmount)
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then return false, 0 end
	
	local unitInstances = playerData:FindFirstChild("UnitInstances")
	if not unitInstances then return false, 0 end
	
	local instance = unitInstances:FindFirstChild(instanceId)
	if not instance then return false, 0 end
	
	local currentXP = instance:GetAttribute("XP") or 0
	local newXP = currentXP + xpAmount
	instance:SetAttribute("XP", newXP)
	
	print("[PlayerData] Added", xpAmount, "XP to", instanceId, "- now has", newXP)
	return true, newXP
end

--------------------------------------------------------------------------------
-- SELL UNITS
--------------------------------------------------------------------------------

-- Sell multiple units at once, returns total coins earned
function PlayerDataManager.SellUnits(player, instanceIds)
	if not instanceIds or #instanceIds == 0 then
		return false, 0, "No units to sell"
	end
	
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then return false, 0, "No player data" end
	
	local unitInstances = playerData:FindFirstChild("UnitInstances")
	if not unitInstances then return false, 0, "No unit instances" end
	
	local loadout = playerData:FindFirstChild("Loadout")
	local loadoutInstanceIds = {}
	if loadout then
		for _, slot in ipairs(loadout:GetChildren()) do
			if slot:IsA("StringValue") and slot.Value ~= "" then
				loadoutInstanceIds[slot.Value] = true
			end
		end
	end
	
	local totalCoins = 0
	local soldCount = 0
	local skippedLocked = 0
	local skippedLoadout = 0
	
	for _, instanceId in ipairs(instanceIds) do
		local instance = unitInstances:FindFirstChild(instanceId)
		if instance then
			-- Check if locked
			if instance:GetAttribute("Locked") then
				skippedLocked = skippedLocked + 1
				continue
			end
			
			-- Check if in loadout
			if loadoutInstanceIds[instanceId] then
				skippedLoadout = skippedLoadout + 1
				continue
			end
			
			-- Get rarity and calculate coins
			local rarity = instance:GetAttribute("Rarity") or "Common"
			local coinValue = GameConfig.Selling.CoinRates[rarity] or 5
			
			-- Delete the unit
			instance:Destroy()
			
			totalCoins = totalCoins + coinValue
			soldCount = soldCount + 1
		end
	end
	
	-- Add coins to player
	if totalCoins > 0 then
		local coinsValue = playerData:FindFirstChild("Coins")
		if coinsValue then
			coinsValue.Value = coinsValue.Value + totalCoins
		end
	end
	
	print("[PlayerData] Sold", soldCount, "units for", totalCoins, "coins. Skipped:", skippedLocked, "locked,", skippedLoadout, "in loadout")
	return true, totalCoins, soldCount, skippedLocked, skippedLoadout
end

return PlayerDataManager
