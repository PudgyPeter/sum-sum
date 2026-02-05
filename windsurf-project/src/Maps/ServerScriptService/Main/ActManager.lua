--[[
	ActManager.lua
	State-based act progression system.
	
	Game States:
	- PreMatch: Waiting for players to press START
	- Playing: Waves are active
	- ActComplete: Current act finished, waiting to continue or return to lobby
	- GameOver: Base destroyed
	
	Each act has 15 waves (1-15), regardless of which act.
	The Round module handles different mob configurations per act.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local MapData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MapData"))
local PlayerDataManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PlayerDataManager"))

local ActManager = {}

-- Game States
ActManager.States = {
	PreMatch = "PreMatch",
	Playing = "Playing",
	ActComplete = "ActComplete",
	GameOver = "GameOver"
}

-- Current state (single source of truth)
local currentState = ActManager.States.PreMatch
local currentMapId = "RockMap"
local currentAct = 1
local currentWave = 0  -- 1-15 within the act
local wavesPerAct = 15

-- RemoteEvents/Functions
local events = ReplicatedStorage:WaitForChild("Events")
local functions = ReplicatedStorage:WaitForChild("Functions")

-- Create events/functions
local function getOrCreateEvent(name)
	local event = events:FindFirstChild(name)
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = events
	end
	return event
end

local function getOrCreateFunction(name)
	local func = functions:FindFirstChild(name)
	if not func then
		func = Instance.new("RemoteFunction")
		func.Name = name
		func.Parent = functions
	end
	return func
end

local ActCompleteEvent = getOrCreateEvent("ActComplete")
local NextActEvent = getOrCreateEvent("NextAct")
local StateChangedEvent = getOrCreateEvent("StateChanged")
local GetActInfoFunction = getOrCreateFunction("GetActInfo")

print("[ActManager] Module loaded")

-- Initialize the act system
function ActManager.Initialize(mapId, startAct)
	currentMapId = mapId or "RockMap"
	currentAct = startAct or 1
	currentWave = 0
	currentState = ActManager.States.PreMatch
	
	print("[ActManager] Initialized - Map:", currentMapId, "Act:", currentAct, "State:", currentState)
end

-- Get current state
function ActManager.GetState()
	return currentState
end

-- Set state
function ActManager.SetState(newState)
	local oldState = currentState
	currentState = newState
	print("[ActManager] State changed:", oldState, "->", newState)
	StateChangedEvent:FireAllClients(newState, currentAct, currentWave)
end

-- Get current act number (1-5)
function ActManager.GetCurrentAct()
	return currentAct
end

-- Get current wave within act (1-15)
function ActManager.GetCurrentWave()
	return currentWave
end

-- Get waves per act
function ActManager.GetWavesPerAct()
	return wavesPerAct
end

-- Get current act info from MapData
function ActManager.GetCurrentActInfo()
	local map = MapData.GetMapById(currentMapId)
	if not map then
		warn("[ActManager] Map not found:", currentMapId)
		return nil
	end
	
	local act = MapData.GetAct(currentMapId, currentAct)
	if not act then
		warn("[ActManager] Act not found:", currentMapId, "Act", currentAct)
		return nil
	end
	
	return act
end

-- Get total acts for current map
function ActManager.GetTotalActs()
	return MapData.GetTotalActs(currentMapId)
end

-- Get current map ID
function ActManager.GetMapId()
	return currentMapId
end

-- Start the game (transition from PreMatch to Playing)
function ActManager.StartGame()
	if currentState ~= ActManager.States.PreMatch then
		warn("[ActManager] Cannot start game - not in PreMatch state")
		return false
	end
	
	currentWave = 1
	ActManager.SetState(ActManager.States.Playing)
	print("[ActManager] Game started - Act", currentAct, "Wave", currentWave)
	return true
end

-- Advance to next wave (returns false if act is complete)
function ActManager.NextWave()
	if currentState ~= ActManager.States.Playing then
		warn("[ActManager] Cannot advance wave - not Playing")
		return false
	end
	
	if currentWave >= wavesPerAct then
		-- Act complete
		return false
	end
	
	currentWave = currentWave + 1
	print("[ActManager] Wave advanced to", currentWave, "of", wavesPerAct)
	return true
end

-- Complete the current act
function ActManager.CompleteAct()
	currentState = ActManager.States.ActComplete
	print("[ActManager] Act", currentAct, "completed!")
	
	-- Save progress for all players
	for _, player in ipairs(Players:GetPlayers()) do
		PlayerDataManager.SetMapProgress(player, currentMapId, currentAct)
	end
	
	-- Notify clients
	ActCompleteEvent:FireAllClients(currentAct, ActManager.GetTotalActs())
	ActManager.SetState(ActManager.States.ActComplete)
end

-- Start next act (called after ActComplete)
function ActManager.StartNextAct()
	if currentState ~= ActManager.States.ActComplete then
		warn("[ActManager] Cannot start next act - not in ActComplete state")
		return false
	end
	
	if currentAct >= ActManager.GetTotalActs() then
		warn("[ActManager] Already on final act")
		return false
	end
	
	currentAct = currentAct + 1
	currentWave = 0
	ActManager.SetState(ActManager.States.PreMatch)
	
	print("[ActManager] Advanced to Act", currentAct)
	return true
end

-- Game over (base destroyed)
function ActManager.GameOver()
	ActManager.SetState(ActManager.States.GameOver)
	print("[ActManager] Game Over!")
end

-- Reset game state (for retrying or starting fresh)
function ActManager.ResetToPreMatch()
	currentWave = 0
	ActManager.SetState(ActManager.States.PreMatch)
	print("[ActManager] Reset to PreMatch for Act", currentAct)
end

-- Full reset to act 1
function ActManager.FullReset()
	currentAct = 1
	currentWave = 0
	ActManager.SetState(ActManager.States.PreMatch)
	print("[ActManager] Full reset to Act 1")
end

-- Check if current wave is the final wave of the act
function ActManager.IsFinalWave()
	return currentWave >= wavesPerAct
end

-- Get all state info (for clients)
function ActManager.GetFullState()
	return {
		State = currentState,
		MapId = currentMapId,
		CurrentAct = currentAct,
		CurrentWave = currentWave,
		WavesPerAct = wavesPerAct,
		TotalActs = ActManager.GetTotalActs(),
		ActInfo = ActManager.GetCurrentActInfo()
	}
end

-- Server handlers (Note: NextActEvent is handled in Main.lua for proper reset)
GetActInfoFunction.OnServerInvoke = function()
	return ActManager.GetFullState()
end

return ActManager
