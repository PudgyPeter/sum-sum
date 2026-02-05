--[[
	MapData.lua
	Central configuration for all game maps.
	Place in ReplicatedStorage.Shared so both client and server can access.
	
	Usage: local MapData = require(ReplicatedStorage.Shared.MapData)
	
	VERSION: 2.0 - Updated with Acts structure
]]

local MapData = {}

-- Helper to create act configuration
local function createAct(actNumber, wavesInAct)
	return {
		ActNumber = actNumber,
		Waves = wavesInAct,
		Name = "Act " .. actNumber,
		Description = "Waves 1-" .. wavesInAct,
	}
end

-- All available maps
MapData.Maps = {
	{
		ID = "RockMap",
		Name = "Rock Valley",
		PlaceId = 78167402552703, -- Your actual Place ID
		Description = "A rocky terrain with winding paths. Perfect for beginners.",
		Difficulty = "Easy",
		Acts = {
			createAct(1, 15),   -- Act 1: 15 waves
			createAct(2, 15),   -- Act 2: 15 waves
			createAct(3, 15),   -- Act 3: 15 waves
			createAct(4, 15),   -- Act 4: 15 waves
			createAct(5, 15),   -- Act 5: 15 waves
		},
		ImageId = "rbxassetid://0", -- Replace with actual thumbnail
		Rewards = { Coins = 100, Gems = 10 },
	},
	{
		ID = "DesertMap",
		Name = "Desert Ruins",
		PlaceId = 0, -- Replace with actual Place ID when created
		Description = "Ancient ruins in a scorching desert. Watch out for ambushes!",
		Difficulty = "Medium",
		Acts = {
			createAct(1, 15),   -- Act 1: 15 waves
			createAct(2, 15),   -- Act 2: 15 waves
			createAct(3, 15),   -- Act 3: 15 waves
			createAct(4, 15),   -- Act 4: 15 waves
			createAct(5, 15),   -- Act 5: 15 waves
		},
		ImageId = "rbxassetid://0", -- Replace with actual thumbnail
		Rewards = { Coins = 200, Gems = 25 },
	},
	-- Add more maps here as you create them...
}

-- Helper: Get map by ID
function MapData.GetMapById(mapId)
	print("MapData.GetMapById called with:", mapId)
	for _, map in ipairs(MapData.Maps) do
		if map.ID == mapId then
			print("MapData: Found map:", map.Name)
			return map
		end
	end
	print("MapData: Map not found:", mapId)
	return nil
end

-- Helper: Get all maps
function MapData.GetAllMaps()
	return MapData.Maps
end

-- Helper: Get act info for a specific act number
function MapData.GetAct(mapId, actNumber)
	local map = MapData.GetMapById(mapId)
	if not map or not map.Acts then return nil end
	
	for _, act in ipairs(map.Acts) do
		if act.ActNumber == actNumber then
			return act
		end
	end
	return nil
end

-- Helper: Get total number of acts for a map
function MapData.GetTotalActs(mapId)
	local map = MapData.GetMapById(mapId)
	return map and #map.Acts or 5
end

-- Helper: Get map index in the list (1-based)
function MapData.GetMapIndex(mapId)
	for i, map in ipairs(MapData.Maps) do
		if map.ID == mapId then
			return i
		end
	end
	return nil
end

-- Helper: Get next map in sequence (returns nil if this is the last map)
function MapData.GetNextMap(mapId)
	local currentIndex = MapData.GetMapIndex(mapId)
	if currentIndex and currentIndex < #MapData.Maps then
		return MapData.Maps[currentIndex + 1]
	end
	return nil
end

-- Helper: Get previous map in sequence (returns nil if this is the first map)
function MapData.GetPreviousMap(mapId)
	local currentIndex = MapData.GetMapIndex(mapId)
	if currentIndex and currentIndex > 1 then
		return MapData.Maps[currentIndex - 1]
	end
	return nil
end

-- Helper: Check if a map is the first map (always unlocked)
function MapData.IsFirstMap(mapId)
	return MapData.GetMapIndex(mapId) == 1
end

print("MapData: Module loaded with", #MapData.Maps, "maps")
print("MapData: Available functions:", "GetMapById", "GetAct", "GetAllMaps", "GetTotalActs", "GetNextMap")

return MapData
