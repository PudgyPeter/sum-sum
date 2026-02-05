--[[
	ProgressManager.lua (RockMap/Game Place)
	Saves player progress (gems, stats) back to lobby's persistent DataStore.
	This ensures currency earned in-game is saved when players leave.
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

-- Must match lobby's DataStore name
local PLAYER_DATA_STORE_NAME = "PlayerData_v7"
local PlayerDataStore = DataStoreService:GetDataStore(PLAYER_DATA_STORE_NAME)

local ProgressManager = {}

-- Save player's progress to lobby DataStore
local function SavePlayerProgress(player)
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then
		warn("[Progress] No PlayerData folder for", player.Name)
		return false
	end
	
	-- Get current values
	local gems = playerData:FindFirstChild("Gems")
	if not gems then
		warn("[Progress] No Gems value for", player.Name)
		return false
	end
	
	print("[Progress] Saving progress for", player.Name, "- Gems:", gems.Value)
	
	-- Use UpdateAsync to safely modify only the fields we care about
	local success, err = pcall(function()
		PlayerDataStore:UpdateAsync(player.UserId, function(oldData)
			-- If no data exists, don't create it here (lobby handles that)
			if not oldData then
				warn("[Progress] No existing data for", player.Name, "- skipping save")
				return nil
			end
			
			-- Update only the gems (preserve everything else)
			oldData.Gems = gems.Value
			
			-- Update stats if they exist
			if oldData.Stats then
				-- You can add more stat tracking here later
				-- oldData.Stats.TotalGamesPlayed = oldData.Stats.TotalGamesPlayed + 1
			end
			
			print("[Progress] Updated data for", player.Name, "- New Gems:", oldData.Gems)
			return oldData
		end)
	end)
	
	if success then
		print("[Progress] Successfully saved progress for", player.Name)
		return true
	else
		warn("[Progress] Failed to save progress for", player.Name, ":", err)
		return false
	end
end

-- Auto-save when player leaves
Players.PlayerRemoving:Connect(function(player)
	print("[Progress] Player leaving, saving progress for", player.Name)
	SavePlayerProgress(player)
end)

-- Save all players on server shutdown
game:BindToClose(function()
	print("[Progress] Server shutting down, saving all player progress")
	
	local players = Players:GetPlayers()
	for _, player in ipairs(players) do
		SavePlayerProgress(player)
	end
	
	-- Give DataStore time to save
	task.wait(3)
end)

-- Manual save function (can be called by other scripts)
function ProgressManager.SavePlayer(player)
	return SavePlayerProgress(player)
end

-- Save all players (useful for periodic auto-save)
function ProgressManager.SaveAllPlayers()
	local players = Players:GetPlayers()
	local savedCount = 0
	
	for _, player in ipairs(players) do
		if SavePlayerProgress(player) then
			savedCount = savedCount + 1
		end
	end
	
	print("[Progress] Saved progress for", savedCount, "out of", #players, "players")
	return savedCount
end

print("[ProgressManager] Loaded - will save player progress on leave/shutdown")

return ProgressManager
