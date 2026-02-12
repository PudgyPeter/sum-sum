--[[
	DataStoreManager.lua
	Handles data store operations for player data persistence.
	
	DataStore name is read from ConfigStore (published by lobby) so all maps
	automatically use the correct version without manual updates.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataStoreManager = {}

-- Read DataStore config from ConfigStore (published by lobby)
local CONFIG_STORE_NAME = "GameConfigStore" -- This name NEVER changes
local ConfigStore = DataStoreService:GetDataStore(CONFIG_STORE_NAME)

-- Fallback to local GameConfig
local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))

local PlayerDataStoreName = GameConfig.DataStore.PlayerDataStoreName

-- Try to read config from ConfigStore (set by lobby)
local configSuccess, config = pcall(function()
	return ConfigStore:GetAsync("DataStoreConfig")
end)

if configSuccess and config then
	PlayerDataStoreName = config.PlayerDataStoreName
	print("[DataStoreManager] Using DataStore config from lobby: " .. PlayerDataStoreName)
else
	warn("[DataStoreManager] Could not read ConfigStore, using local fallback: " .. PlayerDataStoreName)
end

local playerDataStore = DataStoreService:GetDataStore(PlayerDataStoreName)

-- Cache for player data
local dataCache = {}
local savedPlayers = {}

-- Queue for saving data to prevent throttling
local saveQueue = {}
local isProcessingQueue = false

-- Process save queue with throttling protection
local function processSaveQueue()
	if #saveQueue == 0 then
		isProcessingQueue = false
		return
	end
	
	isProcessingQueue = true
	
	local saveItem = table.remove(saveQueue, 1)
	local userId = saveItem.userId
	local data = saveItem.data
	
	local success, errorMessage = pcall(function()
		playerDataStore:SetAsync(userId, data)
	end)
	
	if not success then
		warn("[DataStore] Failed to save data for user", userId, ":", errorMessage)
		-- Re-add to queue to retry later
		table.insert(saveQueue, saveItem)
	end
	
	-- Wait a bit to prevent throttling
	task.wait(1)
	
	-- Process next item
	processSaveQueue()
end

--------------------------------------------------------------------------------
-- DATA RETRIEVAL
--------------------------------------------------------------------------------

-- Load player data from DataStore
function DataStoreManager.LoadData(player)
	local userId = player.UserId -- Use number, not string (must match lobby)
	
	-- Check cache first
	if dataCache[userId] then
		return dataCache[userId]
	end
	
	local success, data = pcall(function()
		return playerDataStore:GetAsync(userId)
	end)
	
	if success and data then
		print("[DataStore] Loaded data for", player.Name)
		dataCache[userId] = data
		return data
	else
		print("[DataStore] No data found for", player.Name, "- creating new")
		return nil
	end
end

--------------------------------------------------------------------------------
-- DATA SAVING
--------------------------------------------------------------------------------

-- Save player data to DataStore
function DataStoreManager.SaveData(player, data)
	local userId = player.UserId -- Use number, not string (must match lobby)
	
	-- Update cache
	dataCache[userId] = data
	
	-- Add to save queue
	table.insert(saveQueue, {
		userId = userId,
		data = data,
		timestamp = tick()
	})
	
	-- Process queue if not already processing
	if not isProcessingQueue then
		processSaveQueue()
	end
	
	return true
end

--------------------------------------------------------------------------------
-- AUTO-SAVE
--------------------------------------------------------------------------------

-- Auto-save when player leaves
Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId
	
	if dataCache[userId] and not savedPlayers[userId] then
		savedPlayers[userId] = true
		local success, errorMessage = pcall(function()
			playerDataStore:SetAsync(userId, dataCache[userId])
		end)
		
		if not success then
			warn("[DataStore] Failed to save data for", player.Name, ":", errorMessage)
		end
		
		-- Remove from cache
		dataCache[userId] = nil
	end
end)

-- Auto-save all players when server shuts down
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		local userId = player.UserId
		if dataCache[userId] and not savedPlayers[userId] then
			savedPlayers[userId] = true
			local success, errorMessage = pcall(function()
				playerDataStore:SetAsync(userId, dataCache[userId])
			end)
			
			if not success then
				warn("[DataStore] Failed to save data for", player.Name, ":", errorMessage)
			end
		end
	end
end)

-- Periodic auto-save every 5 minutes
spawn(function()
	while true do
		wait(300) -- 5 minutes
		
		for userId, data in pairs(dataCache) do
			local success, errorMessage = pcall(function()
				playerDataStore:SetAsync(userId, data)
			end)
			
			if not success then
				warn("[DataStore] Auto-save failed for user", userId, ":", errorMessage)
			end
		end
	end
end)

return DataStoreManager
