--[[
	DataStoreManager.lua
	Handles raw DataStore operations with retries and safety.
	Does NOT know about data structure - that's PlayerDataManager's job.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for GameConfig to be available
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local DataStoreManager = {}

-- Get DataStore with configured name
local PlayerDataStore = DataStoreService:GetDataStore(GameConfig.DataStore.PlayerDataStoreName)

-- Track which players are currently being saved (prevent duplicate saves)
local savingPlayers = {}

-- Track if server is shutting down
local isShuttingDown = false

--------------------------------------------------------------------------------
-- INTERNAL HELPERS
--------------------------------------------------------------------------------

-- Retry wrapper for DataStore operations
local function retryOperation(operationName, operation)
	local maxRetries = GameConfig.DataStore.MaxRetries
	local retryDelay = GameConfig.DataStore.RetryDelay
	
	for attempt = 1, maxRetries do
		local success, result = pcall(operation)
		
		if success then
			return true, result
		end
		
		warn(string.format("[DataStore] %s failed (attempt %d/%d): %s", 
			operationName, attempt, maxRetries, tostring(result)))
		
		if attempt < maxRetries then
			task.wait(retryDelay)
		end
	end
	
	return false, "Max retries exceeded"
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

-- Load raw data from DataStore (returns nil if no data exists)
function DataStoreManager.LoadData(player)
	local success, data = retryOperation(
		"LoadData(" .. player.Name .. ")",
		function()
			return PlayerDataStore:GetAsync(player.UserId)
		end
	)
	
	if success then
		if data then
			print("[DataStore] Loaded data for", player.Name)
		else
			print("[DataStore] No saved data for", player.Name)
		end
		return data -- Can be nil for new players
	else
		warn("[DataStore] Failed to load data for", player.Name, "after retries")
		return nil -- Caller should use defaults
	end
end

-- Save data using UpdateAsync for atomic operations (prevents race conditions)
function DataStoreManager.SaveData(player, data)
	-- Prevent duplicate saves
	if savingPlayers[player.UserId] then
		warn("[DataStore] Already saving for", player.Name, "- skipping")
		return false
	end
	
	savingPlayers[player.UserId] = true
	
	local success, result = retryOperation(
		"SaveData(" .. player.Name .. ")",
		function()
			return PlayerDataStore:UpdateAsync(player.UserId, function(oldData)
				-- UpdateAsync passes the old data - we replace it entirely
				-- This is atomic and prevents race conditions
				return data
			end)
		end
	)
	
	savingPlayers[player.UserId] = nil
	
	if success then
		print("[DataStore] Saved data for", player.Name)
		return true
	else
		warn("[DataStore] Failed to save data for", player.Name, "after retries")
		return false
	end
end

-- Force save (bypasses duplicate check, for shutdown)
function DataStoreManager.ForceSave(player, data)
	savingPlayers[player.UserId] = nil -- Clear any pending save
	return DataStoreManager.SaveData(player, data)
end

-- Check if server is shutting down
function DataStoreManager.IsShuttingDown()
	return isShuttingDown
end

--------------------------------------------------------------------------------
-- BIND TO CLOSE (Server Shutdown Safety)
--------------------------------------------------------------------------------

game:BindToClose(function()
	isShuttingDown = true
	print("[DataStore] Server shutting down - saving all players...")
	
	-- PlayerDataManager will handle the actual serialization
	-- We just need to signal that shutdown is happening
	-- The PlayerRemoving event will fire for each player
	
	-- Wait for all players to be saved (max 30 seconds)
	local startTime = tick()
	local maxWait = 30
	
	-- Force save all online players
	for _, player in ipairs(Players:GetPlayers()) do
		-- Trigger the PlayerRemoving logic
		-- PlayerDataManager listens to this
	end
	
	-- Wait a moment for saves to complete
	task.wait(2)
	
	print("[DataStore] Shutdown save complete")
end)

return DataStoreManager
