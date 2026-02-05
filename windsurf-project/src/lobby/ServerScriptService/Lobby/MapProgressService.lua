--[[
	MapProgressService.lua
	Handles map progress queries and act availability for the lobby.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local MapData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MapData"))

local MapProgressService = {}

-- Helper function to get keys of a table
local function GetKeys(t)
	local keys = {}
	for k, v in pairs(t) do
		table.insert(keys, tostring(k))
	end
	return keys
end

-- Create GetMapProgress RemoteFunction
local functions = ReplicatedStorage:WaitForChild("Functions")
local GetMapProgressFunction = functions:FindFirstChild("GetMapProgress")
if not GetMapProgressFunction then
	GetMapProgressFunction = Instance.new("RemoteFunction")
	GetMapProgressFunction.Name = "GetMapProgress"
	GetMapProgressFunction.Parent = functions
	print("Created GetMapProgress RemoteFunction")
end

-- Create GetAvailableActs RemoteFunction
local GetAvailableActsFunction = functions:FindFirstChild("GetAvailableActs")
if not GetAvailableActsFunction then
	GetAvailableActsFunction = Instance.new("RemoteFunction")
	GetAvailableActsFunction.Name = "GetAvailableActs"
	GetAvailableActsFunction.Parent = functions
	print("Created GetAvailableActs RemoteFunction")
end

-- Create GetAvailableMaps RemoteFunction
local GetAvailableMapsFunction = functions:FindFirstChild("GetAvailableMaps")
if not GetAvailableMapsFunction then
	GetAvailableMapsFunction = Instance.new("RemoteFunction")
	GetAvailableMapsFunction.Name = "GetAvailableMaps"
	GetAvailableMapsFunction.Parent = functions
	print("Created GetAvailableMaps RemoteFunction")
end

-- Create GetAllActs RemoteFunction (returns all acts including locked)
local GetAllActsFunction = functions:FindFirstChild("GetAllActs")
if not GetAllActsFunction then
	GetAllActsFunction = Instance.new("RemoteFunction")
	GetAllActsFunction.Name = "GetAllActs"
	GetAllActsFunction.Parent = functions
	print("Created GetAllActs RemoteFunction")
end

-- Get player's progress for a specific map
function MapProgressService.GetMapProgress(player, mapId)
	return PlayerDataManager.GetMapProgress(player, mapId)
end

-- Check if player has completed all acts of a map
function MapProgressService.HasCompletedAllActs(player, mapId)
	local progress = PlayerDataManager.GetMapProgress(player, mapId)
	local totalActs = MapData.GetTotalActs(mapId)
	return progress >= totalActs
end

-- Check if a map is unlocked for a player
-- A map is unlocked if: it's the first map, OR the previous map has all 5 acts completed
function MapProgressService.IsMapUnlocked(player, mapId)
	-- First map is always unlocked
	if MapData.IsFirstMap(mapId) then
		return true
	end
	
	-- Check if previous map is fully completed
	local previousMap = MapData.GetPreviousMap(mapId)
	if previousMap then
		return MapProgressService.HasCompletedAllActs(player, previousMap.ID)
	end
	
	return false
end

-- Get all maps with unlock status for a player
function MapProgressService.GetAvailableMaps(player)
	local allMaps = MapData.GetAllMaps()
	local result = {}
	
	for i, map in ipairs(allMaps) do
		local isUnlocked = MapProgressService.IsMapUnlocked(player, map.ID)
		local highestAct = PlayerDataManager.GetMapProgress(player, map.ID)
		local totalActs = #map.Acts
		
		table.insert(result, {
			ID = map.ID,
			Name = map.Name,
			Description = map.Description,
			Difficulty = map.Difficulty,
			ImageId = map.ImageId,
			PlaceId = map.PlaceId,
			IsUnlocked = isUnlocked,
			HighestCompletedAct = highestAct,
			TotalActs = totalActs,
			IsFullyCompleted = highestAct >= totalActs,
			MapIndex = i
		})
	end
	
	return result
end

-- Get all available acts for a map based on player progress
function MapProgressService.GetAvailableActs(player, mapId)
	local highestCompletedAct = PlayerDataManager.GetMapProgress(player, mapId)
	local map = MapData.GetMapById(mapId)
	
	if not map then
		warn("[MapProgress] Map not found:", mapId)
		return {}
	end
	
	-- Debug: Print map structure
	print("[MapProgress] Map structure for", mapId, "- Keys:", table.concat(GetKeys(map), ", "))
	print("[MapProgress] Has Acts:", map.Acts ~= nil)
	if map.Acts then
		print("[MapProgress] Acts count:", #map.Acts)
	end
	
	if not map.Acts then
		warn("[MapProgress] Map has no Acts:", mapId)
		return {}
	end
	
	local availableActs = {}
	
	-- Player can access:
	-- 1. The next act after their highest completed
	-- 2. All acts they've already completed (for replay)
	for i = 1, #map.Acts do
		if i <= highestCompletedAct + 1 then
			table.insert(availableActs, {
				ActNumber = i,
				IsUnlocked = true,
				IsCompleted = i <= highestCompletedAct,
				ActInfo = map.Acts[i],
				MapImageId = map.ImageId -- Use map's thumbnail for all acts
			})
		end
	end
	
	return availableActs
end

-- Get ALL acts for a map (both locked and unlocked) for display purposes
function MapProgressService.GetAllActs(player, mapId)
	local highestCompletedAct = PlayerDataManager.GetMapProgress(player, mapId)
	local map = MapData.GetMapById(mapId)
	
	if not map then
		warn("[MapProgress] Map not found:", mapId)
		return {}
	end
	
	if not map.Acts then
		warn("[MapProgress] Map has no Acts:", mapId)
		return {}
	end
	
	local allActs = {}
	
	-- Return ALL acts with their unlock/completion status
	for i = 1, #map.Acts do
		local isUnlocked = i <= highestCompletedAct + 1
		table.insert(allActs, {
			ActNumber = i,
			IsUnlocked = isUnlocked,
			IsCompleted = i <= highestCompletedAct,
			ActInfo = map.Acts[i],
			MapImageId = map.ImageId -- Use map's thumbnail for all acts
		})
	end
	
	return allActs
end

-- Server handlers
GetMapProgressFunction.OnServerInvoke = function(player, mapId)
	return MapProgressService.GetMapProgress(player, mapId)
end

GetAvailableActsFunction.OnServerInvoke = function(player, mapId)
	return MapProgressService.GetAvailableActs(player, mapId)
end

GetAvailableMapsFunction.OnServerInvoke = function(player)
	return MapProgressService.GetAvailableMaps(player)
end

GetAllActsFunction.OnServerInvoke = function(player, mapId)
	return MapProgressService.GetAllActs(player, mapId)
end

return MapProgressService
