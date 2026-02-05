--[[
	PartyController.client.lua
	Client-side controller for the PlayBox party system.
	Displays party UI when player is in the PlayBox and handles party teleportation.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Remote Functions/Events
local functions = ReplicatedStorage:WaitForChild("Functions")
local events = ReplicatedStorage:WaitForChild("Events")

local GetPartyInfoFunction = functions:WaitForChild("GetPartyInfo")
local TeleportPartyFunction = functions:WaitForChild("TeleportParty")
local LeavePartyFunction = functions:WaitForChild("LeaveParty")
local PartyUpdatedEvent = events:WaitForChild("PartyUpdated")

local PartyController = {}

-- State
local partyUI = nil
local isInPlayBox = false
local currentPartyInfo = nil

--------------------------------------------------------------------------------
-- UI SETUP
--------------------------------------------------------------------------------

-- Get the pre-existing PartyUI from StarterGui (now in PlayerGui)
local function getPartyUI()
	return playerGui:WaitForChild("PartyUI", 5)
end

--------------------------------------------------------------------------------
-- UI UPDATE
--------------------------------------------------------------------------------

local function createMemberEntry(memberData, index)
	local entry = Instance.new("Frame")
	entry.Name = "Member_" .. memberData.UserId
	entry.Size = UDim2.new(1, 0, 0, 22)
	entry.BackgroundTransparency = 1
	entry.LayoutOrder = index
	
	-- Player name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(0.6, 0, 1, 0)
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.Gotham
	nameLabel.TextSize = 13
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = entry
	
	-- Build name text with indicators
	local nameText = memberData.DisplayName
	local indicators = {}
	
	if memberData.IsHost then
		table.insert(indicators, "👑")
	end
	if memberData.IsLimiting then
		table.insert(indicators, "⚠️")
	end
	if memberData.UserId == player.UserId then
		table.insert(indicators, "(You)")
	end
	
	if #indicators > 0 then
		nameText = nameText .. " " .. table.concat(indicators, " ")
	end
	nameLabel.Text = nameText
	
	-- Set color based on status
	if memberData.IsHost and memberData.UserId == player.UserId then
		nameLabel.TextColor3 = Color3.fromRGB(255, 215, 0) -- Gold for host (you)
	elseif memberData.IsHost then
		nameLabel.TextColor3 = Color3.fromRGB(255, 200, 100) -- Orange for host
	elseif memberData.IsLimiting then
		nameLabel.TextColor3 = Color3.fromRGB(255, 150, 100) -- Red-orange for limiting
	elseif memberData.UserId == player.UserId then
		nameLabel.TextColor3 = Color3.fromRGB(100, 200, 255) -- Blue for you
	else
		nameLabel.TextColor3 = Color3.fromRGB(200, 200, 200) -- Gray for others
	end
	
	-- Progress indicator
	local progressLabel = Instance.new("TextLabel")
	progressLabel.Name = "Progress"
	progressLabel.Size = UDim2.new(0.4, 0, 1, 0)
	progressLabel.Position = UDim2.new(0.6, 0, 0, 0)
	progressLabel.BackgroundTransparency = 1
	progressLabel.Font = Enum.Font.Gotham
	progressLabel.TextSize = 11
	progressLabel.TextColor3 = Color3.fromRGB(120, 120, 120)
	progressLabel.TextXAlignment = Enum.TextXAlignment.Right
	progressLabel.Text = memberData.MaxMapName .. " A" .. memberData.MaxActNumber
	progressLabel.Parent = entry
	
	return entry
end

local function updatePartyUI(partyInfo)
	if not partyUI then return end
	
	local mainFrame = partyUI:FindFirstChild("PartyFrame")
	if not mainFrame then return end
	
	local statusLabel = mainFrame:FindFirstChild("StatusLabel")
	local membersFrame = mainFrame:FindFirstChild("MembersFrame")
	local progressWarning = mainFrame:FindFirstChild("ProgressWarning")
	local maxProgressLabel = mainFrame:FindFirstChild("MaxProgressLabel")
	local leaveButton = partyUI:FindFirstChild("LeaveButton", true)
	
	-- Clear existing members
	for _, child in ipairs(membersFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	
	-- Handle error messages (e.g., PlayBox full)
	if partyInfo and partyInfo.error then
		-- Show error notification briefly
		local errorGui = playerGui:FindFirstChild("LobbyGui")
		if errorGui then
			local errorMsg = errorGui:FindFirstChild("ErrorMessage")
			if errorMsg then
				errorMsg.Text = partyInfo.error
				errorMsg.Visible = true
				task.delay(3, function()
					errorMsg.Visible = false
				end)
			end
		end
		return
	end
	
	if not partyInfo or (not partyInfo.inParty and not partyInfo.soloInBox) then
		mainFrame.Visible = false
		isInPlayBox = false
		-- Hide leave button when not in party
		if leaveButton then
			leaveButton.Visible = false
		end
		return
	end
	
	isInPlayBox = true
	mainFrame.Visible = true
	
	-- Show leave button when in party
	if leaveButton then
		leaveButton.Visible = true
	end
	
	-- Update status with player count / max capacity
	local maxCapacity = partyInfo.maxCapacity or 4
	if partyInfo.inParty then
		statusLabel.Text = "Party: " .. partyInfo.memberCount .. "/" .. maxCapacity .. " players"
		statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
	else
		statusLabel.Text = "In PlayBox (1/" .. maxCapacity .. ") - Waiting..."
		statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	end
	
	-- Add member entries
	local canvasHeight = 0
	for i, member in ipairs(partyInfo.members) do
		local entry = createMemberEntry(member, i)
		entry.Parent = membersFrame
		canvasHeight = canvasHeight + 27
	end
	membersFrame.CanvasSize = UDim2.new(0, 0, 0, canvasHeight)
	
	-- Update progress restriction warning
	if partyInfo.limitingPlayer and partyInfo.inParty then
		progressWarning.Visible = true
		if partyInfo.limitingPlayer.UserId == player.UserId then
			progressWarning.Text = "You are limiting party progress"
		else
			progressWarning.Text = partyInfo.limitingPlayer.DisplayName .. " is limiting party progress"
		end
	else
		progressWarning.Visible = false
	end
	
	-- Update max progress label
	if partyInfo.partyProgress then
		maxProgressLabel.Text = "Max: " .. partyInfo.partyProgress.mapName .. ", Act " .. partyInfo.partyProgress.actNumber
	else
		maxProgressLabel.Text = "Max: Map 1, Act 1"
	end
	
	-- Adjust frame size based on content
	local frameHeight = 120 + math.min(canvasHeight, 80) + (progressWarning.Visible and 40 or 0)
	mainFrame.Size = UDim2.new(0, 300, 0, frameHeight)
end

--------------------------------------------------------------------------------
-- PARTY ACTIONS
--------------------------------------------------------------------------------

function PartyController.TeleportParty(mapId, selectedAct)
	if not isInPlayBox then
		warn("PartyController: Not in PlayBox, cannot teleport party")
		return false, "You must be in the PlayBox to teleport with a party"
	end
	
	local success, error = TeleportPartyFunction:InvokeServer(mapId, selectedAct)
	return success, error
end

function PartyController.LeaveParty()
	if not isInPlayBox then
		warn("PartyController: Not in PlayBox, cannot leave party")
		return false, "You are not in a party"
	end
	
	local success, error = LeavePartyFunction:InvokeServer()
	return success, error
end

function PartyController.GetPartyInfo()
	return currentPartyInfo
end

function PartyController.IsInParty()
	return currentPartyInfo and currentPartyInfo.inParty
end

function PartyController.IsInPlayBox()
	return isInPlayBox
end

function PartyController.IsHost()
	return currentPartyInfo and currentPartyInfo.isHost
end

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

local function initialize()
	-- Get the pre-existing UI from StarterGui
	partyUI = getPartyUI()
	
	if not partyUI then
		warn("PartyController: PartyUI not found in PlayerGui! Make sure it exists in StarterGui.")
		return
	end
	
	print("PartyController: Found PartyUI in PlayerGui")
	
	-- Connect Leave button if it exists
	local leaveButton = partyUI:FindFirstChild("LeaveButton", true)
	if leaveButton then
		leaveButton.Activated:Connect(function()
			print("PartyController: Leave button clicked")
			local success, err = PartyController.LeaveParty()
			if not success then
				warn("PartyController: Failed to leave party:", err)
			end
		end)
		print("PartyController: Connected LeaveButton")
	else
		warn("PartyController: LeaveButton not found in PartyUI")
	end
	
	-- Listen for party updates from server
	PartyUpdatedEvent.OnClientEvent:Connect(function(partyInfo)
		currentPartyInfo = partyInfo
		updatePartyUI(partyInfo)
	end)
	
	-- Poll for party info periodically (backup in case events are missed)
	task.spawn(function()
		while true do
			task.wait(2)
			local partyInfo = GetPartyInfoFunction:InvokeServer()
			currentPartyInfo = partyInfo
			updatePartyUI(partyInfo)
		end
	end)
	
	-- Initial fetch
	task.spawn(function()
		task.wait(1) -- Wait for server to be ready
		local partyInfo = GetPartyInfoFunction:InvokeServer()
		currentPartyInfo = partyInfo
		updatePartyUI(partyInfo)
	end)
	
	print("PartyController: Initialized")
end

initialize()

return PartyController
