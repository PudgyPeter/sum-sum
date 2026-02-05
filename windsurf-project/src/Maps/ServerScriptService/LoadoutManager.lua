--[[
	LoadoutManager.lua (RockMap/Game Place)
	Loads player loadout from DataStore when they join the game.
	Loadout is saved by TeleportManager in the lobby.
	
	DataStore names are read from ConfigStore (published by lobby) so all maps
	automatically use the correct version without manual updates.
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Read DataStore config from ConfigStore (published by lobby)
-- This is the SINGLE SOURCE OF TRUTH - lobby controls the version
local CONFIG_STORE_NAME = "GameConfigStore" -- This name NEVER changes
local ConfigStore = DataStoreService:GetDataStore(CONFIG_STORE_NAME)

-- Fallback values if ConfigStore read fails
local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))

local LoadoutStoreName = GameConfig.DataStore.LoadoutStoreName
local PlayerDataStoreName = GameConfig.DataStore.PlayerDataStoreName

-- Try to read config from ConfigStore (set by lobby)
local configSuccess, config = pcall(function()
	return ConfigStore:GetAsync("DataStoreConfig")
end)

if configSuccess and config then
	LoadoutStoreName = config.LoadoutStoreName
	PlayerDataStoreName = config.PlayerDataStoreName
	print("[LoadoutManager] Using DataStore config from lobby: v" .. (config.Version or "?"))
else
	warn("[LoadoutManager] Could not read ConfigStore, using local fallback: " .. LoadoutStoreName)
end

local LoadoutStore = DataStoreService:GetDataStore(LoadoutStoreName)
local PlayerDataStore = DataStoreService:GetDataStore(PlayerDataStoreName)

print("[LoadoutManager] Script loaded")

-- Setup player loadout when they join the game
local function SetupPlayerLoadout(player)
	-- Try to load loadout from DataStore
	-- Format is now indexed: { [1] = "TowerA", [3] = "TowerB" }
	local success, loadout = pcall(function()
		return LoadoutStore:GetAsync("Player_" .. player.UserId)
	end)
	
	if success and loadout then
		-- Debug: Show raw data from DataStore
		local HttpService = game:GetService("HttpService")
		print("[LoadoutManager] RAW DataStore response:", HttpService:JSONEncode(loadout))
		
		-- Build readable log with key types
		local loadoutLog = {}
		for key, towerId in pairs(loadout) do
			if towerId and towerId ~= false then
				table.insert(loadoutLog, "(" .. type(key) .. ")" .. tostring(key) .. "=" .. towerId)
			end
		end
		print("[LoadoutManager] Loaded loadout for", player.Name, ":", table.concat(loadoutLog, ", "))
		
		-- Create PlayerData folder
		local playerDataFolder = Instance.new("Folder")
		playerDataFolder.Name = "PlayerData"
		playerDataFolder.Parent = player
		
		-- Create Loadout folder
		local loadoutFolder = Instance.new("Folder")
		loadoutFolder.Name = "Loadout"
		loadoutFolder.Parent = playerDataFolder
		
		-- Add towers to loadout (preserve slot positions)
		-- Supports both string keys "Slot_N" and legacy numeric keys
		for key, towerId in pairs(loadout) do
			if towerId and towerId ~= false then
				local slotNumber
				if type(key) == "string" then
					-- New format: "Slot_3" -> 3
					slotNumber = tonumber(key:match("Slot_(%d+)"))
				else
					-- Legacy format: numeric key
					slotNumber = key
				end
				
				if slotNumber and slotNumber >= 1 and slotNumber <= 6 then
					local towerValue = Instance.new("StringValue")
					towerValue.Name = "Slot_" .. slotNumber
					towerValue.Value = towerId
					towerValue.Parent = loadoutFolder
					print("[LoadoutManager] Created Slot_" .. slotNumber .. " = " .. towerId)
				end
			end
		end
		
		-- Load Gems from lobby's persistent DataStore
		local gemsValue = 0
		local gemsSuccess, playerData = pcall(function()
			return PlayerDataStore:GetAsync(player.UserId)
		end)
		
		if gemsSuccess and playerData and playerData.Gems then
			gemsValue = playerData.Gems
			print("[LoadoutManager] Loaded", gemsValue, "gems for", player.Name)
		else
			print("[LoadoutManager] Could not load gems for", player.Name, "- starting with 0")
		end
		
		local gems = Instance.new("IntValue")
		gems.Name = "Gems"
		gems.Value = gemsValue
		gems.Parent = playerDataFolder
		
		return true
	else
		print("[LoadoutManager] No loadout found for", player.Name, "- allowing all towers")
		return false
	end
end

-- Get loadout as indexed table (matches lobby format)
local function GetLoadout(player)
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then return {} end
	
	local loadout = playerData:FindFirstChild("Loadout")
	if not loadout then return {} end
	
	local slots = {}
	for _, slot in ipairs(loadout:GetChildren()) do
		if slot:IsA("StringValue") then
			local slotNumber = tonumber(slot.Name:match("Slot_(%d+)"))
			if slotNumber then
				slots[slotNumber] = slot.Value
			end
		end
	end
	
	return slots
end

-- Get loadout as flat array (for backward compatibility with tower placement)
local function GetLoadoutArray(player)
	local slots = GetLoadout(player)
	local array = {}
	
	for i = 1, MAX_LOADOUT_SLOTS do
		if slots[i] then
			table.insert(array, slots[i])
		end
	end
	
	return array
end

-- Setup all players on server start
Players.PlayerAdded:Connect(function(player)
	SetupPlayerLoadout(player)
end)

-- Export functions for other scripts
return {
	GetLoadout = GetLoadout,
	GetLoadoutArray = GetLoadoutArray,
}
