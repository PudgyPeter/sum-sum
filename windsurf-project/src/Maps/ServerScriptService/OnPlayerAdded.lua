local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PlayerDataManager"))
local DataStoreManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("DataStoreManager"))

local function setupPlayer(player)
	-- Skip if already set up
	if player:FindFirstChild("Cash") then return end
	
	print("[PlayerData] Loading data for", player.Name)
	
	-- Setup player data (loads from DataStore and creates PlayerData folder)
	PlayerDataManager.SetupPlayer(player)
	
	-- Set up game-specific values
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 5000000
	cash.Parent = player
	
	local placedTowers = Instance.new("IntValue")
	placedTowers.Name = "PlacedTowers"
	placedTowers.Value = 0
	placedTowers.Parent = player
	
	player.CharacterAdded:Connect(function(character)
		for i, object in ipairs(character:GetDescendants()) do
			if object:IsA("BasePart") then
				object.CollisionGroup = "Player"
			end
		end
	end)
end

Players.PlayerAdded:Connect(setupPlayer)

-- Handle players who joined before this script ran (race condition fix)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		setupPlayer(player)
	end)
end