local Players = game:GetService("Players")
local player = Players.LocalPlayer
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local ServerScriptService = game:GetService("ServerScriptService")
local LOBBY_PLACE_ID = 110673592671083

local modules = ReplicatedStorage:WaitForChild("Modules")
local health = require(modules:WaitForChild("Health"))
local GameSpeed = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GameSpeed"))
local TowerData = require(modules:WaitForChild("TowerData"))
local ColorTypeSystem = require(modules:WaitForChild("ColorTypeSystem"))
local TagSystem = require(modules:WaitForChild("TagSystem"))

local cash = Players.LocalPlayer:WaitForChild("Cash")
local functions = ReplicatedStorage:WaitForChild("Functions")
local requestTowerFunction = functions:WaitForChild("RequestTower")
local sellTowerFunction = functions:WaitForChild("SellTower")
local changeTowerPriorityFunction = functions:WaitForChild("ChangeTowerPriority")
local towers = ReplicatedStorage:WaitForChild("Towers")
local spawnTowerFunction = functions:WaitForChild("SpawnTower")
local upgradeTowerFunction = functions:WaitForChild("UpgradeTower")
local getUpgradeCostFunction = functions:WaitForChild("GetUpgradeCost")
local upgradeToParagonFunction = functions:WaitForChild("UpgradeToParagon")
local getUpgradeStatsFunction = functions:WaitForChild("GetUpgradeStats")
local getParagonDataFunction = functions:WaitForChild("GetParagonData")
local getPathColorFunction = functions:WaitForChild("GetPathColor")

local camera = workspace.CurrentCamera
local viewportFrame = script.Parent.UpgradeUi.Portrait.ViewportFrame
local viewportCam = Instance.new("Camera")
viewportFrame.CurrentCamera = viewportCam
viewportCam.Parent = viewportFrame
local gui = script.Parent

local map = workspace:WaitForChild("RockMap")
local base = map:WaitForChild("Base")
local info = workspace:WaitForChild("Info")

local hoveredInstance = nil
local selectedTower = nil
local towerToSpawn = nil
local canPlace = false
local rotation = 0
local placedTowerCounts = {}
	local maxWave = 15
local placementInProgress = false
local lastTouch = tick()

local characterClone

local playerLoadout = {false, false, false, false, false, false} -- Initialize all 6 slots

local playerData = player:WaitForChild("PlayerData", 5)
if playerData then
	local loadoutFolder = playerData:FindFirstChild("Loadout")
	if loadoutFolder then
		print("[GameController] Found Loadout folder with", #loadoutFolder:GetChildren(), "children")
		for _, tower in ipairs(loadoutFolder:GetChildren()) do
			print("[GameController] Found child:", tower.Name, "IsStringValue:", tower:IsA("StringValue"))
			if tower:IsA("StringValue") then
				-- Extract slot number from name (e.g., "Slot_3" -> 3)
				local slotNumber = tonumber(tower.Name:match("Slot_(%d+)"))
				print("[GameController] Extracted slotNumber:", slotNumber, "from", tower.Name, "value:", tower.Value)
				if slotNumber and slotNumber >= 1 and slotNumber <= 6 then
					playerLoadout[slotNumber] = tower.Value
					print("[GameController] Set playerLoadout[" .. slotNumber .. "] =", tower.Value)
				end
			end
		end
	else
		print("[GameController] No Loadout folder found in PlayerData")
	end
else
	print("[GameController] No PlayerData found for player")
end

-- Debug: Print final loadout
print("[GameController] Final playerLoadout:")
for i = 1, 6 do
	print("  Slot", i, "=", playerLoadout[i])
end

local function UpdateTowerCounts()
	placedTowerCounts = {}

	for _, tower in ipairs(workspace.Towers:GetChildren()) do
		if tower:IsA("Model") and tower:FindFirstChild("Config") then
			local owner = tower.Config:FindFirstChild("Owner")
			if owner and owner.Value == player.Name then
				local originalType = tower.Config:FindFirstChild("OriginalTowerType")
				local towerName = originalType and originalType.Value or tower.Name
				placedTowerCounts[towerName] = (placedTowerCounts[towerName] or 0) + 1
			end
		end
	end

	local loadoutFrame = gui:FindFirstChild("LoadoutFrame")
	if loadoutFrame then
		for _, slot in ipairs(loadoutFrame:GetChildren()) do
			if (slot:IsA("Frame") or slot:IsA("ImageButton")) and slot.Name ~= "Template" then
				local nameLabel = slot:FindFirstChild("Name")
				if nameLabel then
					local towerName = nameLabel.Text
					local count = placedTowerCounts[towerName] or 0

					local towerModel = towers:FindFirstChild(towerName)
					local maxCount = 10
					if towerModel then
						local config = towerModel:FindFirstChild("Config")
						if config then
							local maxPlacements = config:FindFirstChild("MaxPlacements")
							if maxPlacements and maxPlacements:IsA("NumberValue") then
								maxCount = maxPlacements.Value
							end
						end
					end

					local countLabel = slot:FindFirstChild("Count")
					if countLabel then
						countLabel.Text = count .. "/" .. maxCount
					end
				end
			end
		end
	end
end

local isShowingMaxLimitWarning = false

local function CreateUpgradeFlash(tower)
	if not tower then return end

	if tower.Parent ~= workspace.Towers then return end

	local auraFolder = Instance.new("Folder")
	auraFolder.Name = "UpgradeAura"
	auraFolder.Parent = tower

	for _, part in ipairs(tower:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 1 and part.Name ~= "Range" then
			local aura = Instance.new("Part")
			aura.Name = "AuraPart"
			aura.Size = part.Size * 1.15
			aura.CFrame = part.CFrame
			aura.Shape = part.Shape
			aura.Anchored = true
			aura.CanCollide = false
			aura.CanQuery = false
			aura.Material = Enum.Material.Neon
			aura.Color = Color3.fromRGB(0, 255, 100)
			aura.Transparency = 0.5
			aura.Parent = auraFolder

			local connection
			connection = game:GetService("RunService").RenderStepped:Connect(function()
				if aura and aura.Parent and part and part.Parent then
					aura.CFrame = part.CFrame
				else
					if connection then connection:Disconnect() end
				end
			end)

			local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local fadeTween = TweenService:Create(aura, tweenInfo, {Transparency = 1})
			fadeTween:Play()

			fadeTween.Completed:Connect(function()
				if connection then connection:Disconnect() end
				aura:Destroy()
			end)
		end
	end

	task.delay(0.6, function()
		auraFolder:Destroy()
	end)
end

local function ShowMaxLimitWarning()
	if isShowingMaxLimitWarning then return end
	isShowingMaxLimitWarning = true

	local maxLimitFrame = gui:FindFirstChild("MaxLimit")
	if not maxLimitFrame then 
		isShowingMaxLimitWarning = false
		return 
	end

	local textLabel = maxLimitFrame:FindFirstChild("MaxLimitL")
	if not textLabel then 
		isShowingMaxLimitWarning = false
		return 
	end

	textLabel.TextTransparency = 0
	textLabel.TextStrokeTransparency = 0.5

	maxLimitFrame.Visible = true

	local originalRotation = maxLimitFrame.Rotation

	local shakeDuration = 0.04
	local shakeAngle = 8

	local rotateRight = TweenService:Create(maxLimitFrame, 
		TweenInfo.new(shakeDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Rotation = originalRotation + shakeAngle}
	)
	rotateRight:Play()
	rotateRight.Completed:Wait()

	-- Back to center
	local backToCenter1 = TweenService:Create(maxLimitFrame,
		TweenInfo.new(shakeDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{Rotation = originalRotation}
	)
	backToCenter1:Play()
	backToCenter1.Completed:Wait()

	local rotateLeft = TweenService:Create(maxLimitFrame,
		TweenInfo.new(shakeDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Rotation = originalRotation - shakeAngle}
	)
	rotateLeft:Play()
	rotateLeft.Completed:Wait()

	local backToCenter2 = TweenService:Create(maxLimitFrame,
		TweenInfo.new(shakeDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{Rotation = originalRotation}
	)
	backToCenter2:Play()
	backToCenter2.Completed:Wait()

	task.wait(1.5)

	local fadeOutInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local textFadeOut = TweenService:Create(textLabel, fadeOutInfo, {
		TextTransparency = 1,
		TextStrokeTransparency = 1
	})
	textFadeOut:Play()
	textFadeOut.Completed:Wait()

	maxLimitFrame.Visible = false

	isShowingMaxLimitWarning = false
end

health.Setup(base, gui.HealthBar)

local totalKills = 0
local totalDamage = 0
local startTime = tick()
local initialCash = cash.Value
local totalCashEarned = 0

local function FormatNumber(num)
	if num >= 1000000 then
		return string.format("%.1fM", num / 1000000)
	elseif num >= 1000 then
		return string.format("%.0fK", num / 1000)
	else
		return tostring(num)
	end
end

local function FormatTime(seconds)
	local minutes = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)
	return string.format("%02d:%02d", minutes, secs)
end

local function ShowVictory()
	if gameEnded then return end
	gameEnded = true

	local victoryFrame = gui:FindFirstChild("Victory")
	if not victoryFrame then 
		warn("Victory frame not found in GUI!")
		return 
	end

	local frame = victoryFrame:FindFirstChild("Frame")
	if not frame then 
		return 
	end


	-- Calculate play time
	local playTime = tick() - startTime

	local stats = frame:FindFirstChild("Stats")
	if stats then
		local totalDamageLabel = stats:FindFirstChild("TotalDamage")
		if totalDamageLabel then
			local damageText = totalDamageLabel:FindFirstChild("TotalDamage")
			if damageText then
				damageText.Text = FormatNumber(totalDamage)
			end
		end

		local totalKillsLabel = stats:FindFirstChild("TotalKills")
		if totalKillsLabel then
			local killsText = totalKillsLabel:FindFirstChild("TotalKills")
			if killsText then
				killsText.Text = FormatNumber(totalKills)
			end
		end

		local moneyEarnedLabel = stats:FindFirstChild("MoneyEarned")
		if moneyEarnedLabel then
			local moneyText = moneyEarnedLabel:FindFirstChild("MoneyEarned")
			if moneyText then
				moneyText.Text = "$" .. FormatNumber(totalCashEarned)
			end
		end

		local playTimeLabel = stats:FindFirstChild("PlayTime")
		if playTimeLabel then
			local timeText = playTimeLabel:FindFirstChild("PlayTime")
			if timeText then
				timeText.Text = FormatTime(playTime)
			end
		end
	end

	local rewardsFrame = frame:FindFirstChild("Rewards")
	if rewardsFrame then
		local rewardsContainer = rewardsFrame:FindFirstChild("RewardsFrame")
		local template = rewardsContainer and rewardsContainer:FindFirstChild("RewardsTemplate")

		if rewardsContainer and template then
			for _, child in ipairs(rewardsContainer:GetChildren()) do
				if child ~= template and not child:IsA("UIListLayout") then
					child:Destroy()
				end
			end

			local UpgradeData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("TowerUpgradeData"))
			if UpgradeData and UpgradeData.Rewards then
				print("Victory: Creating reward displays from template...")
				for itemName, itemData in pairs(UpgradeData.Rewards) do

					local rewardSlot = template:Clone()
					rewardSlot.Name = itemName
					rewardSlot.Visible = true

					local imageLabel = rewardSlot:FindFirstChild("ImageLabel")
					if imageLabel then
						imageLabel.Image = itemData.imageId
					else
						warn("Victory: ImageLabel not found in template")
					end

					local amountLabel = rewardSlot:FindFirstChild("Amount")
					if amountLabel then
						amountLabel.Text = "+" .. tostring(itemData.amountPerWin)
					else
						warn("Victory: Amount label not found in template")
					end

					local nameLabel = rewardSlot:FindFirstChild("Name")
					if nameLabel then
						nameLabel.Text = itemData.name
					else
						warn("Victory: Name label not found in template")
					end

					rewardSlot.Parent = rewardsContainer
				end
			else
				warn("UpgradeData.Rewards not found!")
			end
		else
			warn("Victory: RewardsFrame or RewardsTemplate not found!")
			if not rewardsContainer then
				warn("Victory: RewardsFrame is missing")
			end
			if not template then
				warn("Victory: RewardsTemplate is missing - please create it in Victory.Frame.Rewards.RewardsFrame")
			end
		end
	else
		warn("Victory: Rewards frame not found in Victory.Frame!")
	end

	victoryFrame.Visible = true

	local AwardVictoryRewardsEvent = ReplicatedStorage.Events:WaitForChild("AwardVictoryRewards")
	AwardVictoryRewardsEvent:FireServer()

	-- Setup Return button
	local returnButton = frame:FindFirstChild("Return")
	if returnButton then
		returnButton.Activated:Connect(function()
			-- Teleport back to lobby
			TeleportService:Teleport(LOBBY_PLACE_ID, player)
		end)
	end

	-- Setup Retry button
	local retryButton = frame:FindFirstChild("Retry")
	if retryButton then
		retryButton.Activated:Connect(function()
			-- Request game reset from server
			local ResetGameFunction = ReplicatedStorage.Functions:WaitForChild("ResetGame")
			local success = ResetGameFunction:InvokeServer()
			if success then
				victoryFrame.Visible = false
				gameEnded = false
				totalKills = 0
				totalDamage = 0
				totalCashEarned = 0
				startTime = tick()

				-- Show StartGame button again
				if gui.StartGame then
					gui.StartGame.Visible = true
				end
			end
		end)
	end

	-- Setup Next button for act progression
	local nextButton = frame:FindFirstChild("Next")
	if nextButton then
		nextButton.Activated:Connect(function()
			-- Request next act from server
			local NextActEvent = ReplicatedStorage.Events:WaitForChild("NextAct")
			NextActEvent:FireServer()
			
			-- Hide victory frame and reset for next act
			victoryFrame.Visible = false
			gameEnded = false
			
			-- Reset act-specific stats but keep towers
			totalKills = 0
			totalDamage = 0
			totalCashEarned = 0
			
			-- Show StartGame button for next act
			if gui.StartGame then
				gui.StartGame.Visible = true
			end
		end)
	end
end

local function UpdateStats()
	local enemiesAlive = #workspace.Mobs:GetChildren()

	if gui.Stats then
		local aliveEnemies = gui.Stats:FindFirstChild("AliveEnemies")
		if aliveEnemies then
			local aliveCount = aliveEnemies:FindFirstChild("AliveCount")
			if aliveCount then
				aliveCount.Text = "Enemies Alive: " .. enemiesAlive
			end
		end

		local totalKillsFrame = gui.Stats:FindFirstChild("TotalKills")
		if totalKillsFrame then
			local killCount = totalKillsFrame:FindFirstChild("KillCount")
			if killCount then
				killCount.Text = "Total Kills: " .. totalKills
			end
		end

		local totalCashFrame = gui.Stats:FindFirstChild("TotalCash")
		if totalCashFrame then
			local cashCount = totalCashFrame:FindFirstChild("CashCount")
			if cashCount then
				cashCount.Text = "Total Cash: $" .. FormatNumber(totalCashEarned)
			end
		end
	end
end

local function SetGui()
	gui.Message.Visible = true
	gui.HealthBar.Visible = true
	gui.Waves.Visible = true

	if gui.Stats then
		gui.Stats.Visible = true
	end

	-- Show StartGame button initially
	if gui.StartGame then
		gui.StartGame.Visible = true

		-- Setup StartGame button
		gui.StartGame.Activated:Connect(function()
			gui.StartGame.Visible = false

			local StartGameEvent = ReplicatedStorage.Events:WaitForChild("StartGame")
			StartGameEvent:FireServer()
		end)
	end

	workspace.Mobs.ChildAdded:Connect(function(mob)
		health.Setup(mob)
		UpdateStats()
	end)

	-- Listen for act completion from server
	local ActCompleteEvent = ReplicatedStorage.Events:WaitForChild("ActComplete")
	ActCompleteEvent.OnClientEvent:Connect(function()
		if not gameEnded then
			task.wait(0.5) -- Brief delay for mobs to finish clearing
			if not gameEnded then
				ShowVictory()
			end
		end
	end)

	workspace.Mobs.ChildRemoved:Connect(function(mob)
		-- Update enemies alive count
		UpdateStats()

		-- Check if act is complete
		local GetActInfoFunction = ReplicatedStorage.Functions:WaitForChild("GetActInfo")
		local actInfo = GetActInfoFunction:InvokeServer()
		if actInfo and actInfo.IsComplete and #workspace.Mobs:GetChildren() == 0 and not gameEnded then
			task.wait(0.5)
			if not gameEnded then
				ShowVictory()
			end
		end
	end)

	-- Track per-player kills from server
	local PlayerKillEvent = ReplicatedStorage.Events:WaitForChild("PlayerKill")
	PlayerKillEvent.OnClientEvent:Connect(function()
		totalKills = totalKills + 1
		UpdateStats()
	end)

	-- Track per-player damage from server
	local PlayerDamageEvent = ReplicatedStorage.Events:WaitForChild("PlayerDamage")
	PlayerDamageEvent.OnClientEvent:Connect(function(damageAmount)
		totalDamage = totalDamage + damageAmount
	end)

	info.Message.Changed:Connect(function(change)
		gui.Message.Text = change
		if change == "" then
			gui.Message.Visible = false
		else
			gui.Message.Visible = true
		end
	end)

	-- Setup SkipWave button if it exists
	local skipWaveButton = gui:FindFirstChild("SkipWave")
	print("[SKIP WAVE DEBUG] Button found:", skipWaveButton ~= nil)

	if skipWaveButton then
		-- Hide initially
		skipWaveButton.Visible = false
		print("[SKIP WAVE DEBUG] Button hidden initially")

		-- Track current wave timer
		local skipButtonTimer = nil

		skipWaveButton.Activated:Connect(function()
			print("[SKIP WAVE DEBUG] Button clicked!")
			local SkipWaveFunction = ReplicatedStorage.Functions:WaitForChild("SkipWave")
			print("[SKIP WAVE DEBUG] Calling server SkipWave function...")
			local success = SkipWaveFunction:InvokeServer()

			if success then
				print("[SKIP WAVE DEBUG] Wave skipped successfully")
				skipWaveButton.Visible = false
				if skipButtonTimer then
					task.cancel(skipButtonTimer)
					skipButtonTimer = nil
				end
			else
				warn("[SKIP WAVE DEBUG] Failed to skip wave")
			end
		end)

		-- Show skip button 15 seconds after wave starts
		info.Wave.Changed:Connect(function(wave)
			print("[GameController] Wave changed to:", wave)
			
			-- Wave is now relative (1-15 within each act)
			-- Get act info for display
			local GetActInfoFunction = ReplicatedStorage.Functions:WaitForChild("GetActInfo")
			local stateInfo = GetActInfoFunction:InvokeServer()
			
			local wavesPerAct = stateInfo and stateInfo.WavesPerAct or 15
			local currentAct = stateInfo and stateInfo.CurrentAct or 1
			
			-- Update wave display (wave is already relative 1-15)
			if wave > 0 then
				gui.Waves.Text = "Wave " .. wave .. "/" .. wavesPerAct
			else
				gui.Waves.Text = "Wave 0/" .. wavesPerAct
			end

			-- Cancel any existing timer
			if skipButtonTimer then
				task.cancel(skipButtonTimer)
				skipButtonTimer = nil
			end

			-- Hide button when wave changes
			skipWaveButton.Visible = false

			-- Skip button logic - can't skip final wave
			local canSkip = wave > 0 and wave < wavesPerAct
			
			if canSkip then
				print("[GameController] Starting skip timer for wave", wave)
				skipButtonTimer = task.delay(15, function()
					local mobCount = #workspace.Mobs:GetChildren()
					if mobCount > 0 then
						skipWaveButton.Visible = true
					end
					skipButtonTimer = nil
				end)
			end
		end)

		-- Hide button when all mobs are cleared
		workspace.Mobs.ChildRemoved:Connect(function()
			local mobCount = #workspace.Mobs:GetChildren()
			print("[SKIP WAVE DEBUG] Mob removed. Remaining mobs:", mobCount)
			if mobCount == 0 then
				skipWaveButton.Visible = false
				print("[SKIP WAVE DEBUG] All mobs cleared, button hidden")
				if skipButtonTimer then
					task.cancel(skipButtonTimer)
					skipButtonTimer = nil
					print("[SKIP WAVE DEBUG] Timer cancelled")
				end
			end
		end)
	else
		print("[GameController] No SkipWave button found in GUI")
		-- If no skip button, just update wave text
		info.Wave.Changed:Connect(function(wave)
			local GetActInfoFunction = ReplicatedStorage.Functions:WaitForChild("GetActInfo")
			local stateInfo = GetActInfoFunction:InvokeServer()
			local wavesPerAct = stateInfo and stateInfo.WavesPerAct or 15
			
			if wave > 0 then
				gui.Waves.Text = "Wave " .. wave .. "/" .. wavesPerAct
			else
				gui.Waves.Text = "Wave 0/" .. wavesPerAct
			end
		end)
	end

	-- Setup Speed Toggle button
	local speedButton = gui:FindFirstChild("SpeedToggle")
	if speedButton then
		-- Initialize button text
		speedButton.Speed.Text = "Speed: 1x"
		speedButton.Visible = true

		speedButton.Activated:Connect(function()
			local ToggleSpeedFunction = ReplicatedStorage.Functions:WaitForChild("ToggleSpeed")
			local newSpeed = ToggleSpeedFunction:InvokeServer()

			if newSpeed then
				GameSpeed.SetSpeed(newSpeed)
				speedButton.Speed.Text = "Speed: " .. newSpeed .. "x"
				print("[SPEED] Game speed changed to", newSpeed .. "x")
			end
		end)

		-- Listen for speed changes from server (in case other players change it)
		local SpeedChangedEvent = ReplicatedStorage.Events:WaitForChild("SpeedChanged")
		SpeedChangedEvent.OnClientEvent:Connect(function(newSpeed)
			GameSpeed.SetSpeed(newSpeed)
			speedButton.Speed.Text = "Speed: " .. newSpeed .. "x"
			print("[SPEED] Game speed synchronized to", newSpeed .. "x")
		end)
	else
		print("[SPEED] No SpeedToggle button found in GUI")
	end
end
SetGui()

local lastCashValue = cash.Value

local function CreateCashPopup(amount)
	if amount == 0 then return end

	local popup = Instance.new("TextLabel")
	popup.Size = UDim2.new(0, 150, 0, 40)
	popup.Position = gui.Cash.Position + UDim2.new(0, 0, -0.05, 0) -- Start slightly above cash label
	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.BackgroundTransparency = 1
	popup.TextColor3 = amount > 0 and Color3.new(0, 1, 0) or Color3.new(1, 0, 0) -- Green for gain, red for loss
	popup.TextStrokeTransparency = 0.5
	popup.TextScaled = true
	popup.Font = Enum.Font.FredokaOne
	popup.Text = (amount > 0 and "+" or "") .. "$" .. math.floor(amount)
	popup.ZIndex = 10
	popup.Parent = gui

	-- Animate: float up and fade out
	local tweenInfo = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local goal = {Position = popup.Position + UDim2.new(0, 0, -0.1, 0)}
	local tween = TweenService:Create(popup, tweenInfo, goal)

	local fadeTweenInfo = TweenInfo.new(0.8, Enum.EasingStyle.Linear)
	local fadeGoal = {TextTransparency = 1, TextStrokeTransparency = 1}
	local fadeTween = TweenService:Create(popup, fadeTweenInfo, fadeGoal)

	tween:Play()
	fadeTween:Play()

	-- Destroy after animation
	task.delay(0.8, function()
		popup:Destroy()
	end)
end

local function UpdateGold()
	gui.Cash.Visible = true
	gui.Cash.Text = "$" .. cash.Value

	-- Show popup for cash change
	local cashChange = cash.Value - lastCashValue
	if cashChange ~= 0 then
		CreateCashPopup(cashChange)
		-- Track total cash earned (only positive changes)
		if cashChange > 0 then
			totalCashEarned = totalCashEarned + cashChange
			UpdateStats()
		end
	end
	lastCashValue = cash.Value
end
UpdateGold()
cash.Changed:Connect(UpdateGold)


local function MouseRaycast(blacklist)
	local mousePosition = UserInputService:GetMouseLocation()
	local mouseRay = camera:ViewportPointToRay(mousePosition.X, mousePosition.Y)
	local raycastParams = RaycastParams.new()

	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = blacklist

	local raycastResult = workspace:Raycast(mouseRay.Origin, mouseRay.Direction * 1000, raycastParams)

	return raycastResult
end

-- Client-side line-of-sight check (mirrors server logic)
local function HasLineOfSight(tower, target)
	if not tower or not target then return false end

	local towerRoot = tower:FindFirstChild("HumanoidRootPart")
	local targetRoot = target:FindFirstChild("HumanoidRootPart")

	if not towerRoot or not targetRoot then return false end

	-- Create raycast from tower to target
	local origin = towerRoot.Position
	local direction = (targetRoot.Position - origin)

	-- Raycast parameters
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {tower, target, workspace.Mobs, workspace.Towers}
	raycastParams.IgnoreWater = true

	-- Perform raycast
	local raycastResult = workspace:Raycast(origin, direction, raycastParams)

	-- If raycast hit something, there's an obstacle
	if raycastResult then
		return false
	end

	return true
end

-- Create wedge part for blocked area visualization
local function CreateWedge(tower, startAngle, endAngle, range)
	local height = (tower.PrimaryPart.Size.Y / 2) + tower["Torso"].Size.Y
	local offset = CFrame.new(0, -height, 0)

	-- Calculate the angular span
	local angleSpan = endAngle - startAngle
	local midAngle = startAngle + (angleSpan / 2)

	-- Create wedge using WedgePart
	local wedge = Instance.new("WedgePart")
	wedge.Name = "BlockedWedge"
	wedge.Material = Enum.Material.Neon
	wedge.Color = Color3.fromRGB(255, 50, 50)
	wedge.Transparency = 0.6
	wedge.Anchored = true
	wedge.CanCollide = false
	wedge.CanQuery = false

	-- Size the wedge based on angle span and range
	local wedgeDepth = range
	local wedgeWidth = 2 * range * math.sin(angleSpan / 2)
	wedge.Size = Vector3.new(0.3, wedgeWidth, wedgeDepth)

	-- Position and rotate the wedge
	local towerCFrame = tower.PrimaryPart.CFrame * offset
	local wedgeOffset = CFrame.new(0, 0, -wedgeDepth / 2)
	wedge.CFrame = towerCFrame * CFrame.Angles(0, midAngle, 0) * wedgeOffset * CFrame.Angles(0, math.rad(90), 0)

	return wedge
end

-- Track last tower position for movement optimization
local lastTowerPos = nil
local lastUpdateTime = 0
local UPDATE_INTERVAL = 0.1 -- Update every 100ms max

-- Create visual indicators for blocked line-of-sight using wedges
local function CreateLineOfSightIndicators(tower)
	-- Movement optimization: skip if tower hasn't moved much
	local currentPos = tower.PrimaryPart.Position
	local currentTime = tick()

	if lastTowerPos and (currentPos - lastTowerPos).Magnitude < 1 and (currentTime - lastUpdateTime) < UPDATE_INTERVAL then
		return -- Skip update - tower barely moved
	end

	lastTowerPos = currentPos
	lastUpdateTime = currentTime

	-- Remove existing indicators
	local existingIndicators = workspace.Camera:FindFirstChild("LOSIndicators")
	if existingIndicators then
		existingIndicators:Destroy()
	end

	local indicatorsFolder = Instance.new("Folder")
	indicatorsFolder.Name = "LOSIndicators"
	indicatorsFolder.Parent = workspace.Camera

	local range = tower.Config.Range.Value
	local towerPos = tower.HumanoidRootPart.Position
	local towerCFrame = tower.HumanoidRootPart.CFrame

	-- Use tower center height for raycasting (not ground level)
	local rayOrigin = Vector3.new(towerPos.X, towerPos.Y + 3, towerPos.Z)

	-- Build raycast params once
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local excludeList = {tower, workspace.Mobs, workspace.Towers, workspace.Camera}
	for _, player in ipairs(game.Players:GetPlayers()) do
		if player.Character then
			table.insert(excludeList, player.Character)
		end
	end
	if workspace:FindFirstChild("Baseplate") then
		table.insert(excludeList, workspace.Baseplate)
	end
	if workspace:FindFirstChild("Map") then
		if workspace.Map:FindFirstChild("Floor") then
			table.insert(excludeList, workspace.Map.Floor)
		end
		if workspace.Map:FindFirstChild("Walls") then
			table.insert(excludeList, workspace.Map.Walls)
		end
	end
	raycastParams.FilterDescendantsInstances = excludeList
	raycastParams.IgnoreWater = true

	-- Height offset for visualization
	local height = (tower.PrimaryPart.Size.Y / 2) + tower["Torso"].Size.Y
	local visualY = towerPos.Y - height + 0.2

	-- Adaptive sampling: fewer samples when tower is far from obstacles
	local numSamples = 360
	local sampleStep = 1 -- Default: sample every degree

	-- Reduce sampling if range is large (distant obstacles need less detail)
	if range > 50 then
		sampleStep = 2 -- Sample every 2 degrees
		numSamples = 180
	elseif range > 100 then
		sampleStep = 3 -- Sample every 3 degrees  
		numSamples = 120
	end

	for i = 0, numSamples - 1 do
		local angle = (i * sampleStep / 360) * math.pi * 2
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))

		-- Optimization: only raycast to reasonable distance
		local maxRayDistance = math.min(range, 150) -- Cap at 150 studs
		local raycastResult = workspace:Raycast(rayOrigin, direction * maxRayDistance, raycastParams)

		if raycastResult then
			-- Hit something - create shadow from hit point to range edge
			local hitDistance = raycastResult.Distance
			local shadowLength = range - hitDistance

			if shadowLength > 0.5 then -- Only show if there's meaningful shadow
				local blockedPart = Instance.new("Part")
				blockedPart.Name = "BlockedArea"
				blockedPart.Material = Enum.Material.Neon
				blockedPart.Color = Color3.fromRGB(255, 50, 50)
				blockedPart.Transparency = 0.5
				blockedPart.Anchored = true
				blockedPart.CanCollide = false
				blockedPart.CanQuery = false
				blockedPart.Shape = Enum.PartType.Block

				-- Width based on 1 degree arc at the hit distance
				local arcWidth = hitDistance * math.rad(1)
				blockedPart.Size = Vector3.new(arcWidth, 0.3, shadowLength)

				-- Position: start from hit point, extend to range edge
				local hitPoint2D = Vector3.new(
					towerPos.X + direction.X * hitDistance,
					visualY,
					towerPos.Z + direction.Z * hitDistance
				)
				local centerPos = hitPoint2D + direction * (shadowLength / 2)

				blockedPart.CFrame = CFrame.lookAt(centerPos, centerPos + direction)
				blockedPart.Parent = indicatorsFolder
			end
		end
	end
end

local function CreateRangeCircle(tower, placeholder)
	local range = tower.Config.Range.Value
	local height = (tower.PrimaryPart.Size.Y / 2) + tower["Torso"].Size.Y
	local offset = CFrame.new(0, -height, 0)

	local p = Instance.new("Part")
	p.Name = "Range"
	p.Shape = Enum.PartType.Cylinder
	p.Material = Enum.Material.Neon
	p.Transparency = 0.9
	p.Color = Color3.new(0.333333, 0.666667, 1)
	p.Size = Vector3.new(0.3, range * 2, range * 2)
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = tower.PrimaryPart.CFrame * offset * CFrame.Angles(0, 0, math.rad(90))
	p.CanCollide = false
	p.CanQuery = false

	if placeholder then
		p.Anchored = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = p
		weld.Part1 = tower.PrimaryPart
		weld.Parent = p
		p.Parent = tower

		-- Create LOS indicators for placement preview (will be updated in placement loop)
		CreateLineOfSightIndicators(tower)
	else
		p.Anchored = true
		p.Parent = workspace.Camera

		-- Create line-of-sight indicators when showing range
		CreateLineOfSightIndicators(tower)
	end
end

local function CreateRangePreview(tower, upgradeRange)
	-- Remove existing preview
	local existingPreview = workspace.Camera:FindFirstChild("RangePreview")
	if existingPreview then
		existingPreview:Destroy()
	end

	-- Hide the current blue range circle
	local currentRange = workspace.Camera:FindFirstChild("Range")
	if currentRange then
		currentRange.Transparency = 1
	end

	local height = (tower.PrimaryPart.Size.Y / 2) + tower["Torso"].Size.Y
	local offset = CFrame.new(0, -height, 0)

	local p = Instance.new("Part")
	p.Name = "RangePreview"
	p.Shape = Enum.PartType.Cylinder
	p.Material = Enum.Material.Neon
	p.Transparency = 0.85
	p.Color = Color3.new(0, 1, 0) -- Green for upgrade preview
	p.Size = Vector3.new(0.3, upgradeRange * 2, upgradeRange * 2)
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = tower.PrimaryPart.CFrame * offset * CFrame.Angles(0, 0, math.rad(90))
	p.CanCollide = false
	p.CanQuery = false
	p.Anchored = true
	p.Parent = workspace.Camera
end

local function RemoveRangePreview()
	local existingPreview = workspace.Camera:FindFirstChild("RangePreview")
	if existingPreview then
		existingPreview:Destroy()
	end

	-- Restore the current blue range circle
	local currentRange = workspace.Camera:FindFirstChild("Range")
	if currentRange then
		currentRange.Transparency = 0.9
	end
end

local placementGrid = nil

local function CreatePlacementGrid()
	-- Remove existing grid if any
	if placementGrid then
		placementGrid:Destroy()
	end

	-- Find the TowerArea
	local towerArea = map:FindFirstChild("TowerArea")
	if not towerArea then return end

	-- Create a folder to hold grid lines
	placementGrid = Instance.new("Folder")
	placementGrid.Name = "PlacementGrid"
	placementGrid.Parent = workspace

	-- Calculate bounds from TowerArea children
	local minX, minY, minZ = math.huge, math.huge, math.huge
	local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge

	for _, part in ipairs(towerArea:GetDescendants()) do
		if part:IsA("BasePart") then
			local pos = part.Position
			local size = part.Size
			minX = math.min(minX, pos.X - size.X/2)
			minY = math.min(minY, pos.Y - size.Y/2)
			minZ = math.min(minZ, pos.Z - size.Z/2)
			maxX = math.max(maxX, pos.X + size.X/2)
			maxY = math.max(maxY, pos.Y + size.Y/2)
			maxZ = math.max(maxZ, pos.Z + size.Z/2)
		end
	end

	-- Use exact path rotation: -53 degrees on Y axis
	local rotationY = math.rad(-53)

	local centerX = (minX + maxX) / 2
	local centerY = (minY + maxY) / 2
	local centerZ = (minZ + maxZ) / 2
	local sizeX = maxX - minX
	local sizeZ = maxZ - minZ

	local gridSize = 2 -- 1 stud grid spacing
	local yPos = maxY + 0.1 -- Slightly above surface

	-- Create center CFrame with rotation
	local centerCF = CFrame.new(centerX, yPos, centerZ) * CFrame.Angles(0, rotationY, 0)

	-- Calculate how many lines we need in each direction
	-- Use diagonal size to ensure full coverage when rotated
	local diagonalSize = math.sqrt(sizeX * sizeX + sizeZ * sizeZ)
	local numLinesX = math.ceil(diagonalSize / gridSize)
	local numLinesZ = math.ceil(diagonalSize / gridSize)

	-- Create vertical lines (along local Z axis)
	for i = -numLinesX, numLinesX do
		local offsetX = i * gridSize
		local lineCF = centerCF * CFrame.new(offsetX, 0, 0)

		local line = Instance.new("Part")
		line.Name = "GridLine"
		line.Size = Vector3.new(0.1, 0.1, diagonalSize)
		line.CFrame = lineCF
		line.Anchored = true
		line.CanCollide = false
		line.CanQuery = false
		line.Transparency = 0.95
		line.Color = Color3.new(1, 1, 1)
		line.Material = Enum.Material.Neon
		line.Parent = placementGrid
	end

	-- Create horizontal lines (along local X axis)
	for i = -numLinesZ, numLinesZ do
		local offsetZ = i * gridSize
		local lineCF = centerCF * CFrame.new(0, 0, offsetZ) * CFrame.Angles(0, math.rad(90), 0)

		local line = Instance.new("Part")
		line.Name = "GridLine"
		line.Size = Vector3.new(0.1, 0.1, diagonalSize)
		line.CFrame = lineCF
		line.Anchored = true
		line.CanCollide = false
		line.CanQuery = false
		line.Transparency = 0.95
		line.Color = Color3.new(1, 1, 1)
		line.Material = Enum.Material.Neon
		line.Parent = placementGrid
	end
end

local function RemovePlacementGrid()
	if placementGrid then
		placementGrid:Destroy()
		placementGrid = nil
	end
end

local function RemovePlaceholderTower()
	if towerToSpawn then
		towerToSpawn:Destroy()
		towerToSpawn = nil
		rotation = 0
		gui.Cancel.Visible = false
	end
	RemovePlacementGrid()
end

local function AddPlaceholderTower(name)
	local towerExists = towers:FindFirstChild(name)
	if towerExists then
		RemovePlaceholderTower()
		towerToSpawn = towerExists:Clone()
		towerToSpawn.Parent = workspace
		placementInProgress = true
		CreateRangeCircle(towerToSpawn, true)
		CreatePlacementGrid() -- Show grid during placement

		for i, object in ipairs(towerToSpawn:GetDescendants()) do
			if object:IsA("BasePart") then
				object.CollisionGroup = "Tower"
				if object.Name ~= "Range" then
					object.Transparency = 0.5
				end
			end
		end
		if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
			gui.Cancel.Visible = true
		else
			gui.Cancel.Visible = false
		end
	end
end

local towerSlots = {}

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end

	if input.KeyCode == Enum.KeyCode.X and placementInProgress == true then
		RemovePlaceholderTower()
		return
	end

	-- Number keys 1-6 for tower selection
	local hotkeyMap = {
		[Enum.KeyCode.One] = 1,
		[Enum.KeyCode.Two] = 2,
		[Enum.KeyCode.Three] = 3,
		[Enum.KeyCode.Four] = 4,
		[Enum.KeyCode.Five] = 5,
		[Enum.KeyCode.Six] = 6,
	}

	local slotNumber = hotkeyMap[input.KeyCode]
	if slotNumber and towerSlots[slotNumber] then
		local slot = towerSlots[slotNumber]

		-- Only trigger if it's a filled tower slot (not empty)
		if slot:GetAttribute("TowerName") then
			-- Simulate clicking the slot
			local towerName = slot:GetAttribute("TowerName")
			local towerConfig = slot:GetAttribute("TowerConfig")
			local maxCount = slot:GetAttribute("MaxCount") or 10

			-- Check if tower type is at limit
			local count = placedTowerCounts[towerName] or 0

			if count >= maxCount then
				-- Show max limit warning
				ShowMaxLimitWarning()
			else
				local allowedToSpawn = requestTowerFunction:InvokeServer(towerName)
				if allowedToSpawn then
					AddPlaceholderTower(towerName)

					-- Visual feedback - flash the slot
					local originalTransparency = slot.BackgroundTransparency
					slot.BackgroundTransparency = 0.3
					task.wait(0.1)
					slot.BackgroundTransparency = originalTransparency
				end
			end
		end
	end
end)

local function ColorPlaceholderTower(color)
	for i, object in ipairs(towerToSpawn:GetDescendants()) do
		if object:IsA("BasePart") then
			object.Color = color
		end
	end			
end

workspace.Towers.ChildAdded:Connect(UpdateTowerCounts)
workspace.Towers.ChildRemoved:Connect(UpdateTowerCounts)


local loadoutFrame = gui:FindFirstChild("LoadoutFrame")
if not loadoutFrame then
	warn("GameController: LoadoutFrame not found - please copy LoadoutFrame from lobby")
	return
end

local template = loadoutFrame:FindFirstChild("Template")
if not template then
	warn("GameController: Template not found in LoadoutFrame")
	return
end

local emptyTemplate = loadoutFrame:FindFirstChild("EmptyTemplate")
if not emptyTemplate then
	warn("GameController: EmptyTemplate not found in LoadoutFrame")
	return
end

for _, child in ipairs(loadoutFrame:GetChildren()) do
	if (child:IsA("Frame") or child:IsA("ImageButton")) and child.Name ~= "Template" and child.Name ~= "EmptyTemplate" then
		child:Destroy()
	end
end

local filledSlots = 0
for i = 1, 6 do
	if playerLoadout[i] then
		local instanceId = playerLoadout[i]
		local towerModel = nil
		local modelName = nil
		
		-- Look up unit instance to get the actual tower ID
		local unitInstances = playerData and playerData:FindFirstChild("UnitInstances")
		if unitInstances then
			local unitInstance = unitInstances:FindFirstChild(instanceId)
			if unitInstance then
				local unitId = unitInstance:GetAttribute("UnitId")
				if unitId then
					-- Get tower data to find the model name
					local towerInfo = TowerData.GetTowerById(unitId)
					if towerInfo then
						modelName = towerInfo.ModelName or towerInfo.Name
					end
				end
			end
		end
		
		-- Find tower model using the resolved model name
		if modelName then
			towerModel = towers:FindFirstChild(modelName)
		end
		
		-- Fallback: try treating the loadout value as a direct tower name (legacy support)
		if not towerModel then
			local baseTowerName = instanceId:match("^([^_]+)")
			towerModel = towers:FindFirstChild(baseTowerName) or towers:FindFirstChild(instanceId)
			
			if not towerModel then
				for _, tower in pairs(towers:GetChildren()) do
					if tower:IsA("Model") and tower.Name:find("^" .. baseTowerName) then
						towerModel = tower
						break
					end
				end
			end
		end

		if towerModel then
			local config = towerModel:WaitForChild("Config")
			filledSlots = filledSlots + 1
			local slot = template:Clone()
			slot.Name = "Slot" .. i
			slot.Visible = true
			slot.LayoutOrder = i

			local nameLabel = slot:FindFirstChild("Cost")
			if nameLabel then
				nameLabel.Text = "$" .. config.Price.Value
			end

			-- Update price label if it exists
			local priceLabel = slot:FindFirstChild("Price")
			if priceLabel then
				priceLabel.Text = "$" .. config.Price.Value
			end

			-- Load tower model with animation (matching lobby)
			local viewportFrame = slot:FindFirstChild("ViewportFrame")
			if viewportFrame then
				-- Create WorldModel
				local worldModel = viewportFrame:FindFirstChild("WorldModel")
				if not worldModel then
					worldModel = Instance.new("WorldModel")
					worldModel.Parent = viewportFrame
				else
					worldModel:ClearAllChildren()
				end

				-- Clone the tower model we already found
				if towerModel then
					towerModel.Archivable = true
					for _, obj in ipairs(towerModel:GetDescendants()) do
						obj.Archivable = true
					end

					local modelClone = towerModel:Clone()

					-- Remove scripts
					for _, obj in ipairs(modelClone:GetDescendants()) do
						if obj:IsA("Script") or obj:IsA("LocalScript") then
							obj:Destroy()
						end
					end

					modelClone.Parent = worldModel

					-- Setup camera
					local camera = Instance.new("Camera")
					camera.Parent = viewportFrame
					viewportFrame.CurrentCamera = camera

					if modelClone.PrimaryPart then
						local position = modelClone.PrimaryPart.Position
						modelClone:SetPrimaryPartCFrame(CFrame.new(position) * CFrame.Angles(0, math.rad(180), 0))
						camera.CFrame = CFrame.new(position + Vector3.new(0, 1, 2), position + Vector3.new(0, 1, 0))
					end

					-- Add animation (matching lobby)
					local humanoid = modelClone:FindFirstChild("Humanoid")
					if humanoid then
						local animator = humanoid:FindFirstChildOfClass("Animator")
						if not animator then
							animator = Instance.new("Animator")
							animator.Parent = humanoid
						end

						local animation = Instance.new("Animation")
						animation.AnimationId = "rbxassetid://180435571"

						local animTrack = animator:LoadAnimation(animation)
						animTrack.Looped = true
						animTrack:Play()
					end
				end
			end

			-- Get max placement from tower Config
			local maxCount = 10 -- Default fallback
			local maxPlacements = config:FindFirstChild("MaxPlacements")
			if maxPlacements and maxPlacements:IsA("NumberValue") then
				maxCount = maxPlacements.Value
			end

			-- Set attributes for hotkey access
			slot:SetAttribute("TowerName", towerModel.Name)
			slot:SetAttribute("MaxCount", maxCount)

			-- Store slot reference for hotkeys
			towerSlots[i] = slot

			-- Click to select tower for placement
			slot.Activated:Connect(function()
				-- Check if tower type is at limit
				local count = placedTowerCounts[towerModel.Name] or 0

				if count >= maxCount then
					-- Show max limit warning
					ShowMaxLimitWarning()
				else
					local allowedToSpawn = requestTowerFunction:InvokeServer(towerModel.Name)
					if allowedToSpawn then
						AddPlaceholderTower(towerModel.Name)
					end
				end
			end)

			slot.Parent = loadoutFrame
		else
			warn("GameController: Could not find tower model for loadout entry:", playerLoadout[i])
		end
	else
	end
end


local function loadTowerModel(viewportFrame, towerModelName)
	local worldModel = viewportFrame:FindFirstChild("WorldModel")
	if not worldModel then
		worldModel = Instance.new("WorldModel")
		worldModel.Parent = viewportFrame
	else
		worldModel:ClearAllChildren()
	end

	local towersFolder = game:GetService("ReplicatedStorage"):FindFirstChild("Towers")
	if not towersFolder then return end

	local towerModel = towersFolder:FindFirstChild(towerModelName)
	if not towerModel then return end

	towerModel.Archivable = true
	for _, obj in ipairs(towerModel:GetDescendants()) do
		obj.Archivable = true
	end

	local modelClone = towerModel:Clone()

	-- Remove scripts
	for _, obj in ipairs(modelClone:GetDescendants()) do
		if obj:IsA("Script") or obj:IsA("LocalScript") then
			obj:Destroy()
		end
	end

	modelClone.Parent = worldModel

	-- Setup camera
	local camera = viewportFrame:FindFirstChild("Camera")
	if not camera then
		camera = Instance.new("Camera")
		camera.Parent = viewportFrame
		viewportFrame.CurrentCamera = camera
	end

	if modelClone.PrimaryPart then
		local position = modelClone.PrimaryPart.Position
		modelClone:SetPrimaryPartCFrame(CFrame.new(position) * CFrame.Angles(0, math.rad(180), 0))
		camera.CFrame = CFrame.new(position + Vector3.new(0, 1, 2), position + Vector3.new(0, 1, 0))
	end
end

for i = 1, 6 do
	if not playerLoadout[i] then
		local emptySlot = emptyTemplate:Clone()
		emptySlot.Name = "EmptySlot" .. i
		emptySlot.Visible = true
		emptySlot.LayoutOrder = i

		local nameLabel = emptySlot:FindFirstChild("Name")
		if nameLabel then
			nameLabel.Text = "Empty"
			nameLabel.TextColor3 = Color3.new(0.5, 0.5, 0.5)
		end

		local priceLabel = emptySlot:FindFirstChild("Price")
		if priceLabel then
			priceLabel.Text = ""
		end

		-- Parent slot first so cycling coroutine can check slot.Parent
		emptySlot.Parent = loadoutFrame

		-- Setup cycling silhouette animation (matching lobby)
		local viewportFrame = emptySlot:FindFirstChild("ViewportFrame")
		if viewportFrame then
			-- Get all tower models for cycling
			local allTowers = {}
			local towersFolder = game:GetService("ReplicatedStorage"):FindFirstChild("Towers")
			if towersFolder then
				for _, tower in ipairs(towersFolder:GetChildren()) do
					if tower:IsA("Model") then
						table.insert(allTowers, tower.Name)
					end
				end
			end

			if #allTowers > 0 then
				-- Load initial random tower
				local initialTower = allTowers[math.random(1, #allTowers)]
				loadTowerModel(viewportFrame, initialTower)

				-- Cycle through random towers every 3 seconds
				task.spawn(function()
					while emptySlot and emptySlot.Parent do
						task.wait(3)
						if emptySlot and emptySlot.Parent then
							-- Pick a completely random tower each time
							local randomTower = allTowers[math.random(1, #allTowers)]
							loadTowerModel(viewportFrame, randomTower)
						else
							break
						end
					end
				end)
			end
		end

	end
end

loadoutFrame.Visible = true

UpdateTowerCounts()

-- Function to add a tower slot dynamically when loadout changes
local function AddTowerSlotFromLoadout(slotValue)
	if not slotValue:IsA("StringValue") then return end
	
	local slotNumber = tonumber(slotValue.Name:match("Slot_(%d+)"))
	if not slotNumber or slotNumber < 1 or slotNumber > 6 then return end
	
	local towerName = slotValue.Value
	if not towerName or towerName == "" then return end
	
	-- Remove existing slot at this position (empty or filled)
	local existingSlot = loadoutFrame:FindFirstChild("Slot" .. slotNumber)
	if existingSlot then existingSlot:Destroy() end
	local existingEmpty = loadoutFrame:FindFirstChild("EmptySlot" .. slotNumber)
	if existingEmpty then existingEmpty:Destroy() end
	
	-- Find tower model
	local towerModel = towers:FindFirstChild(towerName)
	if not towerModel then
		warn("[GameController] Tower model not found:", towerName)
		return
	end
	
	local config = towerModel:FindFirstChild("Config")
	if not config then return end
	
	-- Update playerLoadout table
	playerLoadout[slotNumber] = towerName
	
	-- Create slot from template
	local slot = template:Clone()
	slot.Name = "Slot" .. slotNumber
	slot.Visible = true
	slot.LayoutOrder = slotNumber
	
	local costLabel = slot:FindFirstChild("Cost")
	if costLabel then
		costLabel.Text = "$" .. config.Price.Value
	end
	
	local priceLabel = slot:FindFirstChild("Price")
	if priceLabel then
		priceLabel.Text = "$" .. config.Price.Value
	end
	
	-- Setup viewport
	local viewportFrame = slot:FindFirstChild("ViewportFrame")
	if viewportFrame then
		local worldModel = viewportFrame:FindFirstChild("WorldModel")
		if not worldModel then
			worldModel = Instance.new("WorldModel")
			worldModel.Parent = viewportFrame
		else
			worldModel:ClearAllChildren()
		end
		
		towerModel.Archivable = true
		for _, obj in ipairs(towerModel:GetDescendants()) do
			obj.Archivable = true
		end
		
		local modelClone = towerModel:Clone()
		for _, obj in ipairs(modelClone:GetDescendants()) do
			if obj:IsA("Script") or obj:IsA("LocalScript") then
				obj:Destroy()
			end
		end
		modelClone.Parent = worldModel
		
		local camera = Instance.new("Camera")
		camera.Parent = viewportFrame
		viewportFrame.CurrentCamera = camera
		
		if modelClone.PrimaryPart then
			local position = modelClone.PrimaryPart.Position
			modelClone:SetPrimaryPartCFrame(CFrame.new(position) * CFrame.Angles(0, math.rad(180), 0))
			camera.CFrame = CFrame.new(position + Vector3.new(0, 1, 2), position + Vector3.new(0, 1, 0))
		end
		
		local humanoid = modelClone:FindFirstChild("Humanoid")
		if humanoid then
			local animator = humanoid:FindFirstChildOfClass("Animator")
			if not animator then
				animator = Instance.new("Animator")
				animator.Parent = humanoid
			end
			local animation = Instance.new("Animation")
			animation.AnimationId = "rbxassetid://180435571"
			local animTrack = animator:LoadAnimation(animation)
			animTrack.Looped = true
			animTrack:Play()
		end
	end
	
	-- Get max placement
	local maxCount = 10
	local maxPlacements = config:FindFirstChild("MaxPlacements")
	if maxPlacements and maxPlacements:IsA("NumberValue") then
		maxCount = maxPlacements.Value
	end
	
	slot:SetAttribute("TowerName", towerModel.Name)
	slot:SetAttribute("MaxCount", maxCount)
	towerSlots[slotNumber] = slot
	
	slot.Activated:Connect(function()
		local count = placedTowerCounts[towerModel.Name] or 0
		if count >= maxCount then
			ShowMaxLimitWarning()
		else
			local allowedToSpawn = requestTowerFunction:InvokeServer(towerModel.Name)
			if allowedToSpawn then
				AddPlaceholderTower(towerModel.Name)
			end
		end
	end)
	
	slot.Parent = loadoutFrame
	print("[GameController] Added tower slot:", towerName, "to slot", slotNumber)
	UpdateTowerCounts()
end

-- Listen for loadout changes (e.g., from ModMenu)
local loadoutFolder = playerData and playerData:FindFirstChild("Loadout")
if loadoutFolder then
	loadoutFolder.ChildAdded:Connect(AddTowerSlotFromLoadout)
end

local characterClone
local worldModel

local function updatePortrait(tower)
	if characterClone then
		characterClone:Destroy()
	end

	if not worldModel then
		worldModel = Instance.new("WorldModel")
		worldModel.Parent = viewportFrame
	else
		worldModel:ClearAllChildren()
	end

	if not tower then 
		gui.UpgradeUi.Visible = false
		return 
	end

	tower.Archivable = true
	for _, obj in ipairs(tower:GetDescendants()) do
		obj.Archivable = true
	end

	characterClone = tower:Clone()
	if not characterClone then return end

	-- Remove any upgrade aura effects from the clone
	for _, obj in ipairs(characterClone:GetDescendants()) do
		if obj:IsA("LocalScript") or obj:IsA("Script") then
			obj:Destroy()
		elseif obj.Name == "AuraPart" or obj.Name == "UpgradeAura" then
			obj:Destroy()
		end
	end

	characterClone.Parent = worldModel

	-- Reset rotation and position the tower
	if characterClone.PrimaryPart then
		local position = characterClone.PrimaryPart.Position
		characterClone:SetPrimaryPartCFrame(CFrame.new(position) * CFrame.Angles(0, math.rad(180), 0))
		viewportCam.CFrame = CFrame.new(position + Vector3.new(0, 1, 2), position + Vector3.new(0, 1, 0))
	end

	-- Add animation for R6 humanoid
	local cloneHumanoid = characterClone:FindFirstChild("Humanoid")
	if cloneHumanoid then
		local animator = cloneHumanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = cloneHumanoid
		end

		local animation = Instance.new("Animation")
		animation.AnimationId = "rbxassetid://180435571"

		local animationTrack = animator:LoadAnimation(animation)
		animationTrack.Looped = true
		animationTrack:Play()
	end
end

local function showUpgradeStats(towerType, path, currentLevel, currentConfig)
	if not towerType or not path then
		-- Hide upgrade stats
		gui.UpgradeUi.Stats.Damage.UpgradeDamage.Visible = false
		gui.UpgradeUi.Stats.Damage.aro.Visible = false
		gui.UpgradeUi.Stats.Range.UpgradeRange.Visible = false
		gui.UpgradeUi.Stats.Range.aro.Visible = false
		gui.UpgradeUi.Stats.SPA.UpgradeSPA.Visible = false
		gui.UpgradeUi.Stats.SPA.aro.Visible = false

		-- Reset positions to center
		gui.UpgradeUi.Stats.Damage.CurrentDamage.Position = UDim2.new(0.2, 0, 0.157, 0)
		gui.UpgradeUi.Stats.Range.CurrentRange.Position = UDim2.new(0.2, 0, 0.157, 0)
		gui.UpgradeUi.Stats.SPA.CurrentSPA.Position = UDim2.new(0.2, 0, 0.157, 0)
		return
	end

	-- Get upgrade stats from server
	local upgradeStats = getUpgradeStatsFunction:InvokeServer(towerType, path, currentLevel + 1)
	if not upgradeStats then return end

	-- Show upgrade stats UI
	gui.UpgradeUi.Stats.Damage.UpgradeDamage.Visible = true
	gui.UpgradeUi.Stats.Damage.aro.Visible = true
	gui.UpgradeUi.Stats.Range.UpgradeRange.Visible = true
	gui.UpgradeUi.Stats.Range.aro.Visible = true
	gui.UpgradeUi.Stats.SPA.UpgradeSPA.Visible = true
	gui.UpgradeUi.Stats.SPA.aro.Visible = true

	-- Calculate and display upgraded stat values
	local newDamage = currentConfig.Damage.Value + (upgradeStats.damage or 0)
	local newRange = currentConfig.Range.Value + (upgradeStats.range or 0)
	local newSPA = currentConfig.SPA.Value + (upgradeStats.spa or 0)
	-- Cap SPA at minimum 0.2
	if newSPA < 0.2 then
		newSPA = 0.2
	end

	gui.UpgradeUi.Stats.Damage.UpgradeDamage.Text = FormatNumber(newDamage)
	gui.UpgradeUi.Stats.Range.UpgradeRange.Text = FormatNumber(newRange)
	gui.UpgradeUi.Stats.SPA.UpgradeSPA.Text = string.format("%.2f", newSPA) .. "s"

	-- Move current stats to left side
	gui.UpgradeUi.Stats.Damage.CurrentDamage.Position = UDim2.new(0.009, 0,0.2, 0)
	gui.UpgradeUi.Stats.Range.CurrentRange.Position = UDim2.new(0.008, 0, 0.242, 0)
	gui.UpgradeUi.Stats.SPA.CurrentSPA.Position = UDim2.new(0.008, 0, 0.2, 0)
end

local losUpdateConnection = nil

local function toggleTowerInfo()
	workspace.Camera:ClearAllChildren()

	-- Disconnect previous LOS update loop
	if losUpdateConnection then
		losUpdateConnection:Disconnect()
		losUpdateConnection = nil
	end

	if selectedTower then
		CreateRangeCircle(selectedTower)

		-- Start continuous LOS indicator updates
		losUpdateConnection = game:GetService("RunService").Heartbeat:Connect(function()
			if selectedTower and selectedTower.Parent then
				CreateLineOfSightIndicators(selectedTower)
			else
				-- Tower was destroyed or deselected
				if losUpdateConnection then
					losUpdateConnection:Disconnect()
					losUpdateConnection = nil
				end
			end
		end)

		gui.UpgradeUi.Visible = true
		local config = selectedTower.Config
		local dpsValue = FormatNumber(math.floor(config.Damage.Value / config.SPA.Value))
		gui.UpgradeUi.Stats.Damage.CurrentDamage.Text = FormatNumber(config.Damage.Value)
		gui.UpgradeUi.Stats.Range.CurrentRange.Text = FormatNumber(config.Range.Value)
		gui.UpgradeUi.Stats.SPA.CurrentSPA.Text = string.format("%.2f", config.SPA.Value) .. "s"
		gui.UpgradeUi.Portrait.TowerName.Text = selectedTower.Name
		gui.UpgradeUi.DPS.DPS.Text = '<font color="rgb(0, 255, 0)">' .. dpsValue .. '</font>/s'

		local investment = config:FindFirstChild("TotalInvestment")
		if investment then
			gui.UpgradeUi.Sell.SellAmount.Text = "$" .. math.floor(investment.Value * 0.5)
		else
			gui.UpgradeUi.Sell.SellAmount.Text = "$" .. math.floor(config.Price.Value / 2)
		end
		gui.UpgradeUi.Portrait.OwnerName.Text = config.Owner.Value .. "'s"
		gui.UpgradeUi.Priority.PrioritySwitch.Text = config.TargetMode.Value

		-- Function to update tower stats display
		local function updateTowerStats()
			local stats = config:FindFirstChild("Stats")
			if stats then
				local totalDamage = stats:FindFirstChild("TotalDamage")
				local kills = stats:FindFirstChild("Kills")

				-- Update TotalDamage label (just the number)
				local totalDamageFrame = gui.UpgradeUi:FindFirstChild("TotalDamage")
				if totalDamageFrame then
					local totalDamageLabel = totalDamageFrame:FindFirstChild("TotalDamage")
					if totalDamageLabel and totalDamage then
						totalDamageLabel.Text = FormatNumber(math.floor(totalDamage.Value))
					end
				end

				-- Update Kills label (just the number)
				local killsFrame = gui.UpgradeUi:FindFirstChild("Kills")
				if killsFrame then
					local killsLabel = killsFrame:FindFirstChild("ActualKills")
					if killsLabel and kills then
						killsLabel.Text = tostring(kills.Value)
					end
				end
			else
				-- No stats yet, show 0
				local totalDamageFrame = gui.UpgradeUi:FindFirstChild("TotalDamage")
				if totalDamageFrame then
					local totalDamageLabel = totalDamageFrame:FindFirstChild("TotalDamage")
					if totalDamageLabel then
						totalDamageLabel.Text = "0"
					end
				end

				local killsFrame = gui.UpgradeUi:FindFirstChild("Kills")
				if killsFrame then
					local killsLabel = killsFrame:FindFirstChild("ActualKills")
					if killsLabel then
						killsLabel.Text = "0"
					end
				end
			end
		end

		-- Initial update
		updateTowerStats()

		-- Set up real-time updates
		local stats = config:FindFirstChild("Stats")
		if stats then
			local totalDamage = stats:FindFirstChild("TotalDamage")
			local kills = stats:FindFirstChild("Kills")

			if totalDamage then
				totalDamage.Changed:Connect(updateTowerStats)
			end

			if kills then
				kills.Changed:Connect(updateTowerStats)
			end
		end

		updatePortrait(selectedTower)
		showUpgradeStats(nil)

		-- Update Color Type display
		local colorLabel = gui.UpgradeUi:FindFirstChild("Color", true)
		local colorType = config:GetAttribute("ColorType")
		local typeData = colorType and ColorTypeSystem.Types[colorType]
		
		if colorLabel and colorLabel:IsA("ImageLabel") then
			if typeData then
				colorLabel.Image = typeData.ImageId or ""
				colorLabel.ImageColor3 = typeData.Color
				colorLabel.Visible = true
			else
				colorLabel.Visible = false
			end
		end
		
		-- Update UIStroke gradients based on ColorType
		local endColor = Color3.fromHex("#0b0b0c")
		local gradientColor
		if typeData then
			gradientColor = ColorSequence.new({
				ColorSequenceKeypoint.new(0, typeData.Color),
				ColorSequenceKeypoint.new(1, endColor)
			})
		else
			gradientColor = ColorSequence.new({
				ColorSequenceKeypoint.new(0, endColor),
				ColorSequenceKeypoint.new(1, endColor)
			})
		end
		
		-- Apply to Stats.UIStroke.UIGradient
		local statsGradient = gui.UpgradeUi:FindFirstChild("Stats") and gui.UpgradeUi.Stats:FindFirstChild("UIStroke") and gui.UpgradeUi.Stats.UIStroke:FindFirstChild("UIGradient")
		if statsGradient then
			statsGradient.Color = gradientColor
		end
		
		-- Apply to Portrait.UIStroke.UIGradient
		local portraitGradient = gui.UpgradeUi:FindFirstChild("Portrait") and gui.UpgradeUi.Portrait:FindFirstChild("UIStroke") and gui.UpgradeUi.Portrait.UIStroke:FindFirstChild("UIGradient")
		if portraitGradient then
			portraitGradient.Color = gradientColor
		end
		
		-- Apply to UpgradeUi.UIStroke.UIGradient
		local mainGradient = gui.UpgradeUi:FindFirstChild("UIStroke") and gui.UpgradeUi.UIStroke:FindFirstChild("UIGradient")
		if mainGradient then
			mainGradient.Color = gradientColor
		end

		-- Update Tags display with marquee effect
		local tagTemplate = gui.UpgradeUi:FindFirstChild("TagTemplate")
		if tagTemplate then
			local tagLabel = tagTemplate:FindFirstChild("Tag")
			local tagsAttr = config:GetAttribute("Tags")
			
			if tagsAttr and tagLabel then
				local tagList = string.split(tagsAttr, ",")
				if #tagList > 0 then
					tagTemplate.Visible = true
					
					-- Format tags with # prefix and even spacing
					local formattedTags = {}
					for _, tag in ipairs(tagList) do
						local trimmed = string.gsub(tag, "^%s*(.-)%s*$", "%1") -- trim whitespace
						table.insert(formattedTags, "#" .. trimmed)
					end
					
					-- Hide the template label, we'll create individual ones
					tagLabel.Visible = false
					
					-- Clear any existing tag labels
					for _, child in ipairs(tagTemplate:GetChildren()) do
						if child:IsA("TextLabel") and child.Name:match("^TagItem_") then
							child:Destroy()
						end
					end
					
					-- Create separate labels for each tag with staggered positions
					local frameWidth = tagTemplate.AbsoluteSize.X > 0 and tagTemplate.AbsoluteSize.X or 200
					local tagSpacing = 80 -- pixels between tag start positions
					local speed = 80 -- pixels per second
					
					-- Calculate max tag width for consistent cycle timing
					local maxTagWidth = 0
					for _, tagText in ipairs(formattedTags) do
						local w = #tagText * 7
						if w > maxTagWidth then maxTagWidth = w end
					end
					
					-- Use consistent distance for all tags (based on longest tag)
					local totalDistance = frameWidth + maxTagWidth
					local cycleDuration = totalDistance / speed
					
					-- Calculate cumulative delays based on each tag's width
					local cumulativeDelay = 0
					local gapBetweenTags = 40 -- pixels of gap between end of one tag and start of next
					
					-- Calculate total cycle time (all tags use same cycle duration)
					local totalTagsWidth = 0
					for _, tagText in ipairs(formattedTags) do
						totalTagsWidth = totalTagsWidth + (#tagText * 7) + gapBetweenTags
					end
					local fullCycleDuration = (frameWidth + totalTagsWidth) / speed
					
					for i, tagText in ipairs(formattedTags) do
						local label = tagLabel:Clone()
						label.Name = "TagItem_" .. i
						label.Text = tagText
						label.Visible = false -- Start hidden
						label.AutomaticSize = Enum.AutomaticSize.X
						label.Size = UDim2.new(0, 0, 1, 0)
						label.Parent = tagTemplate
						
						local tagWidth = #tagText * 7
						local startPos = -tagWidth -- Start based on own width
						local endPos = frameWidth + tagWidth -- Exit fully off-screen
						local travelDistance = endPos - startPos
						local delay = cumulativeDelay
						
						-- Next tag starts after this tag's width + gap passes the entry point
						cumulativeDelay = cumulativeDelay + (tagWidth + gapBetweenTags) / speed
						
						local function runCycle()
							label.Position = UDim2.new(0, startPos, 0, 0)
							label.Visible = true -- Show when animation starts
							
							-- All tags use same cycle duration for consistent loop
							local tween = TweenService:Create(label, TweenInfo.new(
								fullCycleDuration,
								Enum.EasingStyle.Linear
							), {
								Position = UDim2.new(0, startPos + (fullCycleDuration * speed), 0, 0)
							})
							
							tween.Completed:Connect(runCycle)
							tween:Play()
						end
						
						task.delay(delay, runCycle)
					end
				else
					tagTemplate.Visible = false
				end
			else
				tagTemplate.Visible = false
			end
		end

		if config.Owner.Value == Players.LocalPlayer.Name then
			gui.UpgradeUi.Sell.Visible = true
			gui.UpgradeUi.Priority.Visible = true

			local upgrades = config:FindFirstChild("Upgrades")

			-- Check if tower is already a paragon
			local isParagon = config:FindFirstChild("IsParagon") and config.IsParagon.Value

			if not upgrades then
				gui.UpgradeUi.Upgrade1.Visible = false
				gui.UpgradeUi.Upgrade2.Visible = false
				gui.UpgradeUi.Upgrade3.Visible = false
				-- Hide paragon button if it exists
				if gui.UpgradeUi:FindFirstChild("ParagonButton") then
					gui.UpgradeUi.ParagonButton.Visible = false
				end
			elseif isParagon then
				-- Tower is already paragon, hide all upgrade buttons
				gui.UpgradeUi.Upgrade1.Visible = false
				gui.UpgradeUi.Upgrade2.Visible = false
				gui.UpgradeUi.Upgrade3.Visible = false
				if gui.UpgradeUi:FindFirstChild("ParagonButton") then
					gui.UpgradeUi.ParagonButton.Visible = false
				end
			else
				-- Show upgrade costs and levels
				local towerType = selectedTower.Name
				local primaryPath = config.PrimaryPath.Value

				-- Find which paths have upgrades
				local pathsWithUpgrades = {}
				for _, p in ipairs({"A", "B", "C"}) do
					if upgrades[p] and upgrades[p].Value > 0 then
						table.insert(pathsWithUpgrades, p)
					end
				end

				-- Determine which paths to show
				local secondaryPath = nil
				if primaryPath ~= "" then
					-- Find which path is the secondary (if any)
					for _, p in ipairs({"A", "B", "C"}) do
						if upgrades[p] and p ~= primaryPath and upgrades[p].Value > 0 then
							secondaryPath = p
							break
						end
					end
				end

				-- Path A - only show if tower has this path
				local costA, nameA = nil, nil
				local hidePathA = true

				if upgrades.A then
					costA, nameA = getUpgradeCostFunction:InvokeServer(towerType, "A", upgrades.A.Value + 1)

					-- If cost is nil and level is 0, path doesn't exist in tower data - hide it
					if not costA and upgrades.A.Value == 0 then
						hidePathA = true
					else
						hidePathA = false

						-- Hide Path A if: (1) 2 paths already have upgrades and A doesn't, OR (2) primary+secondary are set and neither is A
						if #pathsWithUpgrades >= 2 and upgrades.A.Value == 0 then
							hidePathA = true
						elseif primaryPath ~= "" and secondaryPath and secondaryPath ~= "A" and primaryPath ~= "A" then
							hidePathA = true
						end
					end
				end

				if hidePathA then
					gui.UpgradeUi.Upgrade1.Visible = false
				else
					gui.UpgradeUi.Upgrade1.Visible = true

					-- Get path color for visual distinction
					local pathColor = getPathColorFunction:InvokeServer(towerType, "A")

					-- Apply path color to border
					local border = gui.UpgradeUi.Upgrade1:FindFirstChild("UIStroke")
					if not border then
						border = Instance.new("UIStroke")
						border.Parent = gui.UpgradeUi.Upgrade1
					end
					border.Color = pathColor
					border.Thickness = 3

					-- Apply path color to gradient
					local gradient = gui.UpgradeUi.Upgrade1:FindFirstChild("UIGradient")
					if gradient then
						gradient.Color = ColorSequence.new{
							ColorSequenceKeypoint.new(0, pathColor),
							ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0))
						}
						gradient.Rotation = 90
					end

					if costA then
						-- Check if path is locked as secondary (at tier 3)
						local isSecondaryLocked = (primaryPath ~= "" and primaryPath ~= "A" and upgrades.A.Value >= 3)

						if isSecondaryLocked then
							-- Show MAX UPGRADE for locked secondary path
							gui.UpgradeUi.Upgrade1.UpgradeName.Text = "Path A (" .. upgrades.A.Value .. "/6)"
							gui.UpgradeUi.Upgrade1.Cost.Text = "MAX UPGRADE"
							gui.UpgradeUi.Upgrade1.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
						else
							gui.UpgradeUi.Upgrade1.UpgradeName.Text = "Path A (" .. upgrades.A.Value .. "/6)"
							gui.UpgradeUi.Upgrade1.Cost.Text = nameA .. " - $" .. FormatNumber(costA)

							-- Check if can upgrade and style button
							if upgrades.A.Value >= 6 or player.Cash.Value < costA then
								gui.UpgradeUi.Upgrade1.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
							else
								gui.UpgradeUi.Upgrade1.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
							end
						end
					else
						gui.UpgradeUi.Upgrade1.UpgradeName.Text = "Path A (6/6)"
						gui.UpgradeUi.Upgrade1.Cost.Text = "MAX UPGRADE"
						gui.UpgradeUi.Upgrade1.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
					end
				end

				-- Path B - only show if tower has this path
				local costB, nameB = nil, nil
				local hidePathB = true

				if upgrades.B then
					costB, nameB = getUpgradeCostFunction:InvokeServer(towerType, "B", upgrades.B.Value + 1)

					-- If cost is nil and level is 0, path doesn't exist in tower data - hide it
					if not costB and upgrades.B.Value == 0 then
						hidePathB = true
					else
						hidePathB = false

						-- Hide Path B if: (1) 2 paths already have upgrades and B doesn't, OR (2) primary+secondary are set and neither is B
						if #pathsWithUpgrades >= 2 and upgrades.B.Value == 0 then
							hidePathB = true
						elseif primaryPath ~= "" and secondaryPath and secondaryPath ~= "B" and primaryPath ~= "B" then
							hidePathB = true
						end
					end
				end

				if hidePathB then
					gui.UpgradeUi.Upgrade2.Visible = false
				else
					gui.UpgradeUi.Upgrade2.Visible = true

					-- Get path color for visual distinction
					local pathColor = getPathColorFunction:InvokeServer(towerType, "B")

					-- Apply path color to border
					local border = gui.UpgradeUi.Upgrade2:FindFirstChild("UIStroke")
					if not border then
						border = Instance.new("UIStroke")
						border.Parent = gui.UpgradeUi.Upgrade2
					end
					border.Color = pathColor
					border.Thickness = 3

					-- Apply path color to gradient
					local gradient = gui.UpgradeUi.Upgrade2:FindFirstChild("UIGradient")
					if gradient then
						gradient.Color = ColorSequence.new{
							ColorSequenceKeypoint.new(0, pathColor),
							ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0))
						}
						gradient.Rotation = 90
					end

					if costB then
						-- Check if path is locked as secondary (at tier 3)
						local isSecondaryLocked = (primaryPath ~= "" and primaryPath ~= "B" and upgrades.B.Value >= 3)

						if isSecondaryLocked then
							-- Show MAX UPGRADE for locked secondary path
							gui.UpgradeUi.Upgrade2.UpgradeName.Text = "Path B (" .. upgrades.B.Value .. "/6)"
							gui.UpgradeUi.Upgrade2.Cost.Text = "MAX UPGRADE"
							gui.UpgradeUi.Upgrade2.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
						else
							gui.UpgradeUi.Upgrade2.UpgradeName.Text = "Path B (" .. upgrades.B.Value .. "/6)"
							gui.UpgradeUi.Upgrade2.Cost.Text = nameB .. " - $" .. FormatNumber(costB)

							if upgrades.B.Value >= 6 or player.Cash.Value < costB then
								gui.UpgradeUi.Upgrade2.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
							else
								gui.UpgradeUi.Upgrade2.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
							end
						end
					else
						gui.UpgradeUi.Upgrade2.UpgradeName.Text = "Path B (6/6)"
						gui.UpgradeUi.Upgrade2.Cost.Text = "MAX UPGRADE"
						gui.UpgradeUi.Upgrade2.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
					end
				end

				-- Path C - only show if tower has this path
				local costC, nameC = nil, nil
				local hidePathC = true

				if upgrades.C then
					costC, nameC = getUpgradeCostFunction:InvokeServer(towerType, "C", upgrades.C.Value + 1)

					-- If cost is nil and level is 0, path doesn't exist in tower data - hide it
					if not costC and upgrades.C.Value == 0 then
						hidePathC = true
					else
						hidePathC = false

						-- Hide Path C if: (1) 2 paths already have upgrades and C doesn't, OR (2) primary+secondary are set and neither is C
						if #pathsWithUpgrades >= 2 and upgrades.C.Value == 0 then
							hidePathC = true
						elseif primaryPath ~= "" and secondaryPath and secondaryPath ~= "C" and primaryPath ~= "C" then
							hidePathC = true
						end
					end
				end

				if hidePathC then
					gui.UpgradeUi.Upgrade3.Visible = false
				else
					gui.UpgradeUi.Upgrade3.Visible = true

					-- Get path color for visual distinction
					local pathColor = getPathColorFunction:InvokeServer(towerType, "C")

					-- Apply path color to border
					local border = gui.UpgradeUi.Upgrade3:FindFirstChild("UIStroke")
					if not border then
						border = Instance.new("UIStroke")
						border.Parent = gui.UpgradeUi.Upgrade3
					end
					border.Color = pathColor
					border.Thickness = 3

					-- Apply path color to gradient
					local gradient = gui.UpgradeUi.Upgrade3:FindFirstChild("UIGradient")
					if gradient then
						gradient.Color = ColorSequence.new{
							ColorSequenceKeypoint.new(0, pathColor),
							ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0))
						}
						gradient.Rotation = 90
					end

					if costC then
						-- Check if path is locked as secondary (at tier 3)
						local isSecondaryLocked = (primaryPath ~= "" and primaryPath ~= "C" and upgrades.C.Value >= 3)

						if isSecondaryLocked then
							-- Show MAX UPGRADE for locked secondary path
							gui.UpgradeUi.Upgrade3.UpgradeName.Text = "Path C (" .. upgrades.C.Value .. "/6)"
							gui.UpgradeUi.Upgrade3.Cost.Text = "MAX UPGRADE"
							gui.UpgradeUi.Upgrade3.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
						else
							gui.UpgradeUi.Upgrade3.UpgradeName.Text = "Path C (" .. upgrades.C.Value .. "/6)"
							gui.UpgradeUi.Upgrade3.Cost.Text = nameC .. " - $" .. FormatNumber(costC)

							if upgrades.C.Value >= 6 or player.Cash.Value < costC then
								gui.UpgradeUi.Upgrade3.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
							else
								gui.UpgradeUi.Upgrade3.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
							end
						end
					else
						gui.UpgradeUi.Upgrade3.UpgradeName.Text = "Path C (6/6)"
						gui.UpgradeUi.Upgrade3.Cost.Text = "MAX UPGRADE"
						gui.UpgradeUi.Upgrade3.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
					end
				end

				-- PARAGON BUTTON - Show big purple button if paragon is available
				local paragonButton = gui.UpgradeUi:FindFirstChild("ParagonButton")
				if paragonButton then
					-- Check if tower can upgrade to paragon
					-- Requirements: one path at 6, another at 3+
					local hasPrimary = false
					local hasSecondary = false
					local primaryPath = nil

					-- Find path at tier 6
					for _, p in ipairs({"A", "B", "C"}) do
						if upgrades[p] and upgrades[p].Value >= 6 then
							hasPrimary = true
							primaryPath = p
							break
						end
					end

					-- Find different path at tier 3+
					if hasPrimary then
						for _, p in ipairs({"A", "B", "C"}) do
							if upgrades[p] and p ~= primaryPath and upgrades[p].Value >= 3 then
								hasSecondary = true
								break
							end
						end
					end

					-- Show button if requirements met
					if hasPrimary and hasSecondary then
						paragonButton.Visible = true
						-- Update cost display if there's a TextLabel
						local costLabel = paragonButton:FindFirstChild("Cost")
						if costLabel then
							costLabel.Text = "$50000" -- You can make this dynamic later
						end
					else
						paragonButton.Visible = false
					end
				end
			end
		else
			gui.UpgradeUi.Sell.Visible = false
			gui.UpgradeUi.Upgrade1.Visible = false
			gui.UpgradeUi.Upgrade2.Visible = false
			gui.UpgradeUi.Upgrade3.Visible = false
			gui.UpgradeUi.Priority.Visible = false
		end
	else
		gui.UpgradeUi.Visible = false
		updatePortrait(nil)
	end
end

-- VFX Framework
local function PlayPlacementVFX(tower)
	if not tower then return end

	local vfxFolder = tower:FindFirstChild("PlacementVFX")
	if not vfxFolder then return end

	for _, obj in ipairs(vfxFolder:GetDescendants()) do
		if obj:IsA("Sound") then
			obj:Play()
		elseif obj:IsA("ParticleEmitter") then
			local emitCount = obj:GetAttribute("EmitCount") or 20
			obj:Emit(emitCount)
		end
	end
end

local function SpawnNewTower()
	if canPlace then
		local placedTower = spawnTowerFunction:InvokeServer(towerToSpawn.Name, towerToSpawn:GetPivot())
		if placedTower then
			-- Wait a frame for tower to replicate
			task.wait()
			PlayPlacementVFX(placedTower)
			RemovePlaceholderTower()
			toggleTowerInfo()
			UpdateTowerCounts()
		end
	end
end

gui.Cancel.CancelButton.Activated:Connect(RemovePlaceholderTower)

gui.UpgradeUi.Priority.PrioritySwitch.Activated:Connect(function()
	if selectedTower then
		local priorityChangeSuccess = changeTowerPriorityFunction:InvokeServer(selectedTower)
		if priorityChangeSuccess then
			toggleTowerInfo()
		end
	end
end)

gui.UpgradeUi.Upgrade1.MouseEnter:Connect(function()
	if selectedTower and selectedTower:FindFirstChild("Config") then
		local config = selectedTower.Config
		local upgrades = config:FindFirstChild("Upgrades")
		if upgrades and upgrades.A then
			showUpgradeStats(selectedTower.Name, "A", upgrades.A.Value, config)

			-- Show range preview if upgrade adds range
			local upgradeStats = getUpgradeStatsFunction:InvokeServer(selectedTower.Name, "A", upgrades.A.Value + 1)
			if upgradeStats and upgradeStats.range ~= 0 then
				local newRange = config.Range.Value + upgradeStats.range
				CreateRangePreview(selectedTower, newRange)
			end
		end
	end
end)

gui.UpgradeUi.Upgrade1.MouseLeave:Connect(function()
	showUpgradeStats(nil)
	RemoveRangePreview()
end)

gui.UpgradeUi.Upgrade1.Button.Activated:Connect(function()
	if selectedTower then
		local success, newTower = upgradeTowerFunction:InvokeServer(selectedTower, "A")
		if success then
			-- Update selectedTower reference if model was swapped
			if newTower then
				selectedTower = newTower
			end
			CreateUpgradeFlash(selectedTower)
			toggleTowerInfo()
		end
	end		
end)

gui.UpgradeUi.Upgrade2.MouseEnter:Connect(function()
	if selectedTower and selectedTower:FindFirstChild("Config") then
		local config = selectedTower.Config
		local upgrades = config:FindFirstChild("Upgrades")
		if upgrades and upgrades.B then
			showUpgradeStats(selectedTower.Name, "B", upgrades.B.Value, config)

			-- Show range preview if upgrade adds range
			local upgradeStats = getUpgradeStatsFunction:InvokeServer(selectedTower.Name, "B", upgrades.B.Value + 1)
			if upgradeStats and upgradeStats.range ~= 0 then
				local newRange = config.Range.Value + upgradeStats.range
				CreateRangePreview(selectedTower, newRange)
			end
		end
	end
end)

gui.UpgradeUi.Upgrade2.MouseLeave:Connect(function()
	showUpgradeStats(nil)
	RemoveRangePreview()
end)

gui.UpgradeUi.Upgrade2.Button.Activated:Connect(function()
	if selectedTower then
		local success, newTower = upgradeTowerFunction:InvokeServer(selectedTower, "B")
		if success then
			-- Update selectedTower reference if model was swapped
			if newTower then
				selectedTower = newTower
			end
			CreateUpgradeFlash(selectedTower)
			toggleTowerInfo()
		end
	end		
end)

gui.UpgradeUi.Upgrade3.MouseEnter:Connect(function()
	if selectedTower and selectedTower:FindFirstChild("Config") then
		local config = selectedTower.Config
		local upgrades = config:FindFirstChild("Upgrades")
		if upgrades and upgrades.C then
			showUpgradeStats(selectedTower.Name, "C", upgrades.C.Value, config)

			-- Show range preview if upgrade adds range
			local upgradeStats = getUpgradeStatsFunction:InvokeServer(selectedTower.Name, "C", upgrades.C.Value + 1)
			if upgradeStats and upgradeStats.range ~= 0 then
				local newRange = config.Range.Value + upgradeStats.range
				CreateRangePreview(selectedTower, newRange)
			end
		end
	end
end)

gui.UpgradeUi.Upgrade3.MouseLeave:Connect(function()
	showUpgradeStats(nil)
	RemoveRangePreview()
end)

gui.UpgradeUi.Upgrade3.Button.Activated:Connect(function()
	if selectedTower then
		local success, newTower = upgradeTowerFunction:InvokeServer(selectedTower, "C")
		if success then
			-- Update selectedTower reference if model was swapped
			if newTower then
				selectedTower = newTower
			end
			CreateUpgradeFlash(selectedTower)
			toggleTowerInfo()
		end
	end		
end)

local paragonButton = gui.UpgradeUi:FindFirstChild("ParagonButton")
if paragonButton then
	paragonButton.MouseEnter:Connect(function()
		if selectedTower and selectedTower:FindFirstChild("Config") then
			local config = selectedTower.Config
			local paragonData = getParagonDataFunction:InvokeServer(selectedTower.Name)
			if paragonData and paragonData.range ~= 0 then
				local newRange = config.Range.Value + paragonData.range
				CreateRangePreview(selectedTower, newRange)
			end
		end
	end)

	-- MouseLeave - remove range preview
	paragonButton.MouseLeave:Connect(function()
		RemoveRangePreview()
	end)

	local upgradeButton = paragonButton:FindFirstChild("UpgradeButton")
	if upgradeButton then
		upgradeButton.Activated:Connect(function()
			if selectedTower then
				local success, newTower = upgradeToParagonFunction:InvokeServer(selectedTower)
				if success then
					-- Update selectedTower reference if model was swapped
					if newTower then
						selectedTower = newTower
					end
					CreateUpgradeFlash(selectedTower)
					toggleTowerInfo()
				else
					warn("Failed to upgrade to paragon")
				end
			end
		end)
	end
end

gui.UpgradeUi.Sell.SellButton.Activated:Connect(function()
	if selectedTower then
		local soldTower = sellTowerFunction:InvokeServer(selectedTower)
		if soldTower then
			selectedTower = nil
			toggleTowerInfo()
			UpdateTowerCounts()
		end
	end
end)

-- Tooltip System: InfoButton, InfoTab, StatsTab, PathsTab navigation
local function hideAllTooltipTabs()
	gui.InfoTab.Visible = false
	gui.StatsTab.Visible = false
	if gui:FindFirstChild("PathsTab") then
		gui.PathsTab.Visible = false
	end
end

local function updateTooltipStats(tower)
	if not tower or not tower.Config then return end

	local config = tower.Config
	local towerType = tower.Name

	-- Get tower data
	local UpgradeData = require(ReplicatedStorage.Modules:WaitForChild("TowerUpgradeData"))
	local towerData = UpgradeData[towerType]

	-- Calculate stats
	local damage = config.Damage.Value
	local range = config.Range.Value
	local spa = config.SPA.Value
	local dps = damage / spa

	-- Crit stats from tower config
	local critChance = config:FindFirstChild("CritChance") and config.CritChance.Value or 0
	local critDamageMultiplier = config:FindFirstChild("CritDamage") and config.CritDamage.Value or 2

	-- Effective DPS (including crit chance)
	local effectiveDPS = dps * (1 + (critChance / 100) * (critDamageMultiplier - 1))

	-- Damage in Range (DiR) = base damage
	local damageInRange = damage

	-- DoT stats from tower config
	local statusType = config:FindFirstChild("StatusType") and config.StatusType.Value or "None"
	local dotType = statusType ~= "None" and statusType or "N/A"
	local dotDamage = "N/A"
	local dotDuration = "N/A"
	local dotDPS = "N/A"

	-- Read DoT stats from StatusEffectConfig if available
	if statusType ~= "None" then
		local statusConfig = config:FindFirstChild("StatusEffectConfig")
		if statusConfig then
			local tickDamage = statusConfig:FindFirstChild("TickDamage")
			local duration = statusConfig:FindFirstChild("Duration")
			local tickRate = statusConfig:FindFirstChild("TickRate")

			if tickDamage then
				dotDamage = tostring(math.floor(tickDamage.Value))
			end

			if duration then
				if duration.Value == math.huge then
					dotDuration = "Permanent"
				else
					dotDuration = tostring(math.floor(duration.Value))
				end
			end

			if tickDamage and duration and tickRate and duration.Value ~= math.huge then
				local totalTicks = duration.Value / tickRate.Value
				local totalDamage = tickDamage.Value * totalTicks
				local dpsValue = totalDamage / duration.Value
				dotDPS = FormatNumber(math.floor(dpsValue))
			elseif tickDamage and tickRate then
				local dpsValue = tickDamage.Value / tickRate.Value
				dotDPS = FormatNumber(math.floor(dpsValue))
			end
		end
	end

	-- Update StatsTab labels
	gui.StatsTab.StatsList1.CritChance.CritChance.Text = string.format("%.1f%%", critChance)
	gui.StatsTab.StatsList1.EffectiveDPS.EffectiveDPS.Text = FormatNumber(math.floor(effectiveDPS))
	gui.StatsTab.StatsList1.DoTType.DoTType.Text = dotType
	gui.StatsTab.StatsList1.DoTDuration.DoTDuration.Text = dotDuration

	-- Format CritDamage as multiplier (e.g., "2x", "2.5x")
	local critDamageText = string.format("%.1fx", critDamageMultiplier)
	if critDamageMultiplier == math.floor(critDamageMultiplier) then
		critDamageText = string.format("%dx", critDamageMultiplier)
	end

	gui.StatsTab.StatsList2.CritDamage.CritDamage.Text = critDamageText
	gui.StatsTab.StatsList2.DamageInRange.DamageInRange.Text = FormatNumber(math.floor(damageInRange))
	gui.StatsTab.StatsList2.DoTDamage.DoTDamage.Text = dotDamage
	gui.StatsTab.StatsList2.DoTDPS.DoTDPS.Text = dotDPS
end

-- InfoButton: Opens InfoTab
local infoButton = gui.UpgradeUi.Info:FindFirstChild("InfoButton")
if infoButton then
	infoButton.Activated:Connect(function()
		if selectedTower then
			local towerType = selectedTower.Name
			local UpgradeData = require(ReplicatedStorage.Modules:WaitForChild("TowerUpgradeData"))
			local towerData = UpgradeData[towerType]

			-- Update info text
			if towerData and towerData.Info then
				gui.InfoTab.Info.Text = towerData.Info
			else
				gui.InfoTab.Info.Text = "No information available for this tower."
			end

			-- Show InfoTab, hide others
			hideAllTooltipTabs()
			gui.InfoTab.Visible = true

			-- Update stats for when user navigates to StatsTab
			updateTooltipStats(selectedTower)
		end
	end)
end

-- InfoArrow: InfoTab -> StatsTab
local infoArrow = gui.InfoTab:FindFirstChild("InfoArrow")
if infoArrow then
	infoArrow.Activated:Connect(function()
		hideAllTooltipTabs()
		gui.StatsTab.Visible = true
	end)
end

-- StatsArrow1: StatsTab -> InfoTab (back)
local statsArrow1 = gui.StatsTab:FindFirstChild("StatsArrow1")
if statsArrow1 then
	statsArrow1.Activated:Connect(function()
		hideAllTooltipTabs()
		gui.InfoTab.Visible = true
	end)
end

-- StatsArrow2: StatsTab -> PathsTab
local statsArrow2 = gui.StatsTab:FindFirstChild("StatsArrow2")
if statsArrow2 then
	statsArrow2.Activated:Connect(function()
		hideAllTooltipTabs()
		if gui:FindFirstChild("PathsTab") then
			gui.PathsTab.Visible = true

			-- Update viewport with tower model
			if selectedTower then
				local pathsViewport = gui.PathsTab:FindFirstChild("ViewportFrame")
				if pathsViewport then
					-- Clear existing models
					pathsViewport:ClearAllChildren()

					-- Create camera for viewport
					local pathsViewportCam = Instance.new("Camera")
					pathsViewport.CurrentCamera = pathsViewportCam
					pathsViewportCam.Parent = pathsViewport

					-- Clone tower model into viewport
					local towerClone = selectedTower:Clone()
					towerClone.Parent = pathsViewport

					-- Position camera to view the tower
					local hrp = towerClone:FindFirstChild("HumanoidRootPart")
					if hrp then
						pathsViewportCam.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 2, 5), hrp.Position)
					end
				end
			end
		end
	end)
end

-- PathArrow: PathsTab -> StatsTab (back)
local pathArrow = gui:FindFirstChild("PathsTab") and gui.PathsTab:FindFirstChild("PathArrow")
if pathArrow then
	pathArrow.Activated:Connect(function()
		hideAllTooltipTabs()
		gui.StatsTab.Visible = true
	end)
end

-- CloseButton handlers for all tooltip tabs
local infoCloseButton = gui.InfoTab:FindFirstChild("CloseButton")
if infoCloseButton then
	infoCloseButton.Activated:Connect(function()
		hideAllTooltipTabs()
	end)
end

local statsCloseButton = gui.StatsTab:FindFirstChild("CloseButton")
if statsCloseButton then
	statsCloseButton.Activated:Connect(function()
		hideAllTooltipTabs()
	end)
end

local pathsCloseButton = gui:FindFirstChild("PathsTab") and gui.PathsTab:FindFirstChild("CloseButton")
if pathsCloseButton then
	pathsCloseButton.Activated:Connect(function()
		hideAllTooltipTabs()
	end)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end

	if towerToSpawn then
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			SpawnNewTower()
		elseif input.UserInputType == Enum.UserInputType.Touch then
			local timeSinceLastTouch = tick() - lastTouch
			if timeSinceLastTouch <= 0.25 then
				SpawnNewTower()
			end
			lastTouch = tick()
		elseif input.keyCode == Enum.KeyCode.R then
			rotation += 90
		end
	elseif hoveredInstance and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		local model = hoveredInstance:FindFirstAncestorOfClass("Model")
		if model and model.Parent == workspace.Towers then
			selectedTower = model
		else
			selectedTower = nil
		end
		toggleTowerInfo()
	end	
end)

RunService.RenderStepped:Connect(function()
	local mousePosition = UserInputService:GetMouseLocation()
	local result = MouseRaycast({towerToSpawn, gui.CursorPrompt})
	if result and result.Instance then
		if towerToSpawn then
			hoveredInstance = nil
			if result.Instance.Parent.Name == "TowerArea" then
				canPlace = true
				ColorPlaceholderTower(Color3.new(0, 1, 0))	
			else 
				canPlace = false
				ColorPlaceholderTower(Color3.new(1,0, 0))		
			end
			local x = result.Position.X
			local y = result.Position.Y + towerToSpawn["Left Leg"].Size.Y + (towerToSpawn.PrimaryPart.Size.Y/2)
			local z = result.Position.Z
			local cframe = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(rotation), 0)
			gui.CursorPrompt.Visible = true
			gui.CursorPrompt.Position = UDim2.new(0, mousePosition.X, 0, mousePosition.Y - gui.CursorPrompt.AbsoluteSize.Y/2)
			towerToSpawn:SetPrimaryPartCFrame(cframe)

			-- Update LOS indicators as tower moves
			CreateLineOfSightIndicators(towerToSpawn)
		else
			hoveredInstance = result.Instance
			gui.CursorPrompt.Visible = false
		end
	else
		hoveredInstance = nil
	end
end)

local events = ReplicatedStorage:WaitForChild("Events")
local DamageIndicatorEvent = events:WaitForChild("DamageIndicator")

local function CreateDamageIndicator(mob, damage, isKillingBlow)
	if not mob or not mob:FindFirstChild("Head") then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(2, 0, 1, 0) -- Scale relative to mob head size
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.MaxDistance = 20 -- Only show within 20 studs
	billboard.AlwaysOnTop = true
	billboard.Adornee = mob.Head
	billboard.Parent = mob

	-- Create TextLabel for damage amount
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = tostring(math.floor(damage))
	-- Red for killing blows, white for normal damage
	textLabel.TextColor3 = isKillingBlow and Color3.new(1, 0, 0) or Color3.new(1, 1, 1)
	textLabel.TextStrokeTransparency = 0.5
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.FredokaOne
	textLabel.Parent = billboard

	-- Animate: float up and fade out
	local tweenInfo = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local goal = {StudsOffset = Vector3.new(0, 5, 0)}
	local tween = TweenService:Create(billboard, tweenInfo, goal)

	local fadeTweenInfo = TweenInfo.new(0.8, Enum.EasingStyle.Linear)
	local fadeGoal = {TextTransparency = 1, TextStrokeTransparency = 1}
	local fadeTween = TweenService:Create(textLabel, fadeTweenInfo, fadeGoal)

	tween:Play()
	fadeTween:Play()

	-- Destroy after animation
	task.delay(0.8, function()
		billboard:Destroy()
	end)
end

DamageIndicatorEvent.OnClientEvent:Connect(function(mob, damage, isKillingBlow)
	CreateDamageIndicator(mob, damage, isKillingBlow)
end)

local gameEnded = false

local function ShowGameOver()
	if gameEnded then return end
	gameEnded = true

	local gameOverFrame = gui:FindFirstChild("GameOverF")
	if not gameOverFrame then 
		warn("GameOverF not found in GUI!")
		return 
	end

	local frame = gameOverFrame:FindFirstChild("Frame")
	if not frame then 
		return 
	end


	-- Calculate play time
	local playTime = tick() - startTime

	-- Update stats
	local stats = frame:FindFirstChild("Stats")
	if stats then
		local totalDamageLabel = stats:FindFirstChild("TotalDamage")
		if totalDamageLabel then
			local damageText = totalDamageLabel:FindFirstChild("TotalDamage")
			if damageText then
				damageText.Text = FormatNumber(totalDamage)
			end
		end

		local totalKillsLabel = stats:FindFirstChild("TotalKills")
		if totalKillsLabel then
			local killsText = totalKillsLabel:FindFirstChild("TotalKills")
			if killsText then
				killsText.Text = FormatNumber(totalKills)
			end
		end

		local moneyEarnedLabel = stats:FindFirstChild("MoneyEarned")
		if moneyEarnedLabel then
			local moneyText = moneyEarnedLabel:FindFirstChild("MoneyEarned")
			if moneyText then
				moneyText.Text = "$" .. FormatNumber(totalCashEarned)
			end
		end

		local playTimeLabel = stats:FindFirstChild("PlayTime")
		if playTimeLabel then
			local timeText = playTimeLabel:FindFirstChild("PlayTime")
			if timeText then
				timeText.Text = FormatTime(playTime)
			end
		end
	end

	-- Show game over screen
	gameOverFrame.Visible = true

	-- Setup Return button
	local returnButton = frame:FindFirstChild("Return")
	if returnButton then
		returnButton.Activated:Connect(function()
			-- Teleport back to lobby
			TeleportService:Teleport(LOBBY_PLACE_ID, player)
		end)
	end

	-- Setup Retry button
	local retryButton = frame:FindFirstChild("Retry")
	if retryButton then
		retryButton.Activated:Connect(function()
			-- Request game reset from server
			local ResetGameFunction = ReplicatedStorage.Functions:WaitForChild("ResetGame")
			local success = ResetGameFunction:InvokeServer()
			if success then
				-- Hide game over screen and reset client state
				gameOverFrame.Visible = false
				gameEnded = false
				totalKills = 0
				totalDamage = 0
				totalCashEarned = 0
				startTime = tick()

				-- Show StartGame button again
				if gui.StartGame then
					gui.StartGame.Visible = true
				end
			end
		end)
	end
end

local function ShowBossWarning(bossName, waveNumber)
	local warningFrame = gui:FindFirstChild("BossWarning")
	if not warningFrame then
		warningFrame = Instance.new("Frame")
		warningFrame.Name = "BossWarning"
		warningFrame.Size = UDim2.new(1, 0, 0.2, 0)
		warningFrame.Position = UDim2.new(0, 0, 0.4, 0)
		warningFrame.BackgroundColor3 = Color3.fromRGB(210, 0, 0) -- #d20000
		warningFrame.BorderSizePixel = 0
		warningFrame.Parent = gui

		-- Add gradient
		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new{
			ColorSequenceKeypoint.new(0, Color3.fromRGB(210, 0, 0)), -- #d20000
			ColorSequenceKeypoint.new(1, Color3.fromRGB(130, 0, 0))  -- #820000
		}
		gradient.Rotation = 90 -- Top to bottom gradient
		gradient.Parent = warningFrame

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = warningFrame

		local titleLabel = Instance.new("TextLabel")
		titleLabel.Name = "Title"
		titleLabel.Size = UDim2.new(1, 0, 0.5, 0)
		titleLabel.Position = UDim2.new(0, 0, 0, 0)
		titleLabel.BackgroundTransparency = 1
		titleLabel.Text = "⚠️ BOSS INCOMING ⚠️"
		titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		titleLabel.TextScaled = true
		titleLabel.Font = Enum.Font.FredokaOne

		local titleStroke = Instance.new("UIStroke")
		titleStroke.Color = Color3.new(0, 0, 0)
		titleStroke.Thickness = 2
		titleStroke.Parent = titleLabel

		titleLabel.Parent = warningFrame

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "BossName"
		nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
		nameLabel.Position = UDim2.new(0, 0, 0.5, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = bossName .. " - Wave " .. waveNumber
		nameLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
		nameLabel.TextScaled = true
		nameLabel.Font = Enum.Font.FredokaOne

		local nameStroke = Instance.new("UIStroke")
		nameStroke.Color = Color3.new(0, 0, 0)
		nameStroke.Thickness = 2
		nameStroke.Parent = nameLabel

		nameLabel.Parent = warningFrame
	end

	local titleLabel = warningFrame:FindFirstChild("Title")
	local nameLabel = warningFrame:FindFirstChild("BossName")

	if titleLabel and nameLabel then
		nameLabel.Text = bossName .. " - Wave " .. waveNumber
	end

	-- Clean up existing tween
	local existingTween = warningFrame:FindFirstChild("WarningTween")
	if existingTween then
		pcall(function()
			existingTween:Cancel()
			existingTween:Destroy()
		end)
	end

	warningFrame.Visible = true

	-- Animate warning with proper cleanup
	local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, true)
	local tween = TweenService:Create(warningFrame, tweenInfo, {BackgroundTransparency = 0.3})
	tween.Name = "WarningTween"
	tween.Parent = warningFrame
	tween:Play()

	-- Hide after 3 seconds and clean up
	task.delay(3, function()
		if warningFrame then
			local cleanupTween = warningFrame:FindFirstChild("WarningTween")
			if cleanupTween then
				pcall(function()
					cleanupTween:Cancel()
					cleanupTween:Destroy()
				end)
			end
			warningFrame.Visible = false
		end
	end)
end

local function ShowBossDefeated(bossName, reward)
	local defeatedFrame = gui:FindFirstChild("BossDefeated")
	if not defeatedFrame then
		defeatedFrame = Instance.new("Frame")
		defeatedFrame.Name = "BossDefeated"
		defeatedFrame.Size = UDim2.new(1, 0, 0.15, 0)
		defeatedFrame.Position = UDim2.new(0, 0, 0.3, 0)
		defeatedFrame.BackgroundColor3 = Color3.fromRGB(0, 139, 0)
		defeatedFrame.BorderSizePixel = 0
		defeatedFrame.Parent = gui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = defeatedFrame

		local titleLabel = Instance.new("TextLabel")
		titleLabel.Name = "Title"
		titleLabel.Size = UDim2.new(1, 0, 0.5, 0)
		titleLabel.Position = UDim2.new(0, 0, 0, 0)
		titleLabel.BackgroundTransparency = 1
		titleLabel.Text = "🎉 BOSS DEFEATED 🎉"
		titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		titleLabel.TextScaled = true
		titleLabel.Font = Enum.Font.FredokaOne

		local titleStroke = Instance.new("UIStroke")
		titleStroke.Color = Color3.new(0, 0, 0)
		titleStroke.Thickness = 2
		titleStroke.Parent = titleLabel

		titleLabel.Parent = defeatedFrame

		local rewardLabel = Instance.new("TextLabel")
		rewardLabel.Name = "Reward"
		rewardLabel.Size = UDim2.new(1, 0, 0.5, 0)
		rewardLabel.Position = UDim2.new(0, 0, 0.5, 0)
		rewardLabel.BackgroundTransparency = 1
		rewardLabel.Text = bossName .. " - +" .. reward .. " cash!"
		rewardLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
		rewardLabel.TextScaled = true
		rewardLabel.Font = Enum.Font.FredokaOne

		local rewardStroke = Instance.new("UIStroke")
		rewardStroke.Color = Color3.new(0, 0, 0)
		rewardStroke.Thickness = 2
		rewardStroke.Parent = rewardLabel

		rewardLabel.Parent = defeatedFrame
	end

	local titleLabel = defeatedFrame:FindFirstChild("Title")
	local rewardLabel = defeatedFrame:FindFirstChild("Reward")

	if titleLabel and rewardLabel then
		rewardLabel.Text = bossName .. " - +" .. reward .. " cash!"
	end

	-- Clean up existing tween
	local existingTween = defeatedFrame:FindFirstChild("DefeatedTween")
	if existingTween then
		pcall(function()
			existingTween:Cancel()
			existingTween:Destroy()
		end)
	end

	defeatedFrame.Visible = true

	-- Animate celebration with proper cleanup
	local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, true)
	local tween = TweenService:Create(defeatedFrame, tweenInfo, {BackgroundTransparency = 0.3})
	tween.Name = "DefeatedTween"
	tween.Parent = defeatedFrame
	tween:Play()

	-- Hide after 4 seconds and clean up
	task.delay(4, function()
		if defeatedFrame then
			local cleanupTween = defeatedFrame:FindFirstChild("DefeatedTween")
			if cleanupTween then
				pcall(function()
					cleanupTween:Cancel()
					cleanupTween:Destroy()
				end)
			end
			defeatedFrame.Visible = false
		end
	end)
end

base.Humanoid.Died:Connect(function()
	ShowGameOver()
end)

-- Monitor base health
base.Humanoid.HealthChanged:Connect(function(health)
	if health <= 0 and not gameEnded then
		ShowGameOver()
	end
end)

-- Monitor waves for victory
info.Wave.Changed:Connect(function(currentWave)
end)

workspace.Mobs.ChildAdded:Connect(function(mob)
	local bossType = mob:FindFirstChild("BossType")
	if bossType then
		local bossWave = mob:FindFirstChild("BossWave")
		if bossWave then
			ShowBossWarning(bossType.Value, bossWave.Value)
		end
	end
end)

-- Boss death notification via RemoteEvent
local events = ReplicatedStorage:WaitForChild("Events", 5)
if events then
	local bossDeathEvent = events:WaitForChild("BossDeath", 5)
	if bossDeathEvent then
		bossDeathEvent.OnClientEvent:Connect(function(bossName, reward)
			ShowBossDefeated(bossName, reward)
		end)
	end
end

