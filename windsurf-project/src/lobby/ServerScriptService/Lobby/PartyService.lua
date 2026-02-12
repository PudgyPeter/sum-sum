--[[
	PartyService.lua
	Manages the PlayBox party system in the lobby.
	Players touch TpPart to teleport into the PlayBox where they form a party.
	Progress is restricted to the lowest-progressed player in the party.
	Maximum 4 players per PlayBox.
	
	Supports multiple PlayBoxes - each creates an independent party.
	First player to enter becomes the Party Host (only host can start match).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local MapProgressService = require(script.Parent.MapProgressService)
local MapData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MapData"))

local PartyService = {}

-- Configuration
local PLAYBOX_CHECK_INTERVAL = 0.5 -- How often to check who's in the PlayBox
local TPPART_NAME = "TpPart" -- Name of the teleport trigger part
local MAX_PARTY_SIZE = 4 -- Maximum players allowed in PlayBox

-- State for multiple PlayBoxes
-- parties[playBoxModel] = { host = Player, members = {Player = true}, originalPositions = {Player = CFrame} }
local parties = {}
-- playerToParty[Player] = playBoxModel (quick lookup for which party a player is in)
local playerToParty = {}
-- playerDebounce[Player] = tick() (prevents immediate re-entry after leaving)
local playerDebounce = {}
local DEBOUNCE_TIME = 1.5 -- Seconds before player can re-enter after leaving

-- Remote Events/Functions (pre-created in Studio)
local functions = ReplicatedStorage:WaitForChild("Functions")
local events = ReplicatedStorage:WaitForChild("Events")

local GetPartyInfoFunction = functions:WaitForChild("GetPartyInfo")
local PartyUpdatedEvent = events:WaitForChild("PartyUpdated")
local TeleportPartyFunction = functions:WaitForChild("TeleportParty")
local LeavePartyFunction = functions:WaitForChild("LeaveParty")

--------------------------------------------------------------------------------
-- PROGRESS CALCULATION
--------------------------------------------------------------------------------

-- Get the maximum map and act a player can access
-- Returns: { mapIndex = number, actNumber = number, mapId = string }
function PartyService.GetPlayerMaxProgress(player)
	local allMaps = MapData.GetAllMaps()
	local maxProgress = {
		mapIndex = 1,
		actNumber = 1,
		mapId = allMaps[1] and allMaps[1].ID or nil
	}
	
	for i, map in ipairs(allMaps) do
		-- Check if this map is unlocked
		if MapProgressService.IsMapUnlocked(player, map.ID) then
			local highestAct = PlayerDataManager.GetMapProgress(player, map.ID)
			-- Player can access up to highestAct + 1 (next act to play)
			local accessibleAct = math.min(highestAct + 1, #map.Acts)
			
			-- Update max progress if this is further
			if i > maxProgress.mapIndex or (i == maxProgress.mapIndex and accessibleAct > maxProgress.actNumber) then
				maxProgress.mapIndex = i
				maxProgress.actNumber = accessibleAct
				maxProgress.mapId = map.ID
			end
		end
	end
	
	return maxProgress
end

-- Calculate the minimum progress across all players in the party
-- This is the furthest map/act the party can travel to together
function PartyService.CalculatePartyProgress(players)
	if #players == 0 then
		return nil
	end
	
	local minProgress = nil
	
	for _, player in ipairs(players) do
		local playerProgress = PartyService.GetPlayerMaxProgress(player)
		
		if not minProgress then
			minProgress = playerProgress
		else
			-- Compare: lower map index = less progress
			-- Same map, lower act = less progress
			if playerProgress.mapIndex < minProgress.mapIndex then
				minProgress = playerProgress
			elseif playerProgress.mapIndex == minProgress.mapIndex and playerProgress.actNumber < minProgress.actNumber then
				minProgress = playerProgress
			end
		end
	end
	
	return minProgress
end

-- Check if a specific map/act is accessible to the party
function PartyService.CanPartyAccessMap(players, mapId, actNumber)
	local partyProgress = PartyService.CalculatePartyProgress(players)
	if not partyProgress then return false end
	
	local targetMapIndex = MapData.GetMapIndex(mapId)
	if not targetMapIndex then return false end
	
	-- Check if target is within party's allowed progress
	if targetMapIndex < partyProgress.mapIndex then
		return true
	elseif targetMapIndex == partyProgress.mapIndex then
		return actNumber <= partyProgress.actNumber
	end
	
	return false
end

-- Get which player is holding back the party (lowest progress)
function PartyService.GetLimitingPlayer(players)
	if #players <= 1 then return nil end
	
	local lowestPlayer = nil
	local lowestProgress = nil
	
	for _, player in ipairs(players) do
		local progress = PartyService.GetPlayerMaxProgress(player)
		
		if not lowestProgress then
			lowestProgress = progress
			lowestPlayer = player
		else
			if progress.mapIndex < lowestProgress.mapIndex then
				lowestProgress = progress
				lowestPlayer = player
			elseif progress.mapIndex == lowestProgress.mapIndex and progress.actNumber < lowestProgress.actNumber then
				lowestProgress = progress
				lowestPlayer = player
			end
		end
	end
	
	return lowestPlayer, lowestProgress
end

--------------------------------------------------------------------------------
-- PLAYBOX DETECTION & MANAGEMENT (MULTI-BOX SUPPORT)
--------------------------------------------------------------------------------

-- Find all PlayBox models in workspace (any model with a TpPart child)
function PartyService.GetAllPlayBoxModels()
	local playBoxes = {}
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and obj:FindFirstChild(TPPART_NAME) then
			table.insert(playBoxes, obj)
		end
	end
	return playBoxes
end

-- Get or create party data for a PlayBox
function PartyService.GetOrCreateParty(playBoxModel)
	if not parties[playBoxModel] then
		parties[playBoxModel] = {
			host = nil,
			members = {},
			originalPositions = {}
		}
	end
	return parties[playBoxModel]
end

-- Get the PlayBox a player is currently in
function PartyService.GetPlayerPlayBox(player)
	return playerToParty[player]
end

-- Get spawn position inside the PlayBox (center of the model)
function PartyService.GetPlayBoxSpawnPosition(playBoxModel)
	-- Try to find a SpawnPoint part first
	local spawnPoint = playBoxModel:FindFirstChild("SpawnPoint")
	if spawnPoint and spawnPoint:IsA("BasePart") then
		return spawnPoint.CFrame + Vector3.new(0, 3, 0)
	end
	
	-- Otherwise use the model's center
	local primaryPart = playBoxModel.PrimaryPart
	if primaryPart then
		return primaryPart.CFrame + Vector3.new(0, 3, 0)
	end
	
	-- Fallback: calculate bounding box center
	local cf, size = playBoxModel:GetBoundingBox()
	return cf + Vector3.new(0, 3, 0)
end

-- Check if a player is inside a specific PlayBox model bounds
function PartyService.IsPlayerInPlayBox(player, playBoxModel)
	local character = player.Character
	if not character then return false end
	
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return false end
	
	-- Get bounding box of the PlayBox model
	local boxCFrame, boxSize = playBoxModel:GetBoundingBox()
	
	-- Convert player position to local space of the box
	local localPos = boxCFrame:PointToObjectSpace(rootPart.Position)
	
	-- Check if within bounds (with margin for movement)
	local halfSize = boxSize / 2
	return math.abs(localPos.X) <= halfSize.X + 2 and
		   math.abs(localPos.Y) <= halfSize.Y + 5 and -- Extra height tolerance
		   math.abs(localPos.Z) <= halfSize.Z + 2
end

-- Get current player count in a specific PlayBox
function PartyService.GetPlayerCountInBox(playBoxModel)
	local party = parties[playBoxModel]
	if not party then return 0 end
	
	local count = 0
	for _ in pairs(party.members) do
		count = count + 1
	end
	return count
end

-- Check if a specific PlayBox has room for more players
function PartyService.HasRoom(playBoxModel)
	return PartyService.GetPlayerCountInBox(playBoxModel) < MAX_PARTY_SIZE
end

-- Teleport player into a specific PlayBox
function PartyService.TeleportPlayerIntoBox(player, playBoxModel)
	if not playBoxModel then
		warn("[PartyService] PlayBox model not provided")
		return false, "PlayBox not found"
	end
	
	-- Check if player is already in any party
	if playerToParty[player] then
		return false, "Already in a party"
	end
	
	-- Check if box is full
	if not PartyService.HasRoom(playBoxModel) then
		return false, "PlayBox is full (max " .. MAX_PARTY_SIZE .. " players)"
	end
	
	local character = player.Character
	if not character then
		return false, "No character"
	end
	
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return false, "No HumanoidRootPart"
	end
	
	-- Get or create party for this PlayBox
	local party = PartyService.GetOrCreateParty(playBoxModel)
	
	-- Store original position for potential return
	party.originalPositions[player] = rootPart.CFrame
	
	-- Teleport to PlayBox
	local spawnCFrame = PartyService.GetPlayBoxSpawnPosition(playBoxModel)
	
	-- Offset position based on current player count to avoid stacking
	local playerCount = PartyService.GetPlayerCountInBox(playBoxModel)
	local offsetX = (playerCount % 2) * 3 - 1.5
	local offsetZ = math.floor(playerCount / 2) * 3 - 1.5
	spawnCFrame = spawnCFrame + Vector3.new(offsetX, 0, offsetZ)
	
	rootPart.CFrame = spawnCFrame
	
	-- Mark player as in this party
	party.members[player] = true
	playerToParty[player] = playBoxModel
	
	-- First player becomes host
	if not party.host then
		party.host = player
		print("[PartyService]", player.Name, "is now the Party Host for", playBoxModel.Name)
	end
	
	-- Notify all players in this party
	PartyService.NotifyPartyUpdate(playBoxModel)
	
	print("[PartyService]", player.Name, "entered", playBoxModel.Name, ". Players:", PartyService.GetPlayerCountInBox(playBoxModel))
	return true
end

-- Remove player from their current party/PlayBox (teleport them out)
function PartyService.RemovePlayerFromBox(player)
	local playBoxModel = playerToParty[player]
	if not playBoxModel then
		return false, "Not in a party"
	end
	
	local party = parties[playBoxModel]
	if not party then
		return false, "Party not found"
	end
	
	-- Remove from party
	party.members[player] = nil
	playerToParty[player] = nil
	
	-- Set debounce to prevent immediate re-entry
	playerDebounce[player] = tick()
	
	-- Teleport back to original position if stored
	local character = player.Character
	if character and party.originalPositions[player] then
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			rootPart.CFrame = party.originalPositions[player]
		end
	end
	party.originalPositions[player] = nil
	
	-- If host left, assign new host
	if party.host == player then
		party.host = nil
		-- Find new host (first remaining member)
		for member, _ in pairs(party.members) do
			if member and member.Parent then
				party.host = member
				print("[PartyService]", member.Name, "is now the new Party Host for", playBoxModel.Name)
				break
			end
		end
	end
	
	-- Notify all players in this party
	PartyService.NotifyPartyUpdate(playBoxModel)
	
	-- Also notify the player who left
	PartyUpdatedEvent:FireClient(player, {
		inParty = false,
		soloInBox = false,
		members = {},
		partyProgress = nil,
		limitingPlayer = nil,
		maxCapacity = MAX_PARTY_SIZE,
		hasRoom = true
	})
	
	print("[PartyService]", player.Name, "left", playBoxModel.Name, ". Players:", PartyService.GetPlayerCountInBox(playBoxModel))
	return true
end

-- Get all players in a specific PlayBox
function PartyService.GetPlayersInPlayBox(playBoxModel)
	local party = parties[playBoxModel]
	if not party then return {} end
	
	local players = {}
	for player, _ in pairs(party.members) do
		if player and player.Parent then
			table.insert(players, player)
		end
	end
	return players
end

-- Get all players in the same party as a given player
function PartyService.GetPlayersInSameParty(player)
	local playBoxModel = playerToParty[player]
	if not playBoxModel then return {} end
	return PartyService.GetPlayersInPlayBox(playBoxModel)
end

-- Check if player is the host of their party
function PartyService.IsPlayerHost(player)
	local playBoxModel = playerToParty[player]
	if not playBoxModel then return false end
	
	local party = parties[playBoxModel]
	return party and party.host == player
end

-- Get the host of a player's party
function PartyService.GetPartyHost(player)
	local playBoxModel = playerToParty[player]
	if not playBoxModel then return nil end
	
	local party = parties[playBoxModel]
	return party and party.host
end

-- Notify all players in a specific party of updates
function PartyService.NotifyPartyUpdate(playBoxModel)
	if not playBoxModel then return end
	
	local party = parties[playBoxModel]
	if not party then return end
	
	local partyInfo = PartyService.GetPartyInfoForBox(playBoxModel)
	
	-- Notify all players in this party
	for player, _ in pairs(party.members) do
		if player and player.Parent then
			PartyUpdatedEvent:FireClient(player, partyInfo)
		end
	end
end

-- Update all parties (check if anyone left bounds)
function PartyService.UpdateAllPartyStates()
	for playBoxModel, party in pairs(parties) do
		local hasChanged = false
		local playersToRemove = {}
		
		-- Check for players who left the box bounds
		for player, _ in pairs(party.members) do
			if not player or not player.Parent then
				-- Player left the game
				table.insert(playersToRemove, player)
				hasChanged = true
			elseif not PartyService.IsPlayerInPlayBox(player, playBoxModel) then
				-- Player walked out of the box
				table.insert(playersToRemove, player)
				hasChanged = true
				print("[PartyService]", player.Name, "walked out of", playBoxModel.Name)
			end
		end
		
		-- Remove players who left
		for _, player in ipairs(playersToRemove) do
			party.members[player] = nil
			party.originalPositions[player] = nil
			playerToParty[player] = nil
			
			-- If host left, assign new host
			if party.host == player then
				party.host = nil
				for member, _ in pairs(party.members) do
					if member and member.Parent then
						party.host = member
						print("[PartyService]", member.Name, "is now the new Party Host")
						break
					end
				end
			end
		end
		
		if hasChanged then
			PartyService.NotifyPartyUpdate(playBoxModel)
		end
	end
end

-- Setup TpPart touch detection for a specific PlayBox
function PartyService.SetupTpPartTriggerForBox(playBoxModel)
	local tpPart = playBoxModel:FindFirstChild(TPPART_NAME)
	if not tpPart then
		warn("[PartyService] TpPart not found in", playBoxModel.Name)
		return
	end
	
	-- Connect touch event
	tpPart.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then return end
		
		local humanoid = character:FindFirstChild("Humanoid")
		if not humanoid then return end
		
		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end
		
		-- Debounce - check if already in any party
		if playerToParty[player] then return end
		
		-- Check if player is on cooldown from recently leaving
		if playerDebounce[player] then
			local timeSinceLeave = tick() - playerDebounce[player]
			if timeSinceLeave < DEBOUNCE_TIME then
				-- Still on cooldown
				local remainingTime = math.ceil(DEBOUNCE_TIME - timeSinceLeave)
				PartyUpdatedEvent:FireClient(player, {
					inParty = false,
					error = "Please wait " .. remainingTime .. " seconds before re-entering"
				})
				return
			else
				-- Cooldown expired, clear it
				playerDebounce[player] = nil
			end
		end
		
		-- Try to teleport player into this specific box
		local success, errorMsg = PartyService.TeleportPlayerIntoBox(player, playBoxModel)
		if not success then
			-- Notify player they couldn't enter
			PartyUpdatedEvent:FireClient(player, {
				inParty = false,
				error = errorMsg
			})
		end
	end)
	
	print("[PartyService] TpPart trigger setup for", playBoxModel.Name)
end

-- Setup all PlayBox triggers
function PartyService.SetupAllTpPartTriggers()
	local playBoxes = PartyService.GetAllPlayBoxModels()
	for _, playBoxModel in ipairs(playBoxes) do
		PartyService.SetupTpPartTriggerForBox(playBoxModel)
	end
	print("[PartyService] Setup triggers for", #playBoxes, "PlayBox(es)")
end

--------------------------------------------------------------------------------
-- PARTY INFO
--------------------------------------------------------------------------------

-- Get full party information for a specific PlayBox
function PartyService.GetPartyInfoForBox(playBoxModel)
	if not playBoxModel then
		return {
			inParty = false,
			soloInBox = false,
			members = {},
			partyProgress = nil,
			limitingPlayer = nil,
			host = nil,
			isHost = false,
			maxCapacity = MAX_PARTY_SIZE,
			hasRoom = true
		}
	end
	
	local party = parties[playBoxModel]
	if not party then
		return {
			inParty = false,
			soloInBox = false,
			members = {},
			partyProgress = nil,
			limitingPlayer = nil,
			host = nil,
			isHost = false,
			maxCapacity = MAX_PARTY_SIZE,
			hasRoom = true
		}
	end
	
	local players = PartyService.GetPlayersInPlayBox(playBoxModel)
	
	if #players == 0 then
		return {
			inParty = false,
			soloInBox = false,
			members = {},
			partyProgress = nil,
			limitingPlayer = nil,
			host = nil,
			isHost = false,
			maxCapacity = MAX_PARTY_SIZE,
			hasRoom = true
		}
	end
	
	local partyProgress = PartyService.CalculatePartyProgress(players)
	local limitingPlayer, limitingProgress = PartyService.GetLimitingPlayer(players)
	
	-- Build member list with individual progress
	local members = {}
	for _, player in ipairs(players) do
		local progress = PartyService.GetPlayerMaxProgress(player)
		local map = MapData.GetMapById(progress.mapId)
		
		table.insert(members, {
			UserId = player.UserId,
			Name = player.Name,
			DisplayName = player.DisplayName,
			MaxMapIndex = progress.mapIndex,
			MaxActNumber = progress.actNumber,
			MaxMapId = progress.mapId,
			MaxMapName = map and map.Name or "Unknown",
			IsLimiting = (limitingPlayer == player and #players > 1),
			IsHost = (party.host == player)
		})
	end
	
	-- Get map name for party progress
	local partyMapName = "Unknown"
	if partyProgress then
		local map = MapData.GetMapById(partyProgress.mapId)
		partyMapName = map and map.Name or "Unknown"
	end
	
	return {
		inParty = #players > 1,
		soloInBox = #players == 1,
		memberCount = #players,
		maxCapacity = MAX_PARTY_SIZE,
		hasRoom = #players < MAX_PARTY_SIZE,
		members = members,
		partyProgress = partyProgress and {
			mapIndex = partyProgress.mapIndex,
			actNumber = partyProgress.actNumber,
			mapId = partyProgress.mapId,
			mapName = partyMapName
		} or nil,
		limitingPlayer = limitingPlayer and {
			UserId = limitingPlayer.UserId,
			Name = limitingPlayer.Name,
			DisplayName = limitingPlayer.DisplayName
		} or nil,
		host = party.host and {
			UserId = party.host.UserId,
			Name = party.host.Name,
			DisplayName = party.host.DisplayName
		} or nil,
		playBoxName = playBoxModel.Name
	}
end

-- Get party info for a specific player (based on which PlayBox they're in)
function PartyService.GetPartyInfoForPlayer(player)
	local playBoxModel = playerToParty[player]
	if not playBoxModel then
		return {
			inParty = false,
			soloInBox = false,
			members = {},
			partyProgress = nil,
			limitingPlayer = nil,
			host = nil,
			isHost = false,
			maxCapacity = MAX_PARTY_SIZE,
			hasRoom = true
		}
	end
	
	local info = PartyService.GetPartyInfoForBox(playBoxModel)
	info.isHost = PartyService.IsPlayerHost(player)
	return info
end

-- Legacy function for compatibility
function PartyService.GetPartyInfo()
	-- This now returns empty - use GetPartyInfoForPlayer instead
	return {
		inParty = false,
		soloInBox = false,
		members = {},
		partyProgress = nil,
		limitingPlayer = nil,
		host = nil,
		isHost = false,
		maxCapacity = MAX_PARTY_SIZE,
		hasRoom = true
	}
end

-- Get available maps for the party (respecting progress limits)
-- Returns ALL maps with IsUnlocked status (matching solo format)
function PartyService.GetAvailableMapsForParty(players)
	local partyProgress = PartyService.CalculatePartyProgress(players)
	if not partyProgress then return {} end
	
	local allMaps = MapData.GetAllMaps()
	local availableMaps = {}
	
	for i, map in ipairs(allMaps) do
		local isUnlocked = i <= partyProgress.mapIndex
		
		-- For earlier maps all acts are completed; for the current map, completed up to actNumber - 1
		local highestCompletedAct = 0
		if i < partyProgress.mapIndex then
			highestCompletedAct = #map.Acts -- earlier map, all acts done
		elseif i == partyProgress.mapIndex then
			highestCompletedAct = partyProgress.actNumber - 1 -- actNumber is next accessible
		end
		
		table.insert(availableMaps, {
			ID = map.ID,
			Name = map.Name,
			Description = map.Description,
			Difficulty = map.Difficulty,
			ImageId = map.ImageId,
			PlaceId = map.PlaceId,
			IsUnlocked = isUnlocked,
			HighestCompletedAct = highestCompletedAct,
			TotalActs = #map.Acts,
			IsFullyCompleted = highestCompletedAct >= #map.Acts,
			MapIndex = i
		})
	end
	
	return availableMaps
end

--------------------------------------------------------------------------------
-- TELEPORT HANDLING
--------------------------------------------------------------------------------

-- Teleport the party to a map (only host can do this)
function PartyService.TeleportParty(requestingPlayer, mapId, selectedAct)
	-- Get the player's party
	local playBoxModel = playerToParty[requestingPlayer]
	if not playBoxModel then
		return false, "You must be in a PlayBox to start a match"
	end
	
	-- Check if player is the host
	if not PartyService.IsPlayerHost(requestingPlayer) then
		return false, "Only the Party Host can start a match"
	end
	
	local players = PartyService.GetPlayersInSameParty(requestingPlayer)
	
	-- Check if the party can access this map/act
	if not PartyService.CanPartyAccessMap(players, mapId, selectedAct) then
		local limitingPlayer = PartyService.GetLimitingPlayer(players)
		local limitName = limitingPlayer and limitingPlayer.DisplayName or "a party member"
		return false, "Cannot travel to this map. " .. limitName .. " hasn't progressed far enough."
	end
	
	-- Use TeleportManager to handle the actual teleport
	-- Require directly here to avoid any circular dependency issues
	local TeleportMgr = require(script.Parent.TeleportManager)
	
	if not TeleportMgr or not TeleportMgr.TeleportPartyToGame then
		warn("[PartyService] TeleportManager or TeleportPartyToGame not available, using fallback")
		-- Fallback: teleport each player individually
		if TeleportMgr and TeleportMgr.TeleportToGame then
			for _, p in ipairs(players) do
				TeleportMgr.TeleportToGame(p, mapId, selectedAct)
			end
			return true
		end
		return false, "Teleport system unavailable"
	end
	
	return TeleportMgr.TeleportPartyToGame(players, mapId, selectedAct)
end

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

-- Start the PlayBox detection loop (checks all parties)
local function startPlayBoxLoop()
	RunService.Heartbeat:Connect(function()
		-- Throttle updates
		if not PartyService._lastUpdate or (tick() - PartyService._lastUpdate) >= PLAYBOX_CHECK_INTERVAL then
			PartyService._lastUpdate = tick()
			PartyService.UpdateAllPartyStates()
		end
	end)
end

-- Handle player leaving the game
Players.PlayerRemoving:Connect(function(player)
	local playBoxModel = playerToParty[player]
	if playBoxModel then
		local party = parties[playBoxModel]
		if party then
			party.members[player] = nil
			party.originalPositions[player] = nil
			playerToParty[player] = nil
			
			-- If host left, assign new host
			if party.host == player then
				party.host = nil
				for member, _ in pairs(party.members) do
					if member and member.Parent then
						party.host = member
						print("[PartyService]", member.Name, "is now the new Party Host")
						break
					end
				end
			end
			
			-- Notify remaining party members
			PartyService.NotifyPartyUpdate(playBoxModel)
			print("[PartyService]", player.Name, "left the game. Players remaining in", playBoxModel.Name, ":", PartyService.GetPlayerCountInBox(playBoxModel))
		end
	end
end)

-- Remote Function handlers
GetPartyInfoFunction.OnServerInvoke = function(player)
	-- Return party info for the player's current party
	return PartyService.GetPartyInfoForPlayer(player)
end

TeleportPartyFunction.OnServerInvoke = function(player, mapId, selectedAct)
	return PartyService.TeleportParty(player, mapId, selectedAct)
end

-- LeaveParty handler
LeavePartyFunction.OnServerInvoke = function(player)
	return PartyService.RemovePlayerFromBox(player)
end

-- Get pre-created GetPartyMaps function
local GetPartyMapsFunction = functions:WaitForChild("GetPartyMaps")

GetPartyMapsFunction.OnServerInvoke = function(player)
	local players = PartyService.GetPlayersInSameParty(player)
	if #players == 0 then
		-- Solo player - return their normal available maps
		return MapProgressService.GetAvailableMaps(player)
	end
	return PartyService.GetAvailableMapsForParty(players)
end

-- Get pre-created GetPartyActs function
local GetPartyActsFunction = functions:WaitForChild("GetPartyActs")

-- Get available acts for a specific map respecting party restrictions
-- Returns ALL acts with IsUnlocked status (matching solo format)
function PartyService.GetAvailableActsForParty(players, mapId)
	local partyProgress = PartyService.CalculatePartyProgress(players)
	if not partyProgress then return {} end
	
	local map = MapData.GetMapById(mapId)
	if not map then return {} end
	
	if not map.Acts then return {} end
	
	local targetMapIndex = MapData.GetMapIndex(mapId)
	if not targetMapIndex then return {} end
	
	local allActs = {}
	local maxAct
	if targetMapIndex > partyProgress.mapIndex then
		maxAct = 0 -- Map not accessible, no acts unlocked
	elseif targetMapIndex == partyProgress.mapIndex then
		maxAct = partyProgress.actNumber
	else
		maxAct = #map.Acts -- Earlier map, all acts accessible
	end
	
	-- Determine highest completed act for this map within party context
	local highestCompletedAct = 0
	if targetMapIndex < partyProgress.mapIndex then
		highestCompletedAct = #map.Acts -- earlier map, all acts done
	elseif targetMapIndex == partyProgress.mapIndex then
		highestCompletedAct = partyProgress.actNumber - 1 -- actNumber is next accessible
	end
	
	for actNum = 1, #map.Acts do
		local isUnlocked = actNum <= maxAct
		table.insert(allActs, {
			ActNumber = actNum,
			IsUnlocked = isUnlocked,
			IsCompleted = actNum <= highestCompletedAct,
			ActInfo = map.Acts[actNum],
			MapImageId = map.ImageId
		})
	end
	
	return allActs
end

GetPartyActsFunction.OnServerInvoke = function(player, mapId)
	local players = PartyService.GetPlayersInSameParty(player)
	if #players == 0 then
		-- Solo player - return their normal available acts
		return MapProgressService.GetAvailableActs(player, mapId)
	end
	return PartyService.GetAvailableActsForParty(players, mapId)
end

-- Start the service
startPlayBoxLoop() -- Check for players leaving bounds
PartyService.SetupAllTpPartTriggers() -- Setup TpPart touch entry for ALL PlayBoxes
print("[PartyService] Initialized - Multi-PlayBox party system active (max " .. MAX_PARTY_SIZE .. " players per box)")

return PartyService
