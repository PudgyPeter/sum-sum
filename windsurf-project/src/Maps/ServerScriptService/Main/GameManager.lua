-- Server/GameManager.lua
-- Handles game utilities: rewards, speed toggle, skip wave

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local UpgradeData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("TowerUpgradeData"))
local GameSpeed = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GameSpeed"))
local Mob = require(script.Parent.Mob)
local ActManager = require(script.Parent.ActManager)

local events = ReplicatedStorage:WaitForChild("Events")
local functions = ReplicatedStorage:WaitForChild("Functions")

-- Get pre-created events and functions
local AwardVictoryRewardsEvent = events:WaitForChild("AwardVictoryRewards")
local ResetGameFunction = functions:WaitForChild("ResetGame")
local StartGameEvent = events:WaitForChild("StartGame")
local SkipWaveFunction = functions:WaitForChild("SkipWave")
local ToggleSpeedFunction = functions:WaitForChild("ToggleSpeed")
local SpeedChangedEvent = events:WaitForChild("SpeedChanged")

local GameManager = {}

-- Function to award victory rewards to a player
function GameManager.AwardVictoryRewards(player)
	print("[GameManager] Awarding victory rewards to", player.Name)

	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then
		warn("[GameManager] No PlayerData found for", player.Name)
		return
	end

	if UpgradeData.Rewards then
		for itemName, itemData in pairs(UpgradeData.Rewards) do
			if itemName == "Gems" then
				local gems = playerData:FindFirstChild("Gems")
				if gems then
					gems.Value = gems.Value + itemData.amountPerWin
					print("[GameManager]", player.Name, "now has", gems.Value, "gems")
				end
			end
		end
	end
end

-- Function to toggle game speed
function GameManager.ToggleSpeed(player)
	local currentSpeed = GameSpeed.GetSpeed()
	local availableSpeeds = GameSpeed.GetAvailableSpeeds()
	
	local currentIndex = 1
	for i, speed in ipairs(availableSpeeds) do
		if speed == currentSpeed then
			currentIndex = i
			break
		end
	end
	
	local nextIndex = (currentIndex % #availableSpeeds) + 1
	local newSpeed = availableSpeeds[nextIndex]

	GameSpeed.SetSpeed(newSpeed)
	print("[GameManager] Speed toggled to", newSpeed .. "x by", player.Name)
	
	Mob.UpdateAllMobSpeeds()
	SpeedChangedEvent:FireAllClients(newSpeed)

	return newSpeed
end

-- Function to skip current wave (spawn next wave while current is active)
function GameManager.SkipWave(player)
	print("[GameManager] Skip wave requested by", player.Name)
	
	local state = ActManager.GetState()
	if state ~= ActManager.States.Playing then
		warn("[GameManager] Cannot skip - not playing")
		return false
	end
	
	local currentWave = ActManager.GetCurrentWave()
	local wavesPerAct = ActManager.GetWavesPerAct()
	
	if currentWave >= wavesPerAct then
		warn("[GameManager] Cannot skip - final wave of act")
		return false
	end
	
	-- Award cash for skipping
	local reward = 50 + (10 * currentWave)
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr:FindFirstChild("Cash") then
			plr.Cash.Value = plr.Cash.Value + reward
		end
	end
	
	print("[GameManager] Wave skipped - advancing to next wave")
	return true
end

-- Function to reset game for retry
function GameManager.ResetGame(player)
	print("[GameManager] Reset requested by", player.Name)
	ActManager.ResetToPreMatch()
	return true
end

-- Event handlers
AwardVictoryRewardsEvent.OnServerEvent:Connect(function(player)
	GameManager.AwardVictoryRewards(player)
end)

ResetGameFunction.OnServerInvoke = function(player)
	return GameManager.ResetGame(player)
end

SkipWaveFunction.OnServerInvoke = function(player)
	return GameManager.SkipWave(player)
end

ToggleSpeedFunction.OnServerInvoke = function(player)
	return GameManager.ToggleSpeed(player)
end

print("[GameManager] Initialized")

return GameManager
