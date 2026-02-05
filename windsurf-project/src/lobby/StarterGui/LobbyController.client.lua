print("LobbyController: Script starting...")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
print("LobbyController: Got player:", player.Name)

local gui = player:WaitForChild("PlayerGui"):WaitForChild("LobbyGui")
print("LobbyController: Found LobbyGui")

local TowerData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TowerData"))
local MapData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MapData"))
local TraitSystem = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TraitSystem"))
local RelicSystem = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RelicSystem"))
local EvolutionSystem = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EvolutionSystem"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
print("LobbyController: Loaded TowerData")
print("LobbyController: Loaded MapData")

-- Remote Functions
local functions = ReplicatedStorage:WaitForChild("Functions")
local SingleSummonFunction = functions:WaitForChild("SingleSummon")
local MultiSummonFunction = functions:WaitForChild("MultiSummon")
local GetInventoryFunction = functions:WaitForChild("GetInventory")
local GetLoadoutFunction = functions:WaitForChild("GetLoadout")
local AddToLoadoutFunction = functions:WaitForChild("AddToLoadout")
local RemoveFromLoadoutFunction = functions:WaitForChild("RemoveFromLoadout")
local SetLoadoutSlotFunction = functions:WaitForChild("SetLoadoutSlot")
local TeleportToGameFunction = functions:WaitForChild("TeleportToGame")
local TeleportPartyFunction = functions:WaitForChild("TeleportParty")
local GetPartyInfoFunction = functions:WaitForChild("GetPartyInfo")
local GetPartyMapsFunction = functions:WaitForChild("GetPartyMaps")
local GetPartyActsFunction = functions:WaitForChild("GetPartyActs")

-- Unit management functions (optional - don't block initialization)
local GetUnitDetailsFunction = nil
local RerollTraitFunction = nil
local GetRelicInventoryFunction = nil
local EquipRelicFunction = nil
local UnequipRelicFunction = nil
local EvolveUnitFunction = nil
local GetEvolutionInfoFunction = nil

-- Load unit management functions in background (don't block main thread)
task.spawn(function()
	GetUnitDetailsFunction = functions:WaitForChild("GetUnitDetails", 30)
	RerollTraitFunction = functions:WaitForChild("RerollTrait", 30)
	GetRelicInventoryFunction = functions:WaitForChild("GetRelicInventory", 30)
	EquipRelicFunction = functions:WaitForChild("EquipRelic", 30)
	UnequipRelicFunction = functions:WaitForChild("UnequipRelic", 30)
	EvolveUnitFunction = functions:WaitForChild("EvolveUnit", 30)
	GetEvolutionInfoFunction = functions:WaitForChild("GetEvolutionInfo", 30)
	print("LobbyController: Unit management functions loaded")
end)

local LobbyController = {}

-- State variables
local selectedMapId = nil
local selectedAct = 1
local selectedUnit = nil -- Currently selected unit from inventory for swap system
local currentUnitDetailsId = nil -- Currently viewing unit in details panel

-- VFX display variables
local vfxDisplayModel = nil
local vfxRenderConnection = nil
local savedCameraCFrame = nil
local savedCameraType = nil

-- Rainbow gradient animation for Mythic rarity
local rainbowConnection = nil

-- Inventory mode state variables
local inventoryModeActive = false
local savedInventoryCameraCFrame = nil
local savedInventoryCameraType = nil
local savedSky = nil
local savedAtmosphere = nil
local hiddenGUIsForInventory = {}
local inventoryDisplayModel = nil -- Currently displayed unit model in inventory mode
local inventoryMirrorModel = nil -- Cloned model for reflection (upside-down)
local inventoryRotationConnection = nil -- Connection for rotating the model
local inventoryModelRotation = 180 -- Current Y rotation in degrees

-- Update Swap button visibility on all loadout slots
local function UpdateSwapButtonVisibility()
	local loadoutFrame = gui:FindFirstChild("LoadoutUI") or gui:FindFirstChild("LoadoutFrame")
	if not loadoutFrame then return end
	
	for i = 1, 6 do
		local slot = loadoutFrame:FindFirstChild("Slot" .. i)
		if slot then
			local swapButton = slot:FindFirstChild("Swap")
			if swapButton then
				swapButton.Visible = (selectedUnit ~= nil)
			end
		end
	end
end

-- Clear selected unit and hide swap buttons
local function ClearSelectedUnit()
	selectedUnit = nil
	UpdateSwapButtonVisibility()
	
	-- Remove highlight from all inventory slots
	local inventoryUI = gui:FindFirstChild("InventoryUI")
	if inventoryUI then
		local gridFrame = inventoryUI:FindFirstChild("GridFrame")
		if gridFrame then
			for _, slot in ipairs(gridFrame:GetChildren()) do
				if slot:IsA("Frame") or slot:IsA("ImageButton") then
					-- Reset any selection highlight (restore original border or remove highlight)
					local highlight = slot:FindFirstChild("SelectionHighlight")
					if highlight then
						highlight:Destroy()
					end
				end
			end
		end
	end
end

-- Button press animation (shrink and pop back)
local function animateButtonPress(button)
	if not button then return end
	
	-- Store original size
	local originalSize = button.Size
	
	-- Shrink tween
	local shrinkTween = TweenService:Create(button, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(originalSize.X.Scale * 0.95, originalSize.X.Offset * 0.95, originalSize.Y.Scale * 0.95, originalSize.Y.Offset * 0.95)
	})
	
	-- Pop back tween
	local popTween = TweenService:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = originalSize
	})
	
	shrinkTween:Play()
	shrinkTween.Completed:Connect(function()
		popTween:Play()
	end)
end

-- Helper to connect button with press animation
local function connectButtonWithAnimation(button, callback)
	if not button then return end
	
	button.Activated:Connect(function()
		animateButtonPress(button)
		if callback then
			callback()
		end
	end)
end

-- Update gems display
local function UpdateGemsDisplay()
	local playerData = player:WaitForChild("PlayerData")
	local gems = playerData:WaitForChild("Gems")

	if gui:FindFirstChild("GemsDisplay") then
		local gemsLabel = gui.GemsDisplay:FindFirstChild("GemsAmount")
		if gemsLabel then
			gemsLabel.Text = tostring(gems.Value)
		end
	end
end

-- Update pity counter display
local function UpdatePityDisplay()
	local playerData = player:WaitForChild("PlayerData")
	local pityCounter = playerData:WaitForChild("PityCounter")

	if gui:FindFirstChild("SummonUI") then
		local pityLabel = gui.SummonUI:FindFirstChild("PityCounter")
		if pityLabel then
			local remaining = 50 - pityCounter.Value
			pityLabel.Text = "Pity: " .. remaining .. " summons until guaranteed Legendary"
		end
	end
end

-- Show summon result animation with ViewportFrame
-- Accepts either a tower directly or a result object with {Tower, InstanceId, Traits}
local function ShowSummonResult(resultData)
	if not resultData then
		warn("ShowSummonResult: resultData is nil")
		return
	end
	
	-- Handle new format: {Tower = tower, InstanceId = ..., Traits = ...}
	local tower = resultData.Tower or resultData
	if not tower or not tower.Name then
		warn("ShowSummonResult: tower data is invalid")
		return
	end

	-- ResultFrame is now a direct child of LobbyGui
	local resultFrame = gui:FindFirstChild("ResultFrame")
	if not resultFrame then 
		warn("ShowSummonResult: ResultFrame not found")
		return 
	end

	-- Hide all other GUI elements including SummonUI
	for _, child in ipairs(gui:GetChildren()) do
		if child ~= resultFrame and child:IsA("GuiObject") then
			child.Visible = false
		end
	end

	-- Save current camera position and move camera high up in the sky
	local cam = workspace.CurrentCamera
	if not savedCameraCFrame then
		savedCameraCFrame = cam.CFrame
		savedCameraType = cam.CameraType
		-- Lock camera in place and position high in the sky looking down
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = CFrame.new(0, 500, 0) * CFrame.Angles(math.rad(-90), 0, 0)
	end

	-- Add depth of field blur effect to camera (only if it doesn't already exist)
	local blur = workspace.CurrentCamera:FindFirstChild("SummonBlur")
	if not blur then
		blur = Instance.new("DepthOfFieldEffect")
		blur.Name = "SummonBlur"
		blur.FarIntensity = 0.75
		blur.FocusDistance = 0
		blur.InFocusRadius = 8.985
		blur.NearIntensity = 0.75
		blur.Parent = workspace.CurrentCamera
	end

	-- Set tower info
	local towerName = resultFrame:FindFirstChild("TowerName")
	if towerName then
		towerName.Text = tower.Name
	end

	local rarity = resultFrame:FindFirstChild("Rarity")
	if rarity then
		rarity.Text = tower.Rarity

		-- Stop any existing rainbow animation
		if rainbowConnection then
			rainbowConnection:Disconnect()
			rainbowConnection = nil
		end

		-- Special rainbow cycle for Mythic rarity
		if tower.Rarity == "Mythic" then
			rainbowConnection = RunService.RenderStepped:Connect(function()
				-- Ping-pong between cyan (0.5) and magenta (0.83) using sine wave
				local t = (math.sin(tick() * 0.8) + 1) / 2 -- Oscillates between 0 and 1
				local hue = 0.5 + t * 0.33 -- Smoothly cycles cyan <-> magenta
				rarity.TextColor3 = Color3.fromHSV(hue, 1, 1)
			end)
		else
			-- Normal static color for other rarities
			rarity.TextColor3 = TowerData.Rarities[tower.Rarity].Color
		end
	end

	local description = resultFrame:FindFirstChild("Description")
	if description then
		description.Text = tower.Description
	end

	-- Setup ViewportFrame with tower model
	local viewportFrame = resultFrame:FindFirstChild("ViewportFrame")
	if viewportFrame then
		-- Set ViewportFrame background to fully transparent
		viewportFrame.BackgroundTransparency = 1

		-- Clear existing content
		viewportFrame:ClearAllChildren()

		-- Create WorldModel
		local worldModel = Instance.new("WorldModel")
		worldModel.Parent = viewportFrame

		-- Find and clone tower model
		local towersFolder = ReplicatedStorage:FindFirstChild("Towers")
		if towersFolder then
			local towerModel = towersFolder:FindFirstChild(tower.ModelName)
			if towerModel then
				towerModel.Archivable = true
				for _, obj in ipairs(towerModel:GetDescendants()) do
					obj.Archivable = true
				end

				local modelClone = towerModel:Clone()

				-- Remove scripts from clone
				for _, obj in ipairs(modelClone:GetDescendants()) do
					if obj:IsA("Script") or obj:IsA("LocalScript") then
						obj:Destroy()
					end
				end
				
				-- Remove PlacementVFX folder
				local placementVFX = modelClone:FindFirstChild("PlacementVFX", true)
				if placementVFX then
					placementVFX:Destroy()
				end

				modelClone.Parent = worldModel

				-- Setup camera
				local camera = Instance.new("Camera")
				camera.Parent = viewportFrame
				viewportFrame.CurrentCamera = camera

				if modelClone.PrimaryPart then
					local position = modelClone.PrimaryPart.Position
					modelClone:SetPrimaryPartCFrame(CFrame.new(position) * CFrame.Angles(0, math.rad(180), 0))

					-- Start camera slightly zoomed out for tween animation
					local finalCameraPos = CFrame.new(position + Vector3.new(0, 1, 3), position + Vector3.new(0, 0.5, 0))
					local startCameraPos = CFrame.new(position + Vector3.new(0, 1.2, 3.6), position + Vector3.new(0, 0.5, 0))
					camera.CFrame = startCameraPos

					-- Zoom in tween animation
					local zoomTween = TweenService:Create(camera, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = finalCameraPos})
					zoomTween:Play()
				end

				-- Create 3D VFX display in workspace (positioned in front of camera)
				local vfxFolder = towerModel:FindFirstChild("PlacementVFX")
				if vfxFolder then
					print("ShowSummonResult: Found PlacementVFX folder, creating 3D VFX display")

					-- Clean up existing VFX display
					if vfxDisplayModel then
						vfxDisplayModel:Destroy()
					end
					if vfxRenderConnection then
						vfxRenderConnection:Disconnect()
					end

					-- Clone the tower model for VFX display in workspace
					towerModel.Archivable = true
					for _, obj in ipairs(towerModel:GetDescendants()) do
						obj.Archivable = true
					end

					vfxDisplayModel = towerModel:Clone()

					-- Remove scripts and make all parts transparent except VFX
					for _, obj in ipairs(vfxDisplayModel:GetDescendants()) do
						if obj:IsA("Script") or obj:IsA("LocalScript") then
							obj:Destroy()
						elseif obj:IsA("BasePart") then
							obj.Transparency = 1  -- Fully invisible
							obj.CanCollide = false
							obj.Anchored = true
						end
					end

					vfxDisplayModel.Parent = workspace

					-- Play all sounds and enable particles
					local displayVFXFolder = vfxDisplayModel:FindFirstChild("PlacementVFX")
					if displayVFXFolder then
						for _, obj in ipairs(displayVFXFolder:GetDescendants()) do
							if obj:IsA("Sound") then
								print("ShowSummonResult: Playing sound", obj.Name)
								obj:Play()
							elseif obj:IsA("ParticleEmitter") then
								-- Enable looping for continuous VFX during summon
								print("ShowSummonResult: Enabling looping particles", obj.Name)
								obj.Enabled = true
								-- Emit burst immediately for instant appearance (no startup delay)
								local emitCount = obj:GetAttribute("EmitCount") or 1
								obj:Emit(emitCount)
							end
						end
					end

					-- Scale animation: start at 3x size, shrink to normal over 1 second
					local startScale = 3

					-- Store original sizes and scale parts to 3x initially
					local originalSizes = {}
					for _, part in ipairs(vfxDisplayModel:GetDescendants()) do
						if part:IsA("BasePart") then
							originalSizes[part] = part.Size
							part.Size = part.Size * startScale
						end
					end

					-- Tween all parts back to normal size over 1 second
					task.delay(0.1, function()
						for part, originalSize in pairs(originalSizes) do
							if part and part.Parent then
								local sizeTween = TweenService:Create(
									part,
									TweenInfo.new(1, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
									{Size = originalSize}
								)
								sizeTween:Play()
							end
						end
					end)

					-- Position model in front of camera and update every frame
					local cam = workspace.CurrentCamera
					vfxRenderConnection = RunService.RenderStepped:Connect(function()
						if vfxDisplayModel and vfxDisplayModel.PrimaryPart and cam then
							-- Position 5 studs in front of camera for natural VFX appearance
							local offset = CFrame.new(0, -0.5, -7.5)
							local targetCFrame = cam.CFrame * offset * CFrame.Angles(0, math.rad(180), 0)
							vfxDisplayModel:SetPrimaryPartCFrame(targetCFrame)
						end
					end)

					print("ShowSummonResult: Created 3D VFX display in workspace")
				else
					print("ShowSummonResult: No PlacementVFX folder found in", tower.ModelName)
				end
			end
		end
	end

	-- Show result with fully transparent background
	resultFrame.Visible = true
	resultFrame.BackgroundTransparency = 1
end

-- Hide summon result
local function HideSummonResult()
	-- ResultFrame is now a direct child of LobbyGui
	local resultFrame = gui:FindFirstChild("ResultFrame")
	if resultFrame then
		resultFrame.Visible = false

		-- Clear ViewportFrame content
		local viewportFrame = resultFrame:FindFirstChild("ViewportFrame")
		if viewportFrame then
			viewportFrame:ClearAllChildren()
		end

		-- Clean up 3D VFX display
		if vfxDisplayModel then
			vfxDisplayModel:Destroy()
			vfxDisplayModel = nil
		end
		if vfxRenderConnection then
			vfxRenderConnection:Disconnect()
			vfxRenderConnection = nil
		end

		-- Clean up rainbow animation
		if rainbowConnection then
			rainbowConnection:Disconnect()
			rainbowConnection = nil
		end
	end

	-- Remove blur effect
	local blur = workspace.CurrentCamera:FindFirstChild("SummonBlur")
	if blur then
		blur:Destroy()
	end

	-- Restore camera position and type
	if savedCameraCFrame then
		workspace.CurrentCamera.CFrame = savedCameraCFrame
		savedCameraCFrame = nil
	end
	if savedCameraType then
		workspace.CurrentCamera.CameraType = savedCameraType
		savedCameraType = nil
	end

	-- Restore all GUI elements that were hidden (except InventoryUI, ErrorMessage, and MapSelectorUI)
	for _, child in ipairs(gui:GetChildren()) do
		if child:IsA("GuiObject") and child.Name ~= "ResultFrame" and child.Name ~= "InventoryUI" and child.Name ~= "ErrorMessage" and child.Name ~= "MapSelectorUI" then
			-- Show all GUI elements except ResultFrame, InventoryUI, ErrorMessage, and MapSelectorUI
			child.Visible = true
		end
	end
end

-- Single summon button
function LobbyController.SingleSummon()
	HideSummonResult()

	local result = SingleSummonFunction:InvokeServer()

	if result.Success then
		ShowSummonResult(result.Tower)
		UpdateGemsDisplay()
		UpdatePityDisplay()
		-- Refresh inventory to show new tower
		LobbyController.LoadInventory()
	else
		warn("Summon failed:", result.Error)
		-- Show error message to player
		if gui:FindFirstChild("ErrorMessage") then
			gui.ErrorMessage.Text = result.Error
			gui.ErrorMessage.Visible = true
			task.wait(2)
			gui.ErrorMessage.Visible = false
		end
	end
end

-- Multi summon button
function LobbyController.MultiSummon()
	HideSummonResult()

	local result = MultiSummonFunction:InvokeServer()

	if result.Success then
		-- Show all 10 results with click-to-continue
		local currentIndex = 1
		local clickConnection
		local continueClicked = false

		-- Show first tower
		ShowSummonResult(result.Towers[currentIndex])

		-- Setup click-to-continue on ResultFrame
		local resultFrame = gui:FindFirstChild("ResultFrame")
		if resultFrame then
			clickConnection = resultFrame.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					continueClicked = true
				end
			end)

			-- Loop through remaining towers
			for i = 2, #result.Towers do
				-- Wait for click
				continueClicked = false
				repeat
					task.wait(0.1)
				until continueClicked

				-- Show next tower
				currentIndex = i
				ShowSummonResult(result.Towers[currentIndex])
			end

			-- Wait for final click to close
			continueClicked = false
			repeat
				task.wait(0.1)
			until continueClicked

			-- Cleanup
			if clickConnection then
				clickConnection:Disconnect()
			end

			HideSummonResult()
		end

		UpdateGemsDisplay()
		UpdatePityDisplay()
		-- Refresh inventory to show new towers
		LobbyController.LoadInventory()
	else
		warn("Multi-summon failed:", result.Error)
		if gui:FindFirstChild("ErrorMessage") then
			gui.ErrorMessage.Text = result.Error
			gui.ErrorMessage.Visible = true
			task.wait(2)
			gui.ErrorMessage.Visible = false
		end
	end
end

-- Spawn unit model in inventory mode at specified position
local function SpawnInventoryDisplayModel(unitId)
	-- Clean up existing model
	if inventoryDisplayModel then
		inventoryDisplayModel:Destroy()
		inventoryDisplayModel = nil
	end
	
	-- Get tower data (search array by ID)
	local tower = nil
	for _, t in ipairs(TowerData.Towers) do
		if t.ID == unitId then
			tower = t
			break
		end
	end
	if not tower then
		warn("LobbyController: Tower not found for unitId:", unitId)
		return
	end
	
	-- Get the model
	local towersFolder = ReplicatedStorage:FindFirstChild("Towers")
	if not towersFolder then
		warn("LobbyController: Towers folder not found in ReplicatedStorage")
		return
	end
	
	local towerModel = towersFolder:FindFirstChild(tower.ModelName)
	if not towerModel then
		warn("LobbyController: Tower model not found:", tower.ModelName)
		return
	end
	
	-- Clone and setup the model
	local modelClone = towerModel:Clone()
	
	-- Remove scripts and VFX from clone
	for _, obj in ipairs(modelClone:GetDescendants()) do
		if obj:IsA("Script") or obj:IsA("LocalScript") then
			obj:Destroy()
		elseif obj:IsA("ParticleEmitter") or obj:IsA("Beam") or obj:IsA("Trail") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
			obj:Destroy()
		end
	end
	
	-- Remove PlacementVFX folder
	local placementVFX = modelClone:FindFirstChild("PlacementVFX", true)
	if placementVFX then
		placementVFX:Destroy()
	end
	
	-- Position the model at the specified location
	local displayPosition = Vector3.new(0.664, 598.971, 1195.967)
	
	-- Ensure model has a PrimaryPart
	if not modelClone.PrimaryPart then
		local rootPart = modelClone:FindFirstChild("HumanoidRootPart") or modelClone:FindFirstChildWhichIsA("BasePart")
		if rootPart then
			modelClone.PrimaryPart = rootPart
		end
	end
	
	-- Only anchor root part to allow animations to play
	local rootPart = modelClone:FindFirstChild("HumanoidRootPart") or modelClone.PrimaryPart
	if rootPart then
		rootPart.Anchored = true
	end
	
	-- Use PivotTo for smooth positioning
	modelClone:PivotTo(CFrame.new(displayPosition) * CFrame.Angles(0, math.rad(180), 0))
	
	modelClone.Name = "InventoryDisplayModel"
	modelClone.Parent = workspace
	inventoryDisplayModel = modelClone
	
	-- Create simple reflection: upside-down clone at the feet
	if inventoryMirrorModel then
		inventoryMirrorModel:Destroy()
		inventoryMirrorModel = nil
	end
	
	-- Clone the model for reflection
	local reflectionClone = modelClone:Clone()
	reflectionClone.Name = "InventoryReflectionModel"
	
	-- Remove scripts and VFX from reflection
	for _, obj in ipairs(reflectionClone:GetDescendants()) do
		if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ParticleEmitter") or obj:IsA("Beam") or obj:IsA("Trail") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
			obj:Destroy()
		end
	end
	local placementVFX = reflectionClone:FindFirstChild("PlacementVFX", true)
	if placementVFX then
		placementVFX:Destroy()
	end
	
	-- Make all parts semi-transparent for reflection effect
	for _, part in ipairs(reflectionClone:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Transparency = math.max(part.Transparency, 0.5)
			part.CanCollide = false
			part.CastShadow = false
		end
	end
	
	-- Only anchor root part of reflection to allow animation
	local reflectionRoot = reflectionClone:FindFirstChild("HumanoidRootPart") or reflectionClone.PrimaryPart
	if reflectionRoot then
		reflectionRoot.Anchored = true
	end
	
	-- Position reflection upside-down at the feet (flipped on Z axis for mirror effect)
	local modelHeight = 3.6 -- Approximate height of model
	reflectionClone:PivotTo(CFrame.new(displayPosition - Vector3.new(0, modelHeight, 0)) * CFrame.Angles(0, math.rad(inventoryModelRotation), math.rad(180)))
	
	reflectionClone.Parent = workspace
	inventoryMirrorModel = reflectionClone
	
	print("LobbyController: Simple reflection clone created")
	
	-- Play animation on main model
	local humanoid = modelClone:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
		
		local animation = Instance.new("Animation")
		animation.AnimationId = "rbxassetid://74802924296512"
		
		local animTrack = animator:LoadAnimation(animation)
		animTrack.Looped = true
		animTrack:Play()
	end
	
	-- Play animation on reflection model
	local reflectionHumanoid = reflectionClone:FindFirstChildOfClass("Humanoid")
	if reflectionHumanoid then
		local reflectionAnimator = reflectionHumanoid:FindFirstChildOfClass("Animator")
		if not reflectionAnimator then
			reflectionAnimator = Instance.new("Animator")
			reflectionAnimator.Parent = reflectionHumanoid
		end
		
		local reflectionAnimation = Instance.new("Animation")
		reflectionAnimation.AnimationId = "rbxassetid://74802924296512"
		
		local reflectionAnimTrack = reflectionAnimator:LoadAnimation(reflectionAnimation)
		reflectionAnimTrack.Looped = true
		reflectionAnimTrack:Play()
	end
	
	-- Set up mouse drag rotation
	local UserInputService = game:GetService("UserInputService")
	local isDragging = false
	local lastMouseX = 0
	
	-- Disconnect any existing rotation connection
	if inventoryRotationConnection then
		inventoryRotationConnection:Disconnect()
		inventoryRotationConnection = nil
	end
	
	local function updateModelRotation()
		if inventoryDisplayModel then
			local displayPosition = Vector3.new(0.664, 598.971, 1195.967)
			inventoryDisplayModel:PivotTo(CFrame.new(displayPosition) * CFrame.Angles(0, math.rad(inventoryModelRotation), 0))
			
			-- Also rotate the reflection clone (upside down on Z axis)
			if inventoryMirrorModel then
				local modelHeight = 3.6
				inventoryMirrorModel:PivotTo(CFrame.new(displayPosition - Vector3.new(0, modelHeight, 0)) * CFrame.Angles(0, math.rad(inventoryModelRotation), math.rad(180)))
			end
		end
	end
	
	-- Track mouse button state
	local mouseDownConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isDragging = true
			lastMouseX = input.Position.X
		end
	end)
	
	local mouseUpConn = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isDragging = false
		end
	end)
	
	local mouseMoveConn = UserInputService.InputChanged:Connect(function(input)
		if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local deltaX = input.Position.X - lastMouseX
			inventoryModelRotation = inventoryModelRotation - deltaX * 0.5 -- Adjust sensitivity here
			lastMouseX = input.Position.X
			updateModelRotation()
		end
	end)
	
	-- Store connections for cleanup
	inventoryRotationConnection = {
		Disconnect = function()
			mouseDownConn:Disconnect()
			mouseUpConn:Disconnect()
			mouseMoveConn:Disconnect()
		end
	}
	
	print("LobbyController: Spawned inventory display model for", tower.Name)
end

-- Load and display inventory
function LobbyController.LoadInventory()
	print("LobbyController: LoadInventory called")
	local inventory = GetInventoryFunction:InvokeServer()
	print("LobbyController: Received inventory with", #inventory, "items")

	local inventoryUI = gui:FindFirstChild("InventoryUI")
	if not inventoryUI then 
		warn("LobbyController: InventoryUI not found")
		return 
	end

	-- Find GridFrame
	local gridFrame = inventoryUI:FindFirstChild("GridFrame")
	if not gridFrame then
		warn("LobbyController: GridFrame not found in InventoryUI")
		return
	end

	-- Find template slot in GridFrame
	local template = gridFrame:FindFirstChild("Template")
	if not template then
		warn("LobbyController: Template not found in GridFrame")
		return
	end

	print("LobbyController: Found template, cloning for inventory items")

	print("LobbyController: Clearing existing inventory items")
	-- Clear existing items (skip UIGridLayout, Template, and other UI elements)
	for _, child in ipairs(gridFrame:GetChildren()) do
		if (child:IsA("Frame") or child:IsA("ImageButton")) and child.Name ~= "Template" then
			child:Destroy()
		end
	end

	-- Create inventory slots from template
	print("LobbyController: Creating inventory slots")
	for i, towerData in ipairs(inventory) do
		-- Get tower info from TowerData using the TowerId
		local tower = TowerData.GetTowerById(towerData.TowerId)
		if tower then
			-- Clone template
			local slot = template:Clone()
			slot.Name = towerData.InstanceId or ("Tower_" .. i)
			slot.Visible = true
			slot.LayoutOrder = i
			-- Use rarity from unit instance data (may differ from base tower rarity)
			local rarity = towerData.Rarity or tower.Rarity
			slot.BackgroundColor3 = TowerData.Rarities[rarity] and TowerData.Rarities[rarity].Color or Color3.new(0.5, 0.5, 0.5)

			-- Update name label if it exists
			local nameLabel = slot:FindFirstChild("Name")
			if nameLabel then
				nameLabel.Text = tower.Name
			end

			-- Load tower model into ViewportFrame
			local viewportFrame = slot:FindFirstChild("ViewportFrame")
			if viewportFrame then
				local worldModel = viewportFrame:FindFirstChild("WorldModel")
				if not worldModel then
					worldModel = Instance.new("WorldModel")
					worldModel.Parent = viewportFrame
				else
					worldModel:ClearAllChildren()
				end

				-- Find tower model in ReplicatedStorage
				local towerModel = game:GetService("ReplicatedStorage"):FindFirstChild("Towers")
				if towerModel then
					towerModel = towerModel:FindFirstChild(tower.ModelName)
					if towerModel then

						-- Clone and prepare model
						towerModel.Archivable = true
						for _, obj in ipairs(towerModel:GetDescendants()) do
							obj.Archivable = true
						end

						local modelClone = towerModel:Clone()

						-- Remove scripts from clone
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
					else
						warn("LobbyController: Tower model", tower.ModelName, "not found in ReplicatedStorage.Towers")
					end
				else
					warn("LobbyController: Towers folder not found in ReplicatedStorage")
				end
			end

			slot.Parent = gridFrame

			-- Add Details button to open unit details panel
			local instanceId = towerData.InstanceId
			local detailsBtn = Instance.new("TextButton")
			detailsBtn.Name = "DetailsButton"
			detailsBtn.Size = UDim2.new(0.4, 0, 0, 20)
			detailsBtn.Position = UDim2.new(0.55, 0, 1, -25)
			detailsBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 120)
			detailsBtn.Text = "Details"
			detailsBtn.TextColor3 = Color3.new(1, 1, 1)
			detailsBtn.TextSize = 12
			detailsBtn.Font = Enum.Font.GothamBold
			detailsBtn.ZIndex = 2
			detailsBtn.Parent = slot
			
			local detailsBtnCorner = Instance.new("UICorner")
			detailsBtnCorner.CornerRadius = UDim.new(0, 4)
			detailsBtnCorner.Parent = detailsBtn
			
			detailsBtn.Activated:Connect(function()
				animateButtonPress(detailsBtn)
				LobbyController.OpenUnitDetails(instanceId)
			end)

			-- Click to select unit for swap system (using instanceId for new system)
			slot.Activated:Connect(function()
				animateButtonPress(slot)
				
				-- Clear previous selection highlight
				local gridFrame = slot.Parent
				for _, otherSlot in ipairs(gridFrame:GetChildren()) do
					if otherSlot:IsA("Frame") or otherSlot:IsA("ImageButton") then
						local highlight = otherSlot:FindFirstChild("SelectionHighlight")
						if highlight then
							highlight:Destroy()
						end
					end
				end
				
				-- Set selected unit (now uses instanceId instead of tower.ID)
				selectedUnit = instanceId
				print("LobbyController: Selected unit:", tower.Name, "(instanceId:", instanceId, ")")
				
				-- Spawn model in inventory mode
				if inventoryModeActive then
					SpawnInventoryDisplayModel(tower.ID)
				end
				
				-- Add selection highlight to this slot
				local highlight = Instance.new("UIStroke")
				highlight.Name = "SelectionHighlight"
				highlight.Color = Color3.fromRGB(255, 255, 0) -- Yellow highlight
				highlight.Thickness = 3
				highlight.Parent = slot
				
				-- Update swap button visibility on loadout slots
				UpdateSwapButtonVisibility()
			end)
		else
			warn("LobbyController: Could not find tower data for ID:", towerData.TowerId)
		end
	end
	print("LobbyController: Finished loading inventory")
end

-- Load and display loadout
function LobbyController.LoadLoadout()
	print("LobbyController: LoadLoadout called")
	local loadout = GetLoadoutFunction:InvokeServer()
	-- Count actual items in sparse table (# doesn't work for indexed tables with gaps)
	local loadoutCount = 0
	for slotNum, towerId in pairs(loadout) do
		loadoutCount = loadoutCount + 1
		print("LobbyController: Loadout slot", slotNum, "=", towerId)
	end
	print("LobbyController: Received loadout with", loadoutCount, "towers")

	-- Try LoadoutUI first, then LoadoutFrame for backwards compatibility
	local loadoutFrame = gui:FindFirstChild("LoadoutUI") or gui:FindFirstChild("LoadoutFrame")
	if not loadoutFrame then 
		warn("LobbyController: LoadoutUI/LoadoutFrame not found")
		return 
	end
	print("LobbyController: Found loadout container:", loadoutFrame.Name)

	-- Find template slots
	local template = loadoutFrame:FindFirstChild("Template")
	local emptyTemplate = loadoutFrame:FindFirstChild("EmptyTemplate")

	if not template then
		warn("LobbyController: Template not found in LoadoutFrame")
		return
	end

	if not emptyTemplate then
		warn("LobbyController: EmptyTemplate not found in LoadoutFrame")
		return
	end

	print("LobbyController: Found templates, creating loadout slots")

	-- Clear existing slots (skip Template, EmptyTemplate and UI elements)
	for _, child in ipairs(loadoutFrame:GetChildren()) do
		if (child:IsA("Frame") or child:IsA("ImageButton")) and child.Name ~= "Template" and child.Name ~= "EmptyTemplate" then
			child:Destroy()
		end
	end

	-- Helper function to load tower model with optional silhouette
	local function loadTowerModel(viewportFrame, towerModelName, asSilhouette)
		local worldModel = viewportFrame:FindFirstChild("WorldModel")
		if not worldModel then
			worldModel = Instance.new("WorldModel")
			worldModel.Parent = viewportFrame
		else
			worldModel:ClearAllChildren()
		end

		-- Find tower model
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

	-- Create loadout slots (max 6)
	for i = 1, 6 do
		local slot

		-- Check if slot has a unit (loadout[i] is false for empty, table with unit data for filled)
		local unitData = loadout[i]
		if unitData and unitData ~= false then
			-- Filled slot - use Template
			-- unitData now contains {InstanceId, TowerId, Rarity, XP, EvolutionStage, Traits}
			local tower = TowerData.GetTowerById(unitData.TowerId)
			if tower then
				print("LobbyController: Loading tower", tower.Name, "into slot", i)
				slot = template:Clone()
				slot.Name = "Slot" .. i
				slot.Visible = true
				slot.LayoutOrder = i

				-- Update name label if it exists
				local nameLabel = slot:FindFirstChild("Name")
				if nameLabel then
					nameLabel.Text = tower.Name
				end

				-- Update price label if it exists (to match RockMap UI)
				local priceLabel = slot:FindFirstChild("Price")
				if priceLabel then
					-- Use unit's rarity from instance data
					priceLabel.Text = unitData.Rarity or tower.Rarity
				end

				-- Load tower model with animation (matching RockMap)
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

					-- Find tower model
					local towersFolder = game:GetService("ReplicatedStorage"):FindFirstChild("Towers")
					if towersFolder then
						local towerModel = towersFolder:FindFirstChild(tower.ModelName)
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

							-- Add animation (matching RockMap)
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
				end

				-- Setup Swap button for filled slot
				local slotIndex = i -- Capture loop variable
				local swapButton = slot:FindFirstChild("Swap")
				if swapButton then
					swapButton.Visible = (selectedUnit ~= nil)
					swapButton.Activated:Connect(function()
						animateButtonPress(swapButton)
						if selectedUnit then
							print("LobbyController: Swapping slot", slotIndex, "with selected unit:", selectedUnit)
							-- Set the selected unit to this slot (server handles removing from other slots)
							SetLoadoutSlotFunction:InvokeServer(selectedUnit, slotIndex)
							ClearSelectedUnit()
							LobbyController.LoadLoadout()
						end
					end)
				end

				-- Click slot itself to remove from loadout (only if no unit selected)
				local currentInstanceId = unitData.InstanceId
				slot.Activated:Connect(function()
					if selectedUnit then
						-- If a unit is selected, clicking the slot swaps it
						print("LobbyController: Swapping slot", slotIndex, "with selected unit:", selectedUnit)
						SetLoadoutSlotFunction:InvokeServer(selectedUnit, slotIndex)
						ClearSelectedUnit()
						LobbyController.LoadLoadout()
					else
						-- No unit selected, remove from loadout using instanceId
						animateButtonPress(slot)
						print("LobbyController: Removing", tower.Name, "from loadout (instanceId:", currentInstanceId, ")")
						RemoveFromLoadoutFunction:InvokeServer(currentInstanceId)
						LobbyController.LoadLoadout()
					end
				end)

				-- Parent filled slot
				slot.Parent = loadoutFrame
			end
		else
			-- Empty slot - use EmptyTemplate with cycling silhouettes
			slot = emptyTemplate:Clone()
			slot.Name = "Slot" .. i
			slot.Visible = true
			slot.LayoutOrder = i

			local nameLabel = slot:FindFirstChild("Name")
			if nameLabel then
				nameLabel.Text = "Empty"
				nameLabel.TextColor3 = Color3.new(0.5, 0.5, 0.5)
			end

			-- Parent slot first so cycling coroutine can check slot.Parent
			slot.Parent = loadoutFrame

			-- Setup Swap button for empty slot
			local slotIndex = i -- Capture loop variable
			local swapButton = slot:FindFirstChild("Swap")
			if swapButton then
				swapButton.Visible = (selectedUnit ~= nil)
				swapButton.Activated:Connect(function()
					animateButtonPress(swapButton)
					if selectedUnit then
						print("LobbyController: Adding selected unit to empty slot", slotIndex)
						SetLoadoutSlotFunction:InvokeServer(selectedUnit, slotIndex)
						ClearSelectedUnit()
						LobbyController.LoadLoadout()
					end
				end)
			end

			-- Click empty slot to add selected unit (use InputBegan for Frame compatibility)
			slot.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					if selectedUnit then
						animateButtonPress(slot)
						print("LobbyController: Adding selected unit to empty slot", slotIndex)
						SetLoadoutSlotFunction:InvokeServer(selectedUnit, slotIndex)
						ClearSelectedUnit()
						LobbyController.LoadLoadout()
					end
				end
			end)

			-- Setup cycling silhouette animation
			local viewportFrame = slot:FindFirstChild("ViewportFrame")
			if viewportFrame and #TowerData.Towers > 0 then
				-- Load initial random tower
				local initialTower = TowerData.Towers[math.random(1, #TowerData.Towers)]
				loadTowerModel(viewportFrame, initialTower.ModelName, false)

				-- Cycle through random towers every 3 seconds
				task.spawn(function()
					while slot and slot.Parent do
						task.wait(3)
						if slot and slot.Parent then
							-- Pick a completely random tower each time
							local randomTower = TowerData.Towers[math.random(1, #TowerData.Towers)]
							loadTowerModel(viewportFrame, randomTower.ModelName, false)
						else
							break
						end
					end
				end)
			end
		end
	end
end

-- Show error message to player
function LobbyController.ShowError(message)
	print("LobbyController: ShowError -", message)
	local errorFrame = gui:FindFirstChild("ErrorMessage")
	if errorFrame then
		errorFrame.Text = message
		errorFrame.Visible = true
		-- Auto-hide after 3 seconds
		task.delay(3, function()
			if errorFrame.Text == message then
				errorFrame.Visible = false
			end
		end)
	else
		warn("LobbyController: ErrorMessage UI not found, error was:", message)
	end
end

-- Open Map Selector UI
function LobbyController.OpenMapSelector()
	print("LobbyController: OpenMapSelector called")
	local mapSelectorUI = gui:FindFirstChild("MapSelectorUI")
	if not mapSelectorUI then 
		warn("LobbyController: MapSelectorUI not found in LobbyGui")
		return 
	end
	print("LobbyController: Found MapSelectorUI")

	-- Reset selection
	selectedMapId = nil
	local detailsFrame = mapSelectorUI:FindFirstChild("MapDetailsFrame", true)
	if detailsFrame then
		detailsFrame.Visible = false
		print("LobbyController: Reset MapDetailsFrame visibility")
	end

	-- Populate map list
	print("LobbyController: Calling PopulateMapList")
	LobbyController.PopulateMapList()

	-- Show UI
	mapSelectorUI.Visible = true
	print("LobbyController: MapSelectorUI now visible")
end

-- Populate the map list with all available maps (respects party progress restrictions)
function LobbyController.PopulateMapList()
	print("LobbyController: PopulateMapList called")
	local mapSelectorUI = gui:FindFirstChild("MapSelectorUI")
	if not mapSelectorUI then 
		warn("LobbyController: MapSelectorUI not found in PopulateMapList")
		return 
	end
	print("LobbyController: Found MapSelectorUI in PopulateMapList")

	-- Find the ScrollingFrame (which is also named MapListFrame, nested inside a Frame)
	local mapListFrame = mapSelectorUI:FindFirstChild("MapListFrame", true)
	if not mapListFrame then 
		warn("LobbyController: MapListFrame not found in MapSelectorUI")
		print("LobbyController: MapSelectorUI children:", mapSelectorUI:GetChildren())
		return 
	end

	-- If it's a Frame, look for the ScrollingFrame child also named MapListFrame
	if mapListFrame:IsA("Frame") and not mapListFrame:IsA("ScrollingFrame") then
		local scrollingFrame = mapListFrame:FindFirstChild("MapListFrame")
		if scrollingFrame and scrollingFrame:IsA("ScrollingFrame") then
			mapListFrame = scrollingFrame
			print("LobbyController: Found ScrollingFrame inside Frame")
		end
	end
	print("LobbyController: Found MapListFrame:", mapListFrame.ClassName)

	local template = mapListFrame:FindFirstChild("Template")
	if not template then 
		warn("LobbyController: Template not found in MapListFrame")
		print("LobbyController: MapListFrame children:")
		for _, child in ipairs(mapListFrame:GetChildren()) do
			print("  -", child.Name, child.ClassName)
		end
		return 
	end
	print("LobbyController: Found Template")
	
	local lockedTemplate = mapListFrame:FindFirstChild("LockedTemplate")
	if not lockedTemplate then
		warn("LobbyController: LockedTemplate not found in MapListFrame, will use Template for locked maps")
	else
		print("LobbyController: Found LockedTemplate")
	end

	-- Clear existing map buttons (except Template, LockedTemplate and UIListLayout)
	for _, child in ipairs(mapListFrame:GetChildren()) do
		if child:IsA("GuiObject") and child.Name ~= "Template" and child.Name ~= "LockedTemplate" and not child:IsA("UIListLayout") and not child:IsA("UIGridLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end

	-- Check if player is in a party - use party maps if so
	local partyInfo = GetPartyInfoFunction:InvokeServer()
	local maps
	
	if partyInfo and (partyInfo.inParty or partyInfo.soloInBox) then
		-- In PlayBox - use party-restricted maps
		maps = GetPartyMapsFunction:InvokeServer()
		print("LobbyController: Using party maps (in PlayBox with", partyInfo.memberCount or 1, "players)")
	else
		-- Not in PlayBox - use normal maps
		local GetAvailableMapsFunction = ReplicatedStorage.Functions:WaitForChild("GetAvailableMaps")
		maps = GetAvailableMapsFunction:InvokeServer()
		print("LobbyController: Using solo maps")
	end
	
	print("LobbyController: Creating", #maps, "map buttons")

	for i, mapInfo in ipairs(maps) do
		-- Use LockedTemplate for locked maps, Template for unlocked
		local templateToUse = template
		if not mapInfo.IsUnlocked and lockedTemplate then
			templateToUse = lockedTemplate
		end
		
		print("LobbyController: Cloning", templateToUse.Name, "for", mapInfo.Name, "Unlocked:", mapInfo.IsUnlocked)
		local mapButton = templateToUse:Clone()
		mapButton.Name = mapInfo.ID
		mapButton.Visible = true
		mapButton.LayoutOrder = i

		-- Make sure all children are visible too
		for _, child in ipairs(mapButton:GetDescendants()) do
			if child:IsA("GuiObject") then
				child.Visible = true
			end
		end

		-- Update labels
		local mapNameLabel = mapButton:FindFirstChild("MapName")
		if mapNameLabel then
			mapNameLabel.Text = mapInfo.Name
			print("LobbyController: Set map name to", mapNameLabel.Text)
		else
			warn("LobbyController: MapName label not found in template")
		end

		local thumbnail = mapButton:FindFirstChild("Thumbnail")
		if thumbnail then
			thumbnail.Image = mapInfo.ImageId
		else
			warn("LobbyController: Thumbnail not found in template")
		end

		-- Connect select button
		local selectButton = mapButton:FindFirstChild("SelectButton")
		if selectButton then
			-- Check if SelectButton has a Button child (like other UI elements)
			local button = selectButton:FindFirstChild("Button")
			if button then
				button.Activated:Connect(function()
					animateButtonPress(mapButton)
					if mapInfo.IsUnlocked then
						print("LobbyController: Map selected:", mapInfo.Name)
						LobbyController.SelectMap(mapInfo.ID)
					else
						print("LobbyController: Map is locked:", mapInfo.Name)
						LobbyController.ShowError("You do not have this map unlocked")
					end
				end)
			else
				-- If no Button child, connect directly to SelectButton
				selectButton.Activated:Connect(function()
					animateButtonPress(mapButton)
					if mapInfo.IsUnlocked then
						print("LobbyController: Map selected:", mapInfo.Name)
						LobbyController.SelectMap(mapInfo.ID)
					else
						print("LobbyController: Map is locked:", mapInfo.Name)
						LobbyController.ShowError("You do not have this map unlocked")
					end
				end)
			end
		else
			warn("LobbyController: SelectButton not found in map template for", mapInfo.Name)
		end

		mapButton.Parent = mapListFrame
		print("LobbyController: Added", mapInfo.Name, "button to MapListFrame")
	end

	print("LobbyController: Finished populating map list")
end

-- Select a map and show its acts
function LobbyController.SelectMap(mapId)
	selectedMapId = mapId
	local map = MapData.GetMapById(mapId)
	if not map then 
		warn("Map not found:", mapId)
		return 
	end

	-- Show acts for this map
	LobbyController.ShowActsForMap(mapId)

	print("Selected map:", map.Name)
end

-- Show acts for a selected map (respects party progress restrictions)
function LobbyController.ShowActsForMap(mapId)
	local mapSelectorUI = gui:FindFirstChild("MapSelectorUI")
	if not mapSelectorUI then return end

	-- Find ActFrame
	local actFrame = mapSelectorUI:FindFirstChild("ActFrame")
	if not actFrame then
		warn("ActFrame not found in MapSelectorUI")
		return
	end

	local actListFrame = actFrame:FindFirstChild("ActListFrame")
	if not actListFrame then
		warn("ActListFrame not found in ActFrame")
		return
	end

	-- Find templates
	local template = actListFrame:FindFirstChild("Template")
	if not template then
		warn("Template not found in ActListFrame")
		return
	end
	
	local lockedTemplate = actListFrame:FindFirstChild("LockedTemplate")
	if not lockedTemplate then
		warn("LobbyController: LockedTemplate not found in ActListFrame, will use Template for locked acts")
	else
		print("LobbyController: Found LockedTemplate for acts")
	end

	-- Clear existing act buttons (except Template, LockedTemplate and UIListLayout)
	for _, child in ipairs(actListFrame:GetChildren()) do
		if child:IsA("GuiObject") and child.Name ~= "Template" and child.Name ~= "LockedTemplate" and not child:IsA("UIListLayout") and not child:IsA("UIGridLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end

	-- Check if player is in a party - use party-restricted acts if so
	local partyInfo = GetPartyInfoFunction:InvokeServer()
	local availableActs
	
	if partyInfo and (partyInfo.inParty or partyInfo.soloInBox) then
		-- In PlayBox - use party-restricted acts
		availableActs = GetPartyActsFunction:InvokeServer(mapId)
		print("LobbyController: Using party acts for", mapId)
	else
		-- Not in PlayBox - use normal acts (get ALL acts, not just unlocked)
		local GetAllActsFunction = ReplicatedStorage.Functions:FindFirstChild("GetAllActs")
		if GetAllActsFunction then
			availableActs = GetAllActsFunction:InvokeServer(mapId)
		else
			-- Fallback to GetAvailableActs if GetAllActs doesn't exist
			local GetAvailableActsFunction = ReplicatedStorage.Functions:WaitForChild("GetAvailableActs")
			availableActs = GetAvailableActsFunction:InvokeServer(mapId)
		end
		print("LobbyController: Using solo acts for", mapId)
	end

	-- Create button for each act
	for i, actData in ipairs(availableActs) do
		-- Use LockedTemplate for locked acts, Template for unlocked
		local templateToUse = template
		if not actData.IsUnlocked and lockedTemplate then
			templateToUse = lockedTemplate
		end
		
		print("LobbyController: Cloning", templateToUse.Name, "for Act", actData.ActNumber, "Unlocked:", actData.IsUnlocked)
		local actButton = templateToUse:Clone()
		actButton.Name = "Act" .. actData.ActNumber
		actButton.Visible = true
		actButton.LayoutOrder = actData.ActNumber

		-- Make sure all children are visible too
		for _, child in ipairs(actButton:GetDescendants()) do
			if child:IsA("GuiObject") then
				child.Visible = true
			end
		end

		-- Update labels (use ActName instead of MapName)
		local actNameLabel = actButton:FindFirstChild("ActName")
		if actNameLabel then
			actNameLabel.Text = "Act " .. actData.ActNumber
			print("LobbyController: Set act name to Act", actData.ActNumber)
		else
			-- Fallback to MapName if ActName doesn't exist
			local mapNameLabel = actButton:FindFirstChild("MapName")
			if mapNameLabel then
				mapNameLabel.Text = "Act " .. actData.ActNumber
			else
				warn("LobbyController: Neither ActName nor MapName label found in template")
			end
		end

		-- Set thumbnail to map's thumbnail (all acts use same image)
		local thumbnail = actButton:FindFirstChild("Thumbnail")
		if thumbnail then
			-- Use the map's thumbnail for all acts
			if actData.MapImageId then
				thumbnail.Image = actData.MapImageId
				print("LobbyController: Set act thumbnail to", actData.MapImageId)
			else
				thumbnail.Image = "rbxassetid://0"
			end

			-- Style based on completion status (only for unlocked template)
			if actData.IsUnlocked and actData.IsCompleted then
				thumbnail.ImageColor3 = Color3.fromRGB(0, 200, 0) -- Green tint for completed
			else
				thumbnail.ImageColor3 = Color3.fromRGB(255, 255, 255) -- Normal color
			end
		else
			warn("LobbyController: Thumbnail not found in template")
		end

		-- Connect select button
		local selectButton = actButton:FindFirstChild("SelectButton")
		if selectButton then
			local button = selectButton:FindFirstChild("Button")
			if button then
				button.Activated:Connect(function()
					animateButtonPress(actButton)
					if actData.IsUnlocked then
						LobbyController.SelectAct(mapId, actData.ActNumber)
					else
						LobbyController.ShowError("You do not have this act unlocked")
					end
				end)
			else
				selectButton.Activated:Connect(function()
					animateButtonPress(actButton)
					if actData.IsUnlocked then
						LobbyController.SelectAct(mapId, actData.ActNumber)
					else
						LobbyController.ShowError("You do not have this act unlocked")
					end
				end)
			end
		end

		actButton.Parent = actListFrame
		print("LobbyController: Added Act", actData.ActNumber, "button to ActListFrame")
	end

	print("LobbyController: Finished populating act list for", mapId)
end

-- Select an act for the map
function LobbyController.SelectAct(mapId, actNumber)
	selectedMapId = mapId
	selectedAct = actNumber

	print("Selected Act", actNumber, "for map", mapId)

	-- Update MapDetailsFrame to show selected act
	local mapSelectorUI = gui:FindFirstChild("MapSelectorUI")
	if mapSelectorUI then
		local detailsFrame = mapSelectorUI:FindFirstChild("MapDetailsFrame", true)
		if detailsFrame then
			-- Make MapDetailsFrame visible
			detailsFrame.Visible = true

			-- Update map name if it exists
			local mapNameLabel = detailsFrame:FindFirstChild("MapName")
			if mapNameLabel then
				local map = MapData.GetMapById(mapId)
				if map then
					mapNameLabel.Text = map.Name
				end
			end

			-- Update ActNumber label
			local actNumberLabel = detailsFrame:FindFirstChild("ActNumber")
			if actNumberLabel then
				actNumberLabel.Text = "Act " .. tostring(actNumber)
				print("LobbyController: Updated ActNumber to", actNumber)
			else
				warn("LobbyController: ActNumber label not found in MapDetailsFrame")
			end

			print("LobbyController: Updated MapDetailsFrame with Act", actNumber, "and set visible")
		else
			warn("LobbyController: MapDetailsFrame not found")
		end
	end
end

-- Teleport to game button (handles both solo and party teleport)
function LobbyController.PlayGame()
	if not selectedMapId then
		warn("No map selected")
		-- Show error message
		if gui:FindFirstChild("ErrorMessage") then
			gui.ErrorMessage.Text = "Please select a map first!"
			gui.ErrorMessage.Visible = true
			task.wait(2)
			gui.ErrorMessage.Visible = false
		end
		return
	end

	-- Check if player is in a party (PlayBox)
	local partyInfo = GetPartyInfoFunction:InvokeServer()
	local success, errorMsg
	
	if partyInfo and (partyInfo.inParty or partyInfo.soloInBox) then
		-- Use party teleport (works for solo in PlayBox too)
		print("LobbyController: Using party teleport for", partyInfo.memberCount or 1, "players")
		success, errorMsg = TeleportPartyFunction:InvokeServer(selectedMapId, selectedAct)
	else
		-- Solo teleport (not in PlayBox)
		print("LobbyController: Using solo teleport")
		success = TeleportToGameFunction:InvokeServer(selectedMapId, selectedAct)
	end
	
	if not success then
		warn("Failed to teleport to game:", errorMsg or "Unknown error")
		if gui:FindFirstChild("ErrorMessage") then
			gui.ErrorMessage.Text = errorMsg or "Failed to teleport. Please try again."
			gui.ErrorMessage.Visible = true
			task.wait(3)
			gui.ErrorMessage.Visible = false
		end
	end
end

--------------------------------------------------------------------------------
-- INVENTORY MODE (Immersive Unit Viewing)
--------------------------------------------------------------------------------

-- Open inventory mode - locks camera, changes environment, hides other UIs
function LobbyController.OpenInventoryMode()
	if inventoryModeActive then return end
	inventoryModeActive = true
	print("LobbyController: Opening inventory mode")
	
	local Lighting = game:GetService("Lighting")
	local camera = workspace.CurrentCamera
	
	-- Save current camera state
	savedInventoryCameraCFrame = camera.CFrame
	savedInventoryCameraType = camera.CameraType
	
	-- Save current sky and atmosphere
	savedSky = Lighting:FindFirstChildOfClass("Sky")
	savedAtmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	
	-- Hide all GUI elements except GemsDisplay, LoadoutUI, and InventoryUI
	hiddenGUIsForInventory = {}
	for _, child in ipairs(gui:GetChildren()) do
		if child:IsA("GuiObject") and child.Visible then
			local name = child.Name
			if name ~= "GemsDisplay" and name ~= "LoadoutUI" and name ~= "InventoryUI" then
				child.Visible = false
				table.insert(hiddenGUIsForInventory, child)
			end
		end
	end
	
	-- Lock camera to position (0, 600, 1200) looking forward and slightly down
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.new(Vector3.new(0, 600, 1200), Vector3.new(0, 400, 0))
	
	-- Switch to SkyUnit (remove SkyNormal first)
	local skyNormal = Lighting:FindFirstChild("SkyNormal")
	if skyNormal then
		skyNormal.Parent = nil -- Temporarily remove
	end
	if savedSky and savedSky ~= skyNormal then
		savedSky.Parent = nil -- Temporarily remove any other sky
	end
	local skyUnit = Lighting:FindFirstChild("SkyUnit")
	if not skyUnit then
		skyUnit = ReplicatedStorage:FindFirstChild("SkyUnit")
		if skyUnit then
			skyUnit = skyUnit:Clone()
		end
	end
	if skyUnit then
		skyUnit.Parent = Lighting
	end
	
	-- Switch to AtmosphereUnit (remove AtmosphereNormal first)
	local atmosphereNormal = Lighting:FindFirstChild("AtmosphereNormal")
	if atmosphereNormal then
		atmosphereNormal.Parent = nil -- Temporarily remove
	end
	if savedAtmosphere and savedAtmosphere ~= atmosphereNormal then
		savedAtmosphere.Parent = nil -- Temporarily remove any other atmosphere
	end
	local atmosphereUnit = Lighting:FindFirstChild("AtmosphereUnit")
	if not atmosphereUnit then
		atmosphereUnit = ReplicatedStorage:FindFirstChild("AtmosphereUnit")
		if atmosphereUnit then
			atmosphereUnit = atmosphereUnit:Clone()
		end
	end
	if atmosphereUnit then
		atmosphereUnit.Parent = Lighting
	end
	
	-- Show inventory UI
	local inventoryUI = gui:FindFirstChild("InventoryUI")
	if inventoryUI then
		inventoryUI.Visible = true
		
		-- Add close button if it doesn't exist
		local closeBtn = inventoryUI:FindFirstChild("CloseInventoryButton")
		if not closeBtn then
			closeBtn = Instance.new("TextButton")
			closeBtn.Name = "CloseInventoryButton"
			closeBtn.Size = UDim2.new(0, 120, 0, 40)
			closeBtn.Position = UDim2.new(1, -130, 0, 10)
			closeBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
			closeBtn.Text = "Close"
			closeBtn.TextColor3 = Color3.new(1, 1, 1)
			closeBtn.TextSize = 18
			closeBtn.Font = Enum.Font.GothamBold
			closeBtn.ZIndex = 10
			closeBtn.Parent = inventoryUI
			
			local closeBtnCorner = Instance.new("UICorner")
			closeBtnCorner.CornerRadius = UDim.new(0, 8)
			closeBtnCorner.Parent = closeBtn
			
			closeBtn.Activated:Connect(function()
				animateButtonPress(closeBtn)
				LobbyController.CloseInventoryMode()
			end)
		end
	end
	
	print("LobbyController: Inventory mode active")
end

-- Close inventory mode - restore camera, environment, and UIs
function LobbyController.CloseInventoryMode()
	if not inventoryModeActive then return end
	inventoryModeActive = false
	print("LobbyController: Closing inventory mode")
	
	local Lighting = game:GetService("Lighting")
	local camera = workspace.CurrentCamera
	
	-- Clean up rotation connection
	if inventoryRotationConnection then
		inventoryRotationConnection:Disconnect()
		inventoryRotationConnection = nil
	end
	inventoryModelRotation = 180 -- Reset rotation
	
	-- Clean up displayed unit model
	if inventoryDisplayModel then
		inventoryDisplayModel:Destroy()
		inventoryDisplayModel = nil
	end
	
	-- Clean up reflection clone
	if inventoryMirrorModel then
		inventoryMirrorModel:Destroy()
		inventoryMirrorModel = nil
	end
	
	-- Hide inventory UI
	if gui:FindFirstChild("InventoryUI") then
		gui.InventoryUI.Visible = false
	end
	
	-- Also close unit details if open
	local detailsUI = gui:FindFirstChild("UnitDetailsUI")
	if detailsUI then
		detailsUI.Visible = false
	end
	currentUnitDetailsId = nil
	
	-- Restore camera
	if savedInventoryCameraType then
		camera.CameraType = savedInventoryCameraType
	else
		camera.CameraType = Enum.CameraType.Custom
	end
	if savedInventoryCameraCFrame then
		camera.CFrame = savedInventoryCameraCFrame
	end
	
	-- Remove SkyUnit and restore SkyNormal
	local skyUnit = Lighting:FindFirstChild("SkyUnit")
	if skyUnit then
		skyUnit.Parent = nil
	end
	-- Restore SkyNormal
	local skyNormal = Lighting:FindFirstChild("SkyNormal")
	if not skyNormal then
		skyNormal = ReplicatedStorage:FindFirstChild("SkyNormal")
		if skyNormal then
			skyNormal = skyNormal:Clone()
		end
	end
	if skyNormal then
		skyNormal.Parent = Lighting
	end
	-- Also restore saved sky if it was different
	if savedSky and savedSky.Name ~= "SkyNormal" and savedSky.Name ~= "SkyUnit" then
		savedSky.Parent = Lighting
	end
	
	-- Remove AtmosphereUnit and restore AtmosphereNormal
	local atmosphereUnit = Lighting:FindFirstChild("AtmosphereUnit")
	if atmosphereUnit then
		atmosphereUnit.Parent = nil
	end
	-- Restore AtmosphereNormal
	local atmosphereNormal = Lighting:FindFirstChild("AtmosphereNormal")
	if not atmosphereNormal then
		atmosphereNormal = ReplicatedStorage:FindFirstChild("AtmosphereNormal")
		if atmosphereNormal then
			atmosphereNormal = atmosphereNormal:Clone()
		end
	end
	if atmosphereNormal then
		atmosphereNormal.Parent = Lighting
	end
	-- Also restore saved atmosphere if it was different
	if savedAtmosphere and savedAtmosphere.Name ~= "AtmosphereNormal" and savedAtmosphere.Name ~= "AtmosphereUnit" then
		savedAtmosphere.Parent = Lighting
	end
	
	-- Restore hidden GUI elements
	for _, guiElement in ipairs(hiddenGUIsForInventory) do
		if guiElement and guiElement.Parent then
			guiElement.Visible = true
		end
	end
	hiddenGUIsForInventory = {}
	
	-- Clear saved states
	savedInventoryCameraCFrame = nil
	savedInventoryCameraType = nil
	savedSky = nil
	savedAtmosphere = nil
	
	print("LobbyController: Inventory mode closed")
end

-- Toggle inventory mode
function LobbyController.ToggleInventoryMode()
	if inventoryModeActive then
		LobbyController.CloseInventoryMode()
	else
		LobbyController.OpenInventoryMode()
	end
end

--------------------------------------------------------------------------------
-- UNIT DETAILS UI
--------------------------------------------------------------------------------

-- Open unit details panel
function LobbyController.OpenUnitDetails(instanceId)
	print("LobbyController: OpenUnitDetails called for", instanceId)
	currentUnitDetailsId = instanceId
	
	if not GetUnitDetailsFunction then
		warn("LobbyController: GetUnitDetailsFunction not available")
		return
	end
	
	local result = GetUnitDetailsFunction:InvokeServer(instanceId)
	if not result or not result.Success then
		warn("LobbyController: Failed to get unit details:", result and result.Error or "Unknown error")
		LobbyController.ShowError(result and result.Error or "Failed to load unit details")
		return
	end
	
	local unitData = result.Unit
	local tower = TowerData.GetTowerById(unitData.UnitId)
	if not tower then
		warn("LobbyController: Tower data not found for", unitData.UnitId)
		return
	end
	
	-- Find or create UnitDetailsUI
	local detailsUI = gui:FindFirstChild("UnitDetailsUI")
	if not detailsUI then
		print("LobbyController: UnitDetailsUI not found, creating dynamically")
		detailsUI = LobbyController.CreateUnitDetailsUI()
	end
	
	if not detailsUI then
		warn("LobbyController: Could not create UnitDetailsUI")
		return
	end
	
	-- Populate unit info
	local unitName = detailsUI:FindFirstChild("UnitName")
	if unitName then unitName.Text = tower.Name end
	
	local unitRarity = detailsUI:FindFirstChild("UnitRarity")
	if unitRarity then
		unitRarity.Text = unitData.Rarity or tower.Rarity
		unitRarity.TextColor3 = TowerData.Rarities[unitData.Rarity or tower.Rarity].Color
	end
	
	-- Populate traits section
	LobbyController.PopulateTraitsSection(detailsUI, instanceId, result)
	
	-- Populate relics section
	LobbyController.PopulateRelicsSection(detailsUI, instanceId, unitData)
	
	-- Populate evolution section
	LobbyController.PopulateEvolutionSection(detailsUI, instanceId, result)
	
	-- Show the UI
	detailsUI.Visible = true
end

-- Create unit details UI dynamically (if not present in Studio)
function LobbyController.CreateUnitDetailsUI()
	local detailsUI = Instance.new("Frame")
	detailsUI.Name = "UnitDetailsUI"
	detailsUI.Size = UDim2.new(0.8, 0, 0.85, 0)
	detailsUI.Position = UDim2.new(0.1, 0, 0.075, 0)
	detailsUI.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	detailsUI.BorderSizePixel = 0
	detailsUI.Visible = false
	detailsUI.Parent = gui
	
	-- Add corner radius
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = detailsUI
	
	-- Title bar
	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.Size = UDim2.new(1, 0, 0, 50)
	titleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
	titleBar.BorderSizePixel = 0
	titleBar.Parent = detailsUI
	
	local titleCorner = Instance.new("UICorner")
	titleCorner.CornerRadius = UDim.new(0, 12)
	titleCorner.Parent = titleBar
	
	local unitName = Instance.new("TextLabel")
	unitName.Name = "UnitName"
	unitName.Size = UDim2.new(0.6, 0, 1, 0)
	unitName.Position = UDim2.new(0.05, 0, 0, 0)
	unitName.BackgroundTransparency = 1
	unitName.Text = "Unit Name"
	unitName.TextColor3 = Color3.new(1, 1, 1)
	unitName.TextSize = 24
	unitName.Font = Enum.Font.GothamBold
	unitName.TextXAlignment = Enum.TextXAlignment.Left
	unitName.Parent = titleBar
	
	local unitRarity = Instance.new("TextLabel")
	unitRarity.Name = "UnitRarity"
	unitRarity.Size = UDim2.new(0.25, 0, 1, 0)
	unitRarity.Position = UDim2.new(0.65, 0, 0, 0)
	unitRarity.BackgroundTransparency = 1
	unitRarity.Text = "Rarity"
	unitRarity.TextColor3 = Color3.fromRGB(255, 215, 0)
	unitRarity.TextSize = 20
	unitRarity.Font = Enum.Font.GothamBold
	unitRarity.Parent = titleBar
	
	-- Close button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 40, 0, 40)
	closeBtn.Position = UDim2.new(1, -45, 0, 5)
	closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.TextSize = 20
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Parent = titleBar
	
	local closeBtnCorner = Instance.new("UICorner")
	closeBtnCorner.CornerRadius = UDim.new(0, 8)
	closeBtnCorner.Parent = closeBtn
	
	closeBtn.Activated:Connect(function()
		animateButtonPress(closeBtn)
		detailsUI.Visible = false
		currentUnitDetailsId = nil
	end)
	
	-- Content area with tabs
	local contentArea = Instance.new("Frame")
	contentArea.Name = "ContentArea"
	contentArea.Size = UDim2.new(1, -20, 1, -70)
	contentArea.Position = UDim2.new(0, 10, 0, 60)
	contentArea.BackgroundTransparency = 1
	contentArea.Parent = detailsUI
	
	-- Tab buttons
	local tabBar = Instance.new("Frame")
	tabBar.Name = "TabBar"
	tabBar.Size = UDim2.new(1, 0, 0, 40)
	tabBar.BackgroundTransparency = 1
	tabBar.Parent = contentArea
	
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 10)
	tabLayout.Parent = tabBar
	
	local tabs = {"Traits", "Relics", "Evolution"}
	local tabFrames = {}
	
	for i, tabName in ipairs(tabs) do
		local tabBtn = Instance.new("TextButton")
		tabBtn.Name = tabName .. "Tab"
		tabBtn.Size = UDim2.new(0, 120, 1, 0)
		tabBtn.BackgroundColor3 = i == 1 and Color3.fromRGB(80, 80, 120) or Color3.fromRGB(50, 50, 70)
		tabBtn.Text = tabName
		tabBtn.TextColor3 = Color3.new(1, 1, 1)
		tabBtn.TextSize = 16
		tabBtn.Font = Enum.Font.GothamBold
		tabBtn.Parent = tabBar
		
		local tabBtnCorner = Instance.new("UICorner")
		tabBtnCorner.CornerRadius = UDim.new(0, 8)
		tabBtnCorner.Parent = tabBtn
		
		-- Create tab content frame
		local tabFrame = Instance.new("ScrollingFrame")
		tabFrame.Name = tabName .. "Frame"
		tabFrame.Size = UDim2.new(1, 0, 1, -50)
		tabFrame.Position = UDim2.new(0, 0, 0, 45)
		tabFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
		tabFrame.BorderSizePixel = 0
		tabFrame.ScrollBarThickness = 6
		tabFrame.Visible = i == 1
		tabFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
		tabFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
		tabFrame.Parent = contentArea
		
		local tabFrameCorner = Instance.new("UICorner")
		tabFrameCorner.CornerRadius = UDim.new(0, 8)
		tabFrameCorner.Parent = tabFrame
		
		local tabPadding = Instance.new("UIPadding")
		tabPadding.PaddingAll = UDim.new(0, 10)
		tabPadding.Parent = tabFrame
		
		local tabListLayout = Instance.new("UIListLayout")
		tabListLayout.Padding = UDim.new(0, 8)
		tabListLayout.Parent = tabFrame
		
		tabFrames[tabName] = tabFrame
		
		tabBtn.Activated:Connect(function()
			animateButtonPress(tabBtn)
			-- Hide all tab frames and reset button colors
			for _, frame in pairs(tabFrames) do
				frame.Visible = false
			end
			for _, btn in ipairs(tabBar:GetChildren()) do
				if btn:IsA("TextButton") then
					btn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
				end
			end
			-- Show selected tab
			tabFrame.Visible = true
			tabBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 120)
		end)
	end
	
	return detailsUI
end

-- Populate traits section
function LobbyController.PopulateTraitsSection(detailsUI, instanceId, result)
	local traitsFrame = detailsUI:FindFirstChild("TraitsFrame", true)
	if not traitsFrame then return end
	
	-- Clear existing trait items
	for _, child in ipairs(traitsFrame:GetChildren()) do
		if child:IsA("Frame") and child.Name ~= "Template" then
			child:Destroy()
		end
	end
	
	local unitData = result.Unit
	local traits = unitData.Traits or {}
	local traitDescriptions = result.TraitDescriptions or {}
	
	if #traits == 0 then
		local noTraits = Instance.new("TextLabel")
		noTraits.Name = "NoTraits"
		noTraits.Size = UDim2.new(1, 0, 0, 40)
		noTraits.BackgroundTransparency = 1
		noTraits.Text = "This unit has no traits"
		noTraits.TextColor3 = Color3.fromRGB(150, 150, 150)
		noTraits.TextSize = 16
		noTraits.Font = Enum.Font.Gotham
		noTraits.Parent = traitsFrame
		return
	end
	
	for i, traitName in ipairs(traits) do
		local traitData = TraitSystem.GetTrait(traitName)
		local description = traitDescriptions[traitName] or (traitData and traitData.Description) or "No description"
		
		local traitItem = Instance.new("Frame")
		traitItem.Name = "Trait_" .. i
		traitItem.Size = UDim2.new(1, 0, 0, 70)
		traitItem.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
		traitItem.BorderSizePixel = 0
		traitItem.Parent = traitsFrame
		
		local traitCorner = Instance.new("UICorner")
		traitCorner.CornerRadius = UDim.new(0, 8)
		traitCorner.Parent = traitItem
		
		local traitNameLabel = Instance.new("TextLabel")
		traitNameLabel.Name = "TraitName"
		traitNameLabel.Size = UDim2.new(0.6, 0, 0, 25)
		traitNameLabel.Position = UDim2.new(0.02, 0, 0.1, 0)
		traitNameLabel.BackgroundTransparency = 1
		traitNameLabel.Text = traitName
		traitNameLabel.TextColor3 = traitData and GameConfig.GetRarityColor(traitData.Rarity) or Color3.new(1, 1, 1)
		traitNameLabel.TextSize = 18
		traitNameLabel.Font = Enum.Font.GothamBold
		traitNameLabel.TextXAlignment = Enum.TextXAlignment.Left
		traitNameLabel.Parent = traitItem
		
		local traitDesc = Instance.new("TextLabel")
		traitDesc.Name = "TraitDesc"
		traitDesc.Size = UDim2.new(0.7, 0, 0, 25)
		traitDesc.Position = UDim2.new(0.02, 0, 0.55, 0)
		traitDesc.BackgroundTransparency = 1
		traitDesc.Text = description
		traitDesc.TextColor3 = Color3.fromRGB(180, 180, 180)
		traitDesc.TextSize = 14
		traitDesc.Font = Enum.Font.Gotham
		traitDesc.TextXAlignment = Enum.TextXAlignment.Left
		traitDesc.Parent = traitItem
		
		-- Reroll button
		local rerollBtn = Instance.new("TextButton")
		rerollBtn.Name = "RerollButton"
		rerollBtn.Size = UDim2.new(0, 80, 0, 35)
		rerollBtn.Position = UDim2.new(1, -90, 0.5, -17)
		rerollBtn.BackgroundColor3 = Color3.fromRGB(100, 80, 180)
		rerollBtn.Text = "Reroll"
		rerollBtn.TextColor3 = Color3.new(1, 1, 1)
		rerollBtn.TextSize = 14
		rerollBtn.Font = Enum.Font.GothamBold
		rerollBtn.Parent = traitItem
		
		local rerollCorner = Instance.new("UICorner")
		rerollCorner.CornerRadius = UDim.new(0, 6)
		rerollCorner.Parent = rerollBtn
		
		local currentTraitName = traitName
		rerollBtn.Activated:Connect(function()
			animateButtonPress(rerollBtn)
			LobbyController.RerollTrait(instanceId, currentTraitName)
		end)
	end
end

-- Populate relics section
function LobbyController.PopulateRelicsSection(detailsUI, instanceId, unitData)
	local relicsFrame = detailsUI:FindFirstChild("RelicsFrame", true)
	if not relicsFrame then return end
	
	-- Clear existing relic items
	for _, child in ipairs(relicsFrame:GetChildren()) do
		if child:IsA("Frame") and child.Name ~= "Template" then
			child:Destroy()
		end
	end
	
	local equippedRelics = unitData.EquippedRelics or {}
	
	-- Show slots
	for _, slotName in ipairs(RelicSystem.Slots) do
		local slotFrame = Instance.new("Frame")
		slotFrame.Name = "Slot_" .. slotName
		slotFrame.Size = UDim2.new(1, 0, 0, 80)
		slotFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
		slotFrame.BorderSizePixel = 0
		slotFrame.Parent = relicsFrame
		
		local slotCorner = Instance.new("UICorner")
		slotCorner.CornerRadius = UDim.new(0, 8)
		slotCorner.Parent = slotFrame
		
		local slotLabel = Instance.new("TextLabel")
		slotLabel.Name = "SlotName"
		slotLabel.Size = UDim2.new(0.25, 0, 1, 0)
		slotLabel.BackgroundTransparency = 1
		slotLabel.Text = slotName
		slotLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		slotLabel.TextSize = 16
		slotLabel.Font = Enum.Font.GothamBold
		slotLabel.Parent = slotFrame
		
		local relicId = equippedRelics[slotName]
		if relicId then
			-- Show equipped relic
			local relicInfo = Instance.new("TextLabel")
			relicInfo.Name = "RelicInfo"
			relicInfo.Size = UDim2.new(0.5, 0, 1, 0)
			relicInfo.Position = UDim2.new(0.25, 0, 0, 0)
			relicInfo.BackgroundTransparency = 1
			relicInfo.Text = "Equipped: " .. relicId:sub(1, 8) .. "..."
			relicInfo.TextColor3 = Color3.fromRGB(100, 200, 100)
			relicInfo.TextSize = 14
			relicInfo.Font = Enum.Font.Gotham
			relicInfo.Parent = slotFrame
			
			-- Unequip button
			local unequipBtn = Instance.new("TextButton")
			unequipBtn.Name = "UnequipButton"
			unequipBtn.Size = UDim2.new(0, 80, 0, 35)
			unequipBtn.Position = UDim2.new(1, -90, 0.5, -17)
			unequipBtn.BackgroundColor3 = Color3.fromRGB(180, 80, 80)
			unequipBtn.Text = "Unequip"
			unequipBtn.TextColor3 = Color3.new(1, 1, 1)
			unequipBtn.TextSize = 14
			unequipBtn.Font = Enum.Font.GothamBold
			unequipBtn.Parent = slotFrame
			
			local unequipCorner = Instance.new("UICorner")
			unequipCorner.CornerRadius = UDim.new(0, 6)
			unequipCorner.Parent = unequipBtn
			
			local currentSlot = slotName
			unequipBtn.Activated:Connect(function()
				animateButtonPress(unequipBtn)
				LobbyController.UnequipRelic(instanceId, currentSlot)
			end)
		else
			-- Show empty slot
			local emptyLabel = Instance.new("TextLabel")
			emptyLabel.Name = "EmptyLabel"
			emptyLabel.Size = UDim2.new(0.5, 0, 1, 0)
			emptyLabel.Position = UDim2.new(0.25, 0, 0, 0)
			emptyLabel.BackgroundTransparency = 1
			emptyLabel.Text = "Empty"
			emptyLabel.TextColor3 = Color3.fromRGB(100, 100, 100)
			emptyLabel.TextSize = 14
			emptyLabel.Font = Enum.Font.Gotham
			emptyLabel.Parent = slotFrame
			
			-- Equip button (opens relic selection)
			local equipBtn = Instance.new("TextButton")
			equipBtn.Name = "EquipButton"
			equipBtn.Size = UDim2.new(0, 80, 0, 35)
			equipBtn.Position = UDim2.new(1, -90, 0.5, -17)
			equipBtn.BackgroundColor3 = Color3.fromRGB(80, 120, 180)
			equipBtn.Text = "Equip"
			equipBtn.TextColor3 = Color3.new(1, 1, 1)
			equipBtn.TextSize = 14
			equipBtn.Font = Enum.Font.GothamBold
			equipBtn.Parent = slotFrame
			
			local equipCorner = Instance.new("UICorner")
			equipCorner.CornerRadius = UDim.new(0, 6)
			equipCorner.Parent = equipBtn
			
			local currentSlot = slotName
			equipBtn.Activated:Connect(function()
				animateButtonPress(equipBtn)
				LobbyController.OpenRelicSelection(instanceId, currentSlot)
			end)
		end
	end
end

-- Populate evolution section
function LobbyController.PopulateEvolutionSection(detailsUI, instanceId, result)
	local evolutionFrame = detailsUI:FindFirstChild("EvolutionFrame", true)
	if not evolutionFrame then return end
	
	-- Clear existing items
	for _, child in ipairs(evolutionFrame:GetChildren()) do
		if child:IsA("Frame") and child.Name ~= "Template" then
			child:Destroy()
		end
	end
	
	local unitData = result.Unit
	local evolutionData = result.EvolutionData
	local canEvolve = result.CanEvolve
	local evolveReason = result.EvolveReason
	local nextStageXP = result.NextStageXP
	
	-- Current stage info
	local stageInfo = Instance.new("Frame")
	stageInfo.Name = "StageInfo"
	stageInfo.Size = UDim2.new(1, 0, 0, 100)
	stageInfo.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
	stageInfo.BorderSizePixel = 0
	stageInfo.Parent = evolutionFrame
	
	local stageCorner = Instance.new("UICorner")
	stageCorner.CornerRadius = UDim.new(0, 8)
	stageCorner.Parent = stageInfo
	
	local stageName = Instance.new("TextLabel")
	stageName.Name = "StageName"
	stageName.Size = UDim2.new(1, 0, 0, 30)
	stageName.Position = UDim2.new(0, 0, 0.1, 0)
	stageName.BackgroundTransparency = 1
	stageName.Text = "Stage: " .. (evolutionData and evolutionData.Name or "Base") .. " (" .. (unitData.EvolutionStage or 0) .. ")"
	stageName.TextColor3 = Color3.new(1, 1, 1)
	stageName.TextSize = 20
	stageName.Font = Enum.Font.GothamBold
	stageName.Parent = stageInfo
	
	local xpLabel = Instance.new("TextLabel")
	xpLabel.Name = "XPLabel"
	xpLabel.Size = UDim2.new(1, 0, 0, 25)
	xpLabel.Position = UDim2.new(0, 0, 0.45, 0)
	xpLabel.BackgroundTransparency = 1
	xpLabel.Text = "XP: " .. (unitData.XP or 0) .. (nextStageXP and (" / " .. nextStageXP) or " (MAX)")
	xpLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	xpLabel.TextSize = 16
	xpLabel.Font = Enum.Font.Gotham
	xpLabel.Parent = stageInfo
	
	-- Evolve button
	local evolveBtn = Instance.new("TextButton")
	evolveBtn.Name = "EvolveButton"
	evolveBtn.Size = UDim2.new(0.4, 0, 0, 40)
	evolveBtn.Position = UDim2.new(0.3, 0, 0.7, 0)
	evolveBtn.BackgroundColor3 = canEvolve and Color3.fromRGB(80, 180, 80) or Color3.fromRGB(80, 80, 80)
	evolveBtn.Text = canEvolve and "Evolve!" or (evolveReason or "Cannot Evolve")
	evolveBtn.TextColor3 = Color3.new(1, 1, 1)
	evolveBtn.TextSize = 16
	evolveBtn.Font = Enum.Font.GothamBold
	evolveBtn.Parent = stageInfo
	
	local evolveBtnCorner = Instance.new("UICorner")
	evolveBtnCorner.CornerRadius = UDim.new(0, 8)
	evolveBtnCorner.Parent = evolveBtn
	
	if canEvolve then
		evolveBtn.Activated:Connect(function()
			animateButtonPress(evolveBtn)
			LobbyController.EvolveUnit(instanceId)
		end)
	end
end

-- Reroll a trait
function LobbyController.RerollTrait(instanceId, traitName)
	print("LobbyController: Rerolling trait", traitName, "for unit", instanceId)
	
	if not RerollTraitFunction then
		LobbyController.ShowError("Trait reroll not available")
		return
	end
	
	local result = RerollTraitFunction:InvokeServer(instanceId, traitName)
	if result.Success then
		print("LobbyController: Trait rerolled successfully")
		-- Refresh the unit details
		LobbyController.OpenUnitDetails(instanceId)
		-- Refresh inventory to show updated traits
		LobbyController.LoadInventory()
	else
		LobbyController.ShowError(result.Error or "Failed to reroll trait")
	end
end

-- Open relic selection for a slot
function LobbyController.OpenRelicSelection(instanceId, slot)
	print("LobbyController: Opening relic selection for slot", slot)
	
	if not GetRelicInventoryFunction then
		LobbyController.ShowError("Relic system not available")
		return
	end
	
	local relics = GetRelicInventoryFunction:InvokeServer()
	
	-- Filter relics for this slot
	local availableRelics = {}
	for _, relic in ipairs(relics) do
		if relic.Slot == slot then
			table.insert(availableRelics, relic)
		end
	end
	
	if #availableRelics == 0 then
		LobbyController.ShowError("No relics available for " .. slot .. " slot")
		return
	end
	
	-- For now, just equip the first available relic
	-- TODO: Create a proper selection UI
	local result = EquipRelicFunction:InvokeServer(instanceId, availableRelics[1].ID)
	if result.Success then
		print("LobbyController: Relic equipped successfully")
		LobbyController.OpenUnitDetails(instanceId)
	else
		LobbyController.ShowError(result.Error or "Failed to equip relic")
	end
end

-- Unequip a relic
function LobbyController.UnequipRelic(instanceId, slot)
	print("LobbyController: Unequipping relic from slot", slot)
	
	if not UnequipRelicFunction then
		LobbyController.ShowError("Relic system not available")
		return
	end
	
	local result = UnequipRelicFunction:InvokeServer(instanceId, slot)
	if result.Success then
		print("LobbyController: Relic unequipped successfully")
		LobbyController.OpenUnitDetails(instanceId)
	else
		LobbyController.ShowError(result.Error or "Failed to unequip relic")
	end
end

-- Evolve a unit
function LobbyController.EvolveUnit(instanceId)
	print("LobbyController: Evolving unit", instanceId)
	
	if not EvolveUnitFunction then
		LobbyController.ShowError("Evolution not available")
		return
	end
	
	local result = EvolveUnitFunction:InvokeServer(instanceId)
	if result.Success then
		print("LobbyController: Unit evolved to stage", result.NewStage)
		LobbyController.OpenUnitDetails(instanceId)
		-- Refresh inventory to show updated evolution stage
		LobbyController.LoadInventory()
	else
		LobbyController.ShowError(result.Error or "Failed to evolve unit")
	end
end

-- Initialize
function LobbyController.Initialize()
	-- Wait for player data to load
	local playerData = player:WaitForChild("PlayerData")

	-- Setup gem display updates
	local gems = playerData:WaitForChild("Gems")
	gems.Changed:Connect(UpdateGemsDisplay)
	UpdateGemsDisplay()

	-- Setup pity display updates
	local pityCounter = playerData:WaitForChild("PityCounter")
	pityCounter.Changed:Connect(UpdatePityDisplay)
	UpdatePityDisplay()

	-- Connect UI buttons (you'll create these in the UI)
	if gui:FindFirstChild("SummonUI") then
		local summonUI = gui.SummonUI
		print("LobbyController: Found SummonUI")

		local singleButton = summonUI:FindFirstChild("SingleSummonButton")
		if singleButton then
			print("LobbyController: Connected SingleSummonButton")
			singleButton.Activated:Connect(function()
				animateButtonPress(singleButton)
				print("LobbyController: SingleSummonButton clicked!")
				LobbyController.SingleSummon()
			end)
		else
			warn("LobbyController: SingleSummonButton not found in SummonUI")
		end

		local multiButton = summonUI:FindFirstChild("MultiSummonButton")
		if multiButton then
			print("LobbyController: Connected MultiSummonButton")
			multiButton.Activated:Connect(function()
				animateButtonPress(multiButton)
				print("LobbyController: MultiSummonButton clicked!")
				LobbyController.MultiSummon()
			end)
		else
			warn("LobbyController: MultiSummonButton not found in SummonUI")
		end
	else
		warn("LobbyController: SummonUI not found")
	end

	if gui:FindFirstChild("PlayButton") then
		print("LobbyController: Connected PlayButton")
		local playBtn = gui.PlayButton
		playBtn.Button.Activated:Connect(function()
			animateButtonPress(playBtn)
			print("LobbyController: PlayButton clicked!")
			LobbyController.OpenMapSelector()  -- Opens map selector instead of direct teleport
		end)
	else
		warn("LobbyController: PlayButton not found")
	end

	if gui:FindFirstChild("InventoryButton", true) then
		print("LobbyController: Connected InventoryButton")
		local invBtn = gui.Buttons.InventoryButton
		invBtn.Button.Activated:Connect(function()
			animateButtonPress(invBtn)
			print("LobbyController: InventoryButton clicked!")
			-- Toggle immersive inventory mode
			LobbyController.ToggleInventoryMode()
		end)
	else
		warn("LobbyController: InventoryButton not found")
	end

	-- Toggle SummonUI button
	if gui:FindFirstChild("SummonButton", true) then
		print("LobbyController: Connected SummonButton")
		local summonBtn = gui.Buttons.SummonButton
		summonBtn.Button.Activated:Connect(function()
			animateButtonPress(summonBtn)
			print("LobbyController: SummonButton clicked!")
			local summonUI = gui:FindFirstChild("SummonUI")
			if summonUI then
				summonUI.Visible = not summonUI.Visible

				-- Hide Gems and Loadout when opening SummonUI
				if summonUI.Visible then
					if gui:FindFirstChild("GemsDisplay") then
						gui.GemsDisplay.Visible = false
					end
					if gui:FindFirstChild("LoadoutUI") then
						gui.LoadoutUI.Visible = false
					end
				else
					-- Show Gems and Loadout when closing SummonUI
					if gui:FindFirstChild("GemsDisplay") then
						gui.GemsDisplay.Visible = true
					end
					if gui:FindFirstChild("LoadoutUI") then
						gui.LoadoutUI.Visible = true
					end
				end
			end
		end)
	else
		warn("LobbyController: SummonButton not found (optional)")
	end

	-- Close button for SummonUI
	local summonUI = gui:FindFirstChild("SummonUI")
	if summonUI then
		local closeButton = summonUI:FindFirstChild("CloseButton")
		if closeButton then
			print("LobbyController: Connected SummonUI CloseButton")
			closeButton.Activated:Connect(function()
				animateButtonPress(closeButton)
				print("LobbyController: SummonUI CloseButton clicked!")

				-- Clean up any active summon result first
				HideSummonResult()

				summonUI.Visible = false

				-- Show Gems and Loadout when closing SummonUI
				if gui:FindFirstChild("GemsDisplay") then
					gui.GemsDisplay.Visible = true
				end
				if gui:FindFirstChild("LoadoutUI") then
					gui.LoadoutUI.Visible = true
				end
			end)
		else
			warn("LobbyController: CloseButton not found in SummonUI")
		end
	end

	-- Load loadout on initialization
	LobbyController.LoadLoadout()

	-- Preload inventory on initialization to prevent freezing
	print("LobbyController: Preloading inventory...")
	LobbyController.LoadInventory()
	-- Hide inventory after preloading
	if gui:FindFirstChild("InventoryUI") then
		gui.InventoryUI.Visible = false
	end
	print("LobbyController: Inventory preloaded")

	-- Hide LoadoutUI and GemsDisplay if SummonUI is initially visible
	local summonUI = gui:FindFirstChild("SummonUI")
	if summonUI and summonUI.Visible then
		if gui:FindFirstChild("LoadoutUI") then
			gui.LoadoutUI.Visible = false
		end
		if gui:FindFirstChild("GemsDisplay") then
			gui.GemsDisplay.Visible = false
		end
	end

	-- Connect MapSelectorUI buttons
	local mapSelectorUI = gui:FindFirstChild("MapSelectorUI")
	if mapSelectorUI then
		print("LobbyController: Found MapSelectorUI")

		-- MapDetailsFrame PlayButton
		local detailsFrame = mapSelectorUI:FindFirstChild("MapDetailsFrame", true)
		if detailsFrame then
			local playBtn = mapSelectorUI:FindFirstChild("PlayButton")
			if playBtn then
				print("LobbyController: Connected MapDetailsFrame PlayButton")
				playBtn.Button.Activated:Connect(function()
					animateButtonPress(playBtn)
					print("LobbyController: Starting game with map:", selectedMapId)
					LobbyController.PlayGame()
				end)
			else
				warn("LobbyController: PlayButton not found in MapDetailsFrame")
			end
		else
			warn("LobbyController: MapDetailsFrame not found")
		end

		-- Close button
		local closeBtn = mapSelectorUI:FindFirstChild("CloseButton")
		if closeBtn then
			print("LobbyController: Connected MapSelectorUI CloseButton")
			closeBtn.Activated:Connect(function()
				animateButtonPress(closeBtn)
				print("LobbyController: Closing MapSelectorUI")
				mapSelectorUI.Visible = false
				selectedMapId = nil
				-- Hide details frame
				if detailsFrame then
					detailsFrame.Visible = false
				end
			end)
		else
			warn("LobbyController: CloseButton not found in MapSelectorUI")
		end
	else
		warn("LobbyController: MapSelectorUI not found")
	end

	print("Lobby controller initialized")
	
	-- Preload inventory mode assets in background
	task.spawn(function()
		print("LobbyController: Preloading inventory assets...")
		local assetsToPreload = {}
		
		-- Preload inventory animation
		local inventoryAnimation = Instance.new("Animation")
		inventoryAnimation.AnimationId = "rbxassetid://74802924296512"
		table.insert(assetsToPreload, inventoryAnimation)
		
		-- Preload all tower models
		local towersFolder = ReplicatedStorage:FindFirstChild("Towers")
		if towersFolder then
			for _, model in ipairs(towersFolder:GetChildren()) do
				table.insert(assetsToPreload, model)
			end
		end
		
		ContentProvider:PreloadAsync(assetsToPreload)
		print("LobbyController: Inventory assets preloaded")
	end)
end

-- Auto-initialize
LobbyController.Initialize()

return LobbyController
