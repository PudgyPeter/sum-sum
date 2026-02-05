--[[
	TeleportManager.lua
	Handles teleporting players between lobby and game maps.
	Saves loadout to DataStore so game place can access it.
]]

local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local MapData = require(Shared:WaitForChild("MapData"))
local PlayerDataManager = require(script.Parent.PlayerDataManager)

local TeleportManager = {}

-- DataStore for loadouts (shared across places in same game)
local LoadoutStore = DataStoreService:GetDataStore(GameConfig.DataStore.LoadoutStoreName)

-- Teleport single player to game map with loadout data
function TeleportManager.TeleportToGame(player, mapId, selectedAct)
	selectedAct = selectedAct or 1 -- Default to Act 1 if not specified
	
	-- Validate map exists
	local map = MapData.GetMapById(mapId)
	if not map then
		warn("[Teleport] Invalid map ID:", mapId)
		return false
	end
	
	if map.PlaceId == 0 then
		warn("[Teleport] Map PlaceId not set for:", mapId)
		return false
	end
	
	-- Get player's loadout (indexed by slot - returns dense array with false for empty)
	local loadoutArray = PlayerDataManager.GetLoadout(player)
	
	-- Convert to string-keyed table for DataStore compatibility (avoids sparse table issues)
	local loadout = {}
	local loadoutCount = 0
	print("[Teleport] Converting loadoutArray to string keys:")
	for i = 1, 6 do
		print("[Teleport]   loadoutArray[" .. i .. "] =", loadoutArray[i])
		if loadoutArray[i] and loadoutArray[i] ~= false then
			loadout["Slot_" .. i] = loadoutArray[i]
			loadoutCount = loadoutCount + 1
			print("[Teleport]   -> Added Slot_" .. i .. " =", loadoutArray[i])
		end
	end
	print("[Teleport] Loadout has", loadoutCount, "towers for", player.Name)
	print("[Teleport] Final loadout table:", game:GetService("HttpService"):JSONEncode(loadout))
	
	if loadoutCount == 0 then
		warn("[Teleport] WARNING: Loadout is empty for", player.Name, "- check if towers were added")
	end
	
	-- Save loadout to DataStore so it can be accessed in the game place
	-- Format: { "Slot_1" = "TowerA", "Slot_3" = "TowerB" } - preserves slot positions with string keys
	local saveSuccess, saveErr = pcall(function()
		LoadoutStore:SetAsync("Player_" .. player.UserId, loadout)
	end)
	
	if not saveSuccess then
		warn("[Teleport] Failed to save loadout for", player.Name, ":", saveErr)
	else
		-- Build readable log of loadout
		local loadoutLog = {}
		for slot, towerId in pairs(loadout) do
			if towerId and towerId ~= false then
				table.insert(loadoutLog, slot .. "=" .. towerId)
			end
		end
		print("[Teleport] Saved loadout for", player.Name, ":", table.concat(loadoutLog, ", "))
	end
	
	-- Create TeleportOptions with loadout data (for published games)
	local teleportOptions = Instance.new("TeleportOptions")
	teleportOptions:SetTeleportData({
		Loadout = loadout, -- Indexed table preserving slot positions
		MapId = mapId, -- Pass map ID to game place
		SelectedAct = selectedAct -- Pass selected act to game place
	})
	
	local success, err = pcall(function()
		TeleportService:TeleportAsync(map.PlaceId, {player}, teleportOptions)
	end)
	
	if success then
		print("[Teleport] Teleporting", player.Name, "to", map.Name, "Act", selectedAct)
		return true
	else
		warn("[Teleport] Failed to teleport", player.Name, ":", err)
		return false
	end
end

-- Teleport party of players to game map (legacy - use TeleportPartyToGame instead)
function TeleportManager.TeleportParty(players, mapId)
	return TeleportManager.TeleportPartyToGame(players, mapId, 1)
end

-- Teleport party of players to game map with full loadout support
function TeleportManager.TeleportPartyToGame(players, mapId, selectedAct)
	selectedAct = selectedAct or 1
	
	-- Validate map exists
	local map = MapData.GetMapById(mapId)
	if not map then
		warn("[Teleport] Invalid map ID:", mapId)
		return false, "Invalid map"
	end
	
	if map.PlaceId == 0 then
		warn("[Teleport] Map PlaceId not set for:", mapId)
		return false, "Map not available yet"
	end
	
	-- Save loadouts for ALL players in the party
	local partyLoadouts = {}
	for _, player in ipairs(players) do
		local loadoutArray = PlayerDataManager.GetLoadout(player)
		
		-- Convert to string-keyed table for DataStore compatibility
		local loadout = {}
		for i = 1, 6 do
			if loadoutArray[i] and loadoutArray[i] ~= false then
				loadout["Slot_" .. i] = loadoutArray[i]
			end
		end
		
		partyLoadouts[player.UserId] = loadout
		
		-- Save to DataStore for each player
		local saveSuccess, saveErr = pcall(function()
			LoadoutStore:SetAsync("Player_" .. player.UserId, loadout)
		end)
		
		if not saveSuccess then
			warn("[Teleport] Failed to save loadout for", player.Name, ":", saveErr)
		else
			local loadoutLog = {}
			for slot, towerId in pairs(loadout) do
				if towerId and towerId ~= false then
					table.insert(loadoutLog, slot .. "=" .. towerId)
				end
			end
			print("[Teleport] Saved loadout for", player.Name, ":", table.concat(loadoutLog, ", "))
		end
	end
	
	-- Build player list for teleport data
	local playerNames = {}
	for _, player in ipairs(players) do
		table.insert(playerNames, player.Name)
	end
	
	-- Create TeleportOptions with shared party data
	local teleportOptions = Instance.new("TeleportOptions")
	teleportOptions:SetTeleportData({
		IsParty = true,
		PartySize = #players,
		PartyMembers = playerNames,
		MapId = mapId,
		SelectedAct = selectedAct,
		PartyLoadouts = partyLoadouts
	})
	
	local success, err = pcall(function()
		TeleportService:TeleportAsync(map.PlaceId, players, teleportOptions)
	end)
	
	if success then
		print("[Teleport] Teleporting party of", #players, "players to", map.Name, "Act", selectedAct)
		print("[Teleport] Party members:", table.concat(playerNames, ", "))
		return true
	else
		warn("[Teleport] Failed to teleport party:", err)
		return false, "Teleport failed: " .. tostring(err)
	end
end

-- Get pre-created TeleportToGame function
local functions = ReplicatedStorage:WaitForChild("Functions")
local TeleportToGameFunction = functions:WaitForChild("TeleportToGame")

TeleportToGameFunction.OnServerInvoke = function(player, mapId, selectedAct)
	return TeleportManager.TeleportToGame(player, mapId, selectedAct)
end

return TeleportManager
