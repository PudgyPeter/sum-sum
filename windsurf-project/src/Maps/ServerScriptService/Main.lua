--[[
	Main.lua
	Central game controller for the map.
	Works with ActManager's state-based system.
]]

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local mob = require(script.Mob)
local tower = require(script.Tower)
local round = require(script.Round)
local GameManager = require(script.GameManager)
local ActManager = require(script.ActManager)
local GameSpeed = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GameSpeed"))
local MapData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MapData"))
local ModMenuHandler = require(script.ModMenuHandler)

local map = workspace.RockMap
local info = workspace.Info
local gameOver = false

-- Initialize ActManager with defaults (will be updated when player joins)
ActManager.Initialize("RockMap", 1)

-- Track if we've received teleport data
local teleportDataReceived = false

-- Handle player joining and get teleport data
Players.PlayerAdded:Connect(function(player)
	print("[Main] Player joined:", player.Name)
	
	-- Only process teleport data once (first player sets the act)
	if not teleportDataReceived then
		local teleportData = player:GetJoinData().TeleportData
		if teleportData then
			local mapId = teleportData.MapId or "RockMap"
			local selectedAct = teleportData.SelectedAct or 1
			print("[Main] Teleport data received - Map:", mapId, "Act:", selectedAct)
			ActManager.Initialize(mapId, selectedAct)
			teleportDataReceived = true
		else
			print("[Main] No teleport data, using defaults (Act 1)")
		end
	end
	
	-- Update message to show current act
	local actInfo = ActManager.GetCurrentActInfo()
	if actInfo then
		info.Message.Value = "Act " .. ActManager.GetCurrentAct() .. " - Press START GAME to begin"
	end
end)

-- Base health monitoring
map.Base.Humanoid.HealthChanged:Connect(function(health)
	if health <= 0 and not gameOver then
		gameOver = true
		ActManager.GameOver()
		info.Message.Value = "Game Over"
	end
end)

-- Reset game state helper
local function resetGameState()
	-- Clear all mobs
	local mobsFolder = workspace:FindFirstChild("Mobs")
	if mobsFolder then
		mobsFolder:ClearAllChildren()
	end
	
	-- Remove all towers
	local towersFolder = workspace:FindFirstChild("Towers")
	if towersFolder then
		for _, towerModel in ipairs(towersFolder:GetChildren()) do
			if towerModel:IsA("Model") then
				towerModel:Destroy()
			end
		end
	end
	
	-- Reset player values
	for _, player in ipairs(Players:GetPlayers()) do
		if player:FindFirstChild("PlacedTowers") then
			player.PlacedTowers.Value = 0
		end
		if player:FindFirstChild("Cash") then
			player.Cash.Value = 100
		end
	end
	
	-- Reset base health
	local base = map:FindFirstChild("Base")
	if base and base:FindFirstChild("Humanoid") then
		base.Humanoid.Health = base.Humanoid.MaxHealth
	end
	
	gameOver = false
	print("[Main] Game state reset")
end

-- Spawn wave and handle completion
local function runWave()
	local currentAct = ActManager.GetCurrentAct()
	local currentWave = ActManager.GetCurrentWave()
	local wavesPerAct = ActManager.GetWavesPerAct()
	
	print("[Main] Starting Act", currentAct, "Wave", currentWave, "/", wavesPerAct)
	info.Message.Value = ""
	
	-- Update Info.Wave for client display (use relative wave 1-15)
	info.Wave.Value = currentWave
	
	-- Spawn wave - pass act and wave separately (no more absolute waves)
	round.GetWave(currentAct, currentWave, map)
	
	-- Wait for wave to complete
	task.spawn(function()
		repeat
			task.wait(0.5)
		until #workspace.Mobs:GetChildren() == 0 or gameOver
		
		if gameOver then return end
		
		-- Award cash reward
		local reward = 50 + (10 * currentWave)
		for _, player in ipairs(Players:GetPlayers()) do
			if player:FindFirstChild("Cash") then
				player.Cash.Value = player.Cash.Value + reward
			end
		end
		print("[Main] Awarded", reward, "cash to all players")
		
		-- Check if more waves remain
		if ActManager.NextWave() then
			-- Countdown to next wave
			for i = 3, 1, -1 do
				info.Message.Value = "Next wave in " .. i
				task.wait(GameSpeed.GetWaitTime(1))
			end
			-- Start next wave
			runWave()
		else
			-- Act complete!
			print("[Main] Act", currentAct, "completed!")
			ActManager.CompleteAct()
			
			if currentAct >= ActManager.GetTotalActs() then
				info.Message.Value = "Victory! All Acts Complete!"
			else
				info.Message.Value = "Act " .. currentAct .. " Complete! Press NEXT ACT to continue"
			end
		end
	end)
end

-- Listen for game start from GameManager
local events = ReplicatedStorage:WaitForChild("Events")
local StartGameEvent = events:WaitForChild("StartGame")
local NextActEvent = events:WaitForChild("NextAct")

StartGameEvent.OnServerEvent:Connect(function(player)
	print("[Main] StartGame requested by", player.Name)
	
	local state = ActManager.GetState()
	if state == ActManager.States.PreMatch then
		if ActManager.StartGame() then
			runWave()
		end
	elseif state == ActManager.States.ActComplete then
		-- Start next act
		if ActManager.StartNextAct() then
			resetGameState()
			local actInfo = ActManager.GetCurrentActInfo()
			info.Message.Value = "Act " .. ActManager.GetCurrentAct() .. " - Press START GAME to begin"
		end
	else
		warn("[Main] Cannot start - current state:", state)
	end
end)

-- Listen for next act request (from "Next" button after act complete)
NextActEvent.OnServerEvent:Connect(function(player)
	print("[Main] NextAct requested by", player.Name)
	
	local state = ActManager.GetState()
	if state == ActManager.States.ActComplete then
		local currentAct = ActManager.GetCurrentAct()
		local totalActs = ActManager.GetTotalActs()
		
		-- Check if this was the final act (Act 5)
		if currentAct >= totalActs then
			-- Get next map and teleport there
			local currentMapId = ActManager.GetMapId()
			local nextMap = MapData.GetNextMap(currentMapId)
			
			if nextMap and nextMap.PlaceId and nextMap.PlaceId > 0 then
				print("[Main] Teleporting to next map:", nextMap.Name)
				info.Message.Value = "Loading " .. nextMap.Name .. "..."
				
				-- Teleport all players to the next map, starting at Act 1
				local teleportOptions = Instance.new("TeleportOptions")
				teleportOptions:SetTeleportData({
					MapId = nextMap.ID,
					SelectedAct = 1
				})
				
				local playersToTeleport = Players:GetPlayers()
				local success, result = pcall(function()
					return TeleportService:TeleportAsync(nextMap.PlaceId, playersToTeleport, teleportOptions)
				end)
				
				if not success then
					warn("[Main] Failed to teleport to next map:", result)
					info.Message.Value = "Failed to load next map. Returning to lobby..."
					-- Fallback: return to lobby
					task.wait(2)
					for _, p in ipairs(playersToTeleport) do
						TeleportService:Teleport(game.PlaceId, p) -- Return to lobby
					end
				end
			else
				-- No next map available, return to lobby
				print("[Main] No next map available, congratulations message")
				info.Message.Value = "Congratulations! You've completed all maps!"
			end
		else
			-- Not the final act, proceed to next act
			if ActManager.StartNextAct() then
				resetGameState()
				info.Message.Value = "Act " .. ActManager.GetCurrentAct() .. " - Press START GAME to begin"
			end
		end
	else
		warn("[Main] Cannot advance to next act - current state:", state)
	end
end)

print("[Main] Initialized - waiting for players")
