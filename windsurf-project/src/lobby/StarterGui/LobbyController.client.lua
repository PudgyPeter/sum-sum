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
local ColorTypeSystem = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ColorTypeSystem"))
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
local SellUnitsFunction = nil
local LockUnitFunction = nil

-- Load unit management functions in background (don't block main thread)
task.spawn(function()
	GetUnitDetailsFunction = functions:WaitForChild("GetUnitDetails", 30)
	RerollTraitFunction = functions:WaitForChild("RerollTrait", 30)
	GetRelicInventoryFunction = functions:WaitForChild("GetRelicInventory", 30)
	EquipRelicFunction = functions:WaitForChild("EquipRelic", 30)
	UnequipRelicFunction = functions:WaitForChild("UnequipRelic", 30)
	EvolveUnitFunction = functions:WaitForChild("EvolveUnit", 30)
	GetEvolutionInfoFunction = functions:WaitForChild("GetEvolutionInfo", 30)
	SellUnitsFunction = functions:WaitForChild("SellUnits", 30)
	LockUnitFunction = functions:WaitForChild("LockUnit", 30)
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
local savedClockTime = nil
local hiddenGUIsForInventory = {}
local inventoryDisplayModel = nil -- Currently displayed unit model in inventory mode
local inventoryMirrorModel = nil -- Cloned model for reflection (upside-down)
local inventoryFeetToRoot = 0 -- Distance from root to feet (calculated per model)
local reflectionRippleConnection = nil -- Connection for subtle water ripple on reflection
local inventoryDepthOfField = nil -- DepthOfField effect for inventory mode
local inventoryModelRotation = 160 -- Current Y rotation in degrees (200 = slightly facing left)

-- Sell mode state variables
local sellModeActive = false
local unitsToSell = {} -- Table of instanceIds marked for selling
local SELL_DOLLAR_IMAGE = "rbxassetid://134048766914445"

-- Side button state (for Overview and future buttons)
local sideButtonStates = {}

-- Inventory tab animation/camera state
local inventoryAnimator = nil
local inventoryCurrentAnimTrack = nil
local reflectionAnimator = nil
local reflectionCurrentAnimTrack = nil
local animSwitchVersion = 0
local currentInventoryTab = "Overview"

-- Tab camera angles (tweakable)
local INVENTORY_MODEL_POS = Vector3.new(0.664, 598.971, 1195.967)
local TAB_CAMERAS = {
	Overview  = CFrame.new(Vector3.new(0, 600, 1200), Vector3.new(0, 400, 0)),
	Relics    = CFrame.new(INVENTORY_MODEL_POS + Vector3.new(2, 3, -4), INVENTORY_MODEL_POS + Vector3.new(-2, -1, 0)),
	Traits    = CFrame.new(INVENTORY_MODEL_POS + Vector3.new(-3, 0, 3), INVENTORY_MODEL_POS + Vector3.new(0, 0, 0)),
	Evolution = CFrame.new(Vector3.new(0, 600, 1200), Vector3.new(0, 400, 0)), -- placeholder
}

-- Tab idle animations (looping pose per tab)
local DEFAULT_IDLE_ANIM = "rbxassetid://74802924296512"
local TAB_IDLE_ANIMS = {
	Overview  = "rbxassetid://97922180101608",
	Relics    = "rbxassetid://140408577984265",
	Traits    = DEFAULT_IDLE_ANIM, -- TODO: set idle anim
	Evolution = DEFAULT_IDLE_ANIM, -- TODO: set idle anim
}

-- Directional transition animations: [from][to] = animId (plays once before idle)
-- Set to nil for no transition (jumps straight to idle)
local TAB_TRANSITIONS = {
	Overview = {
		Relics = "rbxassetid://123151035779597", -- TODO: set anim
		Traits = nil, -- TODO: set anim
	},
	Relics = {
		Overview = "rbxassetid://125922138724815", -- TODO: set anim
		Traits   = nil, -- TODO: set anim
	},
	Traits = {
		Overview = nil, -- TODO: set anim
		Relics   = nil, -- TODO: set anim
	},
}

-- Format large numbers with K/M suffix
local function FormatNumber(num)
	if num >= 1000000 then
		return string.format("%.1fM", num / 1000000)
	elseif num >= 1000 then
		return string.format("%.0fK", num / 1000)
	else
		return tostring(num)
	end
end

-- Update Swap button visibility on all loadout slots
local function UpdateSwapButtonVisibility()
	local loadoutFrame = gui:FindFirstChild("LoadoutFrame")
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

-- Create ripple effect on water surface
local function CreateRippleEffect(position)
	local waterY = position.Y - 2 -- HumanoidRootPart is ~2 studs above feet
	local ripplePosition = Vector3.new(position.X, waterY, position.Z)

	-- Create a single ripple ring
	local ring = Instance.new("Part")
	ring.Name = "RippleRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.1, 2, 2) -- Start small (height, diameter, diameter)
	ring.CFrame = CFrame.new(ripplePosition) * CFrame.Angles(0, 0, math.rad(90)) -- Rotate to lay flat
	ring.Anchored = true
	ring.CanCollide = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(126, 242, 255) -- Light blue/white
	ring.Transparency = 0.9
	ring.Parent = workspace

	-- Animate expansion and fade
	local expandTween = TweenService:Create(ring, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.1, 30, 30), -- Expand outward
		Transparency = 1 -- Fade out
	})

	expandTween:Play()
	expandTween.Completed:Connect(function()
		ring:Destroy()
	end)
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

	-- Position model 0.5 studs higher for drop animation
	local startPosition = displayPosition + Vector3.new(0, 0.5, 0)
	modelClone:PivotTo(CFrame.new(startPosition) * CFrame.Angles(0, math.rad(inventoryModelRotation), 0))

	modelClone.Name = "InventoryDisplayModel"
	modelClone.Parent = workspace
	inventoryDisplayModel = modelClone

	-- Animate drop and trigger ripple when landing
	local dropTween = TweenService:Create(rootPart, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		CFrame = CFrame.new(displayPosition) * CFrame.Angles(0, math.rad(inventoryModelRotation), 0)
	})
	dropTween:Play()
	dropTween.Completed:Connect(function()
		-- Use rootPart's actual position for ripple (CreateRippleEffect subtracts 3.6 for water level)
		CreateRippleEffect(rootPart.Position)
	end)

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

	-- Vertical squash: Y-scale ~0.7 instantly reads as "water reflection"
	for _, part in ipairs(reflectionClone:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Size = Vector3.new(part.Size.X, part.Size.Y * 0.8, part.Size.Z)
		end
	end

	-- Vertical fade gradient + darken/desaturate
	local highestY, lowestY = -math.huge, math.huge
	for _, part in ipairs(reflectionClone:GetDescendants()) do
		if part:IsA("BasePart") then
			if part.Position.Y > highestY then highestY = part.Position.Y end
			if part.Position.Y < lowestY then lowestY = part.Position.Y end
		end
	end
	local heightRange = math.max(highestY - lowestY, 0.1)

	for _, part in ipairs(reflectionClone:GetDescendants()) do
		if part:IsA("BasePart") then
			-- Gradient: 0.35 at feet (near water), 0.75 at head (fades away)
			local t = math.clamp((part.Position.Y - lowestY) / heightRange, 0, 1)
			local gradientTransparency = 0.35 + t * 0.4
			part.Transparency = math.max(part.Transparency, gradientTransparency)
			part.CanCollide = false
			part.CastShadow = false
			-- Darken ~30% + desaturate toward grey
			local c = part.Color
			local grey = (c.R + c.G + c.B) / 3
			local desatAmt = 0.3 -- 30% toward grey
			local darkAmt = 0.7 -- multiply brightness by 70%
			part.Color = Color3.new(
				(c.R * (1 - desatAmt) + grey * desatAmt) * darkAmt,
				(c.G * (1 - desatAmt) + grey * desatAmt) * darkAmt,
				(c.B * (1 - desatAmt) + grey * desatAmt) * darkAmt
			)
			-- Remove surface textures for softer look
			for _, child in ipairs(part:GetChildren()) do
				if child:IsA("SurfaceAppearance") or child:IsA("Texture") or child:IsA("Decal") then
					child:Destroy()
				end
			end
			part.Material = Enum.Material.SmoothPlastic
		end
	end

	-- Only anchor root part of reflection to allow animation
	local reflectionRoot = reflectionClone:FindFirstChild("HumanoidRootPart") or reflectionClone.PrimaryPart
	if reflectionRoot then
		reflectionRoot.Anchored = true
	end

	-- Calculate exact distance from root to feet for precise reflection alignment
	local feetToRoot = 0
	if rootPart then
		local rootY = rootPart.Position.Y
		local lowestY = rootY
		for _, part in ipairs(modelClone:GetDescendants()) do
			if part:IsA("BasePart") then
				local bottomY = part.Position.Y - part.Size.Y / 2
				if bottomY < lowestY then
					lowestY = bottomY
				end
			end
		end
		feetToRoot = rootY - lowestY
	end
	inventoryFeetToRoot = feetToRoot

	-- Build a Y-negated CFrame for true mirror reflection (no facing direction change)
	local MIRROR_Y = CFrame.new() * CFrame.fromMatrix(Vector3.new(), Vector3.xAxis, -Vector3.yAxis, Vector3.zAxis)

	local function makeReflectionCFrame(pos)
		return CFrame.new(pos) * CFrame.Angles(0, math.rad(inventoryModelRotation), 0) * MIRROR_Y
	end

	-- Position reflection so its feet meet the main model's feet
	local reflectionFinalPos = displayPosition - Vector3.new(0, 2 * feetToRoot, 0)
	local reflectionStartPos = reflectionFinalPos - Vector3.new(0, 0.5, 0)
	reflectionClone:PivotTo(makeReflectionCFrame(reflectionStartPos))

	reflectionClone.Parent = workspace
	inventoryMirrorModel = reflectionClone

	-- Animate reflection drop (rises toward water surface)
	if reflectionRoot then
		local reflectionDropTween = TweenService:Create(reflectionRoot, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = makeReflectionCFrame(reflectionFinalPos)
		})
		reflectionDropTween:Play()
	end

	-- Subtle water ripple: gently wobble reflection position using layered sine waves
	if reflectionRippleConnection then
		reflectionRippleConnection:Disconnect()
		reflectionRippleConnection = nil
	end
	local rippleStart = tick()
	reflectionRippleConnection = RunService.RenderStepped:Connect(function()
		if not inventoryMirrorModel or not inventoryMirrorModel.Parent then
			if reflectionRippleConnection then
				reflectionRippleConnection:Disconnect()
				reflectionRippleConnection = nil
			end
			return
		end
		local t = tick() - rippleStart

		-- Subtle vertical wobble only: ±0.03 studs — reads as surface distortion
		local offsetY = math.sin(t * 1.1) * 0.025 + math.sin(t * 2.3) * 0.01
		local rippleOffset = Vector3.new(0, offsetY, 0)

		local basePos = displayPosition - Vector3.new(0, 2 * inventoryFeetToRoot, 0)
		local MIRROR_Y = CFrame.fromMatrix(Vector3.new(), Vector3.xAxis, -Vector3.yAxis, Vector3.zAxis)
		inventoryMirrorModel:PivotTo(CFrame.new(basePos + rippleOffset) * CFrame.Angles(0, math.rad(inventoryModelRotation), 0) * MIRROR_Y)
	end)

	-- DepthOfField: character sharp, reflection naturally softer
	if inventoryDepthOfField then
		inventoryDepthOfField:Destroy()
		inventoryDepthOfField = nil
	end
	local dof = Instance.new("DepthOfFieldEffect")
	dof.FocusDistance = 2
	dof.InFocusRadius = 3.17
	dof.FarIntensity = 0.12
	dof.NearIntensity = 0
	dof.Parent = game:GetService("Lighting")
	inventoryDepthOfField = dof

	print("LobbyController: Simple reflection clone created")

	-- Play animation on main model and store animator reference
	inventoryAnimator = nil
	inventoryCurrentAnimTrack = nil
	local humanoid = modelClone:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
		inventoryAnimator = animator

		local animation = Instance.new("Animation")
		animation.AnimationId = DEFAULT_IDLE_ANIM

		local animTrack = animator:LoadAnimation(animation)
		animTrack.Looped = true
		animTrack:Play()
		inventoryCurrentAnimTrack = animTrack
	end

	-- Play animation on reflection model and store animator reference
	reflectionAnimator = nil
	reflectionCurrentAnimTrack = nil
	local reflectionHumanoid = reflectionClone:FindFirstChildOfClass("Humanoid")
	if reflectionHumanoid then
		local refAnimator = reflectionHumanoid:FindFirstChildOfClass("Animator")
		if not refAnimator then
			refAnimator = Instance.new("Animator")
			refAnimator.Parent = reflectionHumanoid
		end
		reflectionAnimator = refAnimator

		local reflectionAnimation = Instance.new("Animation")
		reflectionAnimation.AnimationId = DEFAULT_IDLE_ANIM

		local reflectionAnimTrack = refAnimator:LoadAnimation(reflectionAnimation)
		reflectionAnimTrack.Looped = true
		reflectionAnimTrack:Play()
		-- Animation desync: offset reflection animation slightly so it doesn't mirror frame-for-frame
		reflectionAnimTrack.TimePosition = reflectionAnimTrack.Length * 0.08
		reflectionAnimTrack:AdjustSpeed(0.97) -- Slightly slower so it drifts further over time
		reflectionCurrentAnimTrack = reflectionAnimTrack
	end

	print("LobbyController: Spawned inventory display model for", tower.Name)
end

-- Tab spatial order: tabs on opposite sides of Overview must route through it
local TAB_SIDE = {
	Traits = -1,    -- left side
	Overview = 0,   -- center
	Relics = 1,     -- right side
	Evolution = 0,  -- center (placeholder)
}

-- Active camera arc animation connection
local activeCameraArc = nil

-- Cancel any in-flight camera animation
local function CancelCameraArc()
	if activeCameraArc then
		activeCameraArc:Disconnect()
		activeCameraArc = nil
	end
end

-- Smooth ease in-out helper
local function easeInOut(t)
	return t < 0.5 and 2 * t * t or 1 - math.pow(-2 * t + 2, 2) / 2
end

-- Smooth direct camera tween (no arc, straight CFrame lerp)
local function TweenCameraSmooth(camera, targetCFrame, duration)
	CancelCameraArc()
	local startCFrame = camera.CFrame
	local elapsed = 0
	local RunService = game:GetService("RunService")

	activeCameraArc = RunService.RenderStepped:Connect(function(dt)
		elapsed = elapsed + dt
		local t = math.clamp(elapsed / duration, 0, 1)
		camera.CFrame = startCFrame:Lerp(targetCFrame, easeInOut(t))
		if t >= 1 then
			camera.CFrame = targetCFrame
			CancelCameraArc()
		end
	end)
end

-- Animate camera along a Bezier arc around the character model
-- arcRadius controls how far outward the arc swings from the model
local function TweenCameraArc(camera, targetCFrame, duration, arcRadius)
	CancelCameraArc()

	local startCFrame = camera.CFrame
	local startPos = startCFrame.Position
	local endPos = targetCFrame.Position

	-- Compute control point: midpoint pushed outward from the model
	local midPos = (startPos + endPos) / 2
	local dirFromModel = midPos - INVENTORY_MODEL_POS
	dirFromModel = Vector3.new(dirFromModel.X, 0, dirFromModel.Z) -- horizontal only
	if dirFromModel.Magnitude > 0.01 then
		dirFromModel = dirFromModel.Unit
	else
		dirFromModel = Vector3.new(0, 0, 1)
	end
	local controlPoint = midPos + dirFromModel * (arcRadius or 4)
	controlPoint = Vector3.new(controlPoint.X, midPos.Y, controlPoint.Z)

	local elapsed = 0
	local RunService = game:GetService("RunService")

	activeCameraArc = RunService.RenderStepped:Connect(function(dt)
		elapsed = elapsed + dt
		local t = math.clamp(elapsed / duration, 0, 1)
		local easedT = easeInOut(t)

		-- Quadratic Bezier: B(t) = (1-t)²P0 + 2(1-t)tP1 + t²P2
		local oneMinusT = 1 - easedT
		local pos = oneMinusT * oneMinusT * startPos + 2 * oneMinusT * easedT * controlPoint + easedT * easedT * endPos

		-- Slerp the rotation by lerping CFrames then applying arc position
		local lerpedCF = startCFrame:Lerp(targetCFrame, easedT)
		camera.CFrame = CFrame.new(pos) * (lerpedCF - lerpedCF.Position)

		if t >= 1 then
			camera.CFrame = targetCFrame
			CancelCameraArc()
		end
	end)
end

-- Orbital arc: camera sweeps around the model in a smooth circular path.
-- Converts positions to polar coords (angle, radius, height) and interpolates.
-- Always looks at the character. No Bezier, no clipping, one smooth motion.
local function TweenCameraOrbit(camera, targetCFrame, duration)
	CancelCameraArc()

	local startCFrame = camera.CFrame
	local startPos = startCFrame.Position
	local endPos = targetCFrame.Position

	-- Convert world position to polar coords relative to model
	local function toPolar(pos)
		local rel = pos - INVENTORY_MODEL_POS
		local angle = math.atan2(rel.X, rel.Z)
		local radius = math.sqrt(rel.X * rel.X + rel.Z * rel.Z)
		local height = rel.Y
		return angle, radius, height
	end

	local startAngle, startRadius, startHeight = toPolar(startPos)
	local endAngle, endRadius, endHeight = toPolar(endPos)

	-- Shortest angular path (naturally goes around the left side for Traits↔Relics)
	local angleDiff = endAngle - startAngle
	while angleDiff > math.pi do angleDiff = angleDiff - 2 * math.pi end
	while angleDiff < -math.pi do angleDiff = angleDiff + 2 * math.pi end

	-- Look-at targets (both look near the model)
	local startLookAt = startPos + startCFrame.LookVector * (startPos - INVENTORY_MODEL_POS).Magnitude
	local endLookAt = endPos + targetCFrame.LookVector * (endPos - INVENTORY_MODEL_POS).Magnitude

	local elapsed = 0
	local RunService = game:GetService("RunService")

	activeCameraArc = RunService.RenderStepped:Connect(function(dt)
		elapsed = elapsed + dt
		local t = math.clamp(elapsed / duration, 0, 1)
		local easedT = easeInOut(t)

		-- Interpolate polar coords
		local angle = startAngle + angleDiff * easedT
		local radius = startRadius + (endRadius - startRadius) * easedT
		local height = startHeight + (endHeight - startHeight) * easedT

		-- Convert back to world position
		local pos = INVENTORY_MODEL_POS + Vector3.new(
			math.sin(angle) * radius,
			height,
			math.cos(angle) * radius
		)

		-- Smoothly interpolate look-at target
		local lookTarget = startLookAt:Lerp(endLookAt, easedT)
		camera.CFrame = CFrame.lookAt(pos, lookTarget)

		if t >= 1 then
			camera.CFrame = targetCFrame
			CancelCameraArc()
		end
	end)
end

-- Switch inventory tab: camera movement and animations
local function SwitchInventoryTab(tabName)
	if currentInventoryTab == tabName then return end
	local previousTab = currentInventoryTab
	currentInventoryTab = tabName

	local camera = workspace.CurrentCamera
	local targetCFrame = TAB_CAMERAS[tabName]

	if targetCFrame then
		local fromSide = TAB_SIDE[previousTab] or 0
		local toSide = TAB_SIDE[tabName] or 0

		if fromSide ~= 0 and toSide ~= 0 and fromSide ~= toSide then
			-- Opposite sides (Traits↔Relics): smooth orbital sweep around the character
			TweenCameraOrbit(camera, targetCFrame, 0.8)
		elseif tabName == "Relics" or previousTab == "Relics" then
			-- Overview↔Relics: wide arc
			TweenCameraArc(camera, targetCFrame, 0.6, 4)
		else
			-- Overview↔Traits (and others): smooth direct
			TweenCameraSmooth(camera, targetCFrame, 0.5)
		end
	end

	-- Switch animations
	animSwitchVersion = animSwitchVersion + 1
	local thisVersion = animSwitchVersion
	local transitionId = TAB_TRANSITIONS[previousTab] and TAB_TRANSITIONS[previousTab][tabName]
	local idleId = TAB_IDLE_ANIMS[tabName]

	-- Helper: play an animation on both main + reflection animators
	local function playOnBoth(animId, looped)
		local anim = Instance.new("Animation")
		anim.AnimationId = animId

		local mainTrack = inventoryAnimator:LoadAnimation(anim)
		mainTrack.Looped = looped
		mainTrack:Play()
		inventoryCurrentAnimTrack = mainTrack

		if reflectionAnimator then
			local refAnim = Instance.new("Animation")
			refAnim.AnimationId = animId
			local refTrack = reflectionAnimator:LoadAnimation(refAnim)
			refTrack.Looped = looped
			refTrack:Play()
			reflectionCurrentAnimTrack = refTrack
		end

		return mainTrack
	end

	if inventoryAnimator then
		-- Stop current animations on both models
		if inventoryCurrentAnimTrack then
			inventoryCurrentAnimTrack:Stop(0.2)
		end
		if reflectionCurrentAnimTrack then
			reflectionCurrentAnimTrack:Stop(0.2)
		end

		if transitionId then
			-- Play directional transition on both, then switch to idle on completion
			local transTrack = playOnBoth(transitionId, false)

			-- When transition finishes, switch to idle (guard against stale callbacks)
			transTrack.Stopped:Connect(function()
				if animSwitchVersion ~= thisVersion then return end
				if idleId and inventoryAnimator then
					-- Stop any lingering transition tracks before playing idle
					if inventoryCurrentAnimTrack then
						inventoryCurrentAnimTrack:Stop(0)
					end
					if reflectionCurrentAnimTrack then
						reflectionCurrentAnimTrack:Stop(0)
					end
					playOnBoth(idleId, true)
				end
			end)
		elseif idleId then
			-- No transition, just play idle directly on both
			playOnBoth(idleId, true)
		end
	end

	print("LobbyController: Switched inventory tab to", tabName)
end

-- Load and display inventory
function LobbyController.LoadInventory()
	print("LobbyController: LoadInventory called")
	local inventory = GetInventoryFunction:InvokeServer()
	print("LobbyController: Received inventory with", #inventory, "items")

	-- Get loadout to sort equipped units first
	local loadout = GetLoadoutFunction:InvokeServer()
	local equippedInstanceIds = {}
	local equippedOrder = {}
	for slotNum, instanceId in pairs(loadout) do
		if instanceId and instanceId ~= "" then
			equippedInstanceIds[instanceId] = true
			equippedOrder[instanceId] = slotNum
		end
	end

	-- Sort inventory: equipped units first (by slot order), then others
	table.sort(inventory, function(a, b)
		local aEquipped = equippedInstanceIds[a.InstanceId]
		local bEquipped = equippedInstanceIds[b.InstanceId]

		if aEquipped and bEquipped then
			-- Both equipped, sort by loadout slot order
			return (equippedOrder[a.InstanceId] or 99) < (equippedOrder[b.InstanceId] or 99)
		elseif aEquipped then
			return true -- a is equipped, goes first
		elseif bEquipped then
			return false -- b is equipped, goes first
		else
			-- Neither equipped, maintain original order
			return false
		end
	end)

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

			-- Update Cost label (get from tower model's Config/Price value if it exists)
			local costLabel = slot:FindFirstChild("Cost")
			if costLabel then
				local towersFolder = game:GetService("ReplicatedStorage"):FindFirstChild("Towers")
				if towersFolder then
					local towerModelRef = towersFolder:FindFirstChild(tower.ModelName)
					if towerModelRef then
						local configFolder = towerModelRef:FindFirstChild("Config")
						if configFolder then
							local priceValue = configFolder:FindFirstChild("Price")
							if priceValue and priceValue:IsA("IntValue") then
								costLabel.Text = "$" .. FormatNumber(priceValue.Value)
							else
								costLabel.Text = "?"
							end
						else
							costLabel.Text = "?"
						end
					else
						costLabel.Text = "?"
					end
				else
					costLabel.Text = "?"
				end
			end

			-- Update Color ImageLabel (element type icon)
			local colorImage = slot:FindFirstChild("Color")
			if colorImage and colorImage:IsA("ImageLabel") then
				local colorType = tower.ColorType
				if colorType then
					local imageId = ColorTypeSystem.GetTypeImage(colorType)
					if imageId and imageId ~= "" then
						colorImage.Image = imageId
					end
					-- Also tint the image with the type color
					colorImage.ImageColor3 = ColorTypeSystem.GetTypeColor(colorType)
				end
			end

			-- Update Level label (calculate from XP if available)
			local levelLabel = slot:FindFirstChild("Level")
			if levelLabel then
				local xp = towerData.XP or 0
				-- Simple level calculation: level = floor(sqrt(XP / 100)) + 1
				local level = math.floor(math.sqrt(xp / 100)) + 1
				levelLabel.Text = "Lv." .. tostring(level)
			end

			-- Update Trait ImageLabel (placeholder for now)
			local traitImage = slot:FindFirstChild("Trait")
			if traitImage and traitImage:IsA("ImageLabel") then
				local traits = towerData.Traits or {}
				if #traits > 0 then
					-- Get first trait info
					local firstTrait = traits[1]
					local traitData = TraitSystem.GetTrait(firstTrait)
					if traitData then
						-- Placeholder image - no trait images defined yet
						-- traitImage.Image = traitData.ImageId or ""
						-- For now, just show the trait exists by keeping placeholder visible
						traitImage.Visible = true
					else
						traitImage.Visible = false
					end
				else
					traitImage.Visible = false
				end
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

			-- Store locked status and instanceId on the slot for sell mode
			local instanceId = towerData.InstanceId
			local isLocked = towerData.Locked or false
			slot:SetAttribute("InstanceId", instanceId)
			slot:SetAttribute("IsLocked", isLocked)

			-- Add lock indicator if unit is locked
			if isLocked then
				local lockIndicator = Instance.new("ImageLabel")
				lockIndicator.Name = "LockIndicator"
				lockIndicator.Size = UDim2.new(0, 20, 0, 20)
				lockIndicator.Position = UDim2.new(1, -22, 0, 2)
				lockIndicator.BackgroundTransparency = 1
				lockIndicator.Image = "rbxassetid://6031091004" -- Lock icon
				lockIndicator.ImageColor3 = Color3.fromRGB(255, 200, 50)
				lockIndicator.ZIndex = 5
				lockIndicator.Parent = slot
			end

			-- Click handler for unit selection and sell mode
			slot.Activated:Connect(function()
				animateButtonPress(slot)

				-- If in sell mode, toggle this unit for sale
				if sellModeActive then
					LobbyController.ToggleUnitForSale(slot, instanceId, isLocked)
					return
				end

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

	-- Try LoadoutFrame first, then LoadoutFrame for backwards compatibility
	local loadoutFrame = gui:FindFirstChild("LoadoutFrame") or gui:FindFirstChild("LoadoutFrame")
	if not loadoutFrame then 
		warn("LobbyController: LoadoutFrame/LoadoutFrame not found")
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

	-- Save current time and set to noon
	savedClockTime = Lighting.ClockTime
	Lighting.ClockTime = 12

	-- Hide all GUI elements except GemsDisplay, LoadoutFrame, and InventoryUI
	hiddenGUIsForInventory = {}
	for _, child in ipairs(gui:GetChildren()) do
		if child:IsA("GuiObject") and child.Visible then
			local name = child.Name
			if name ~= "GemsDisplay" and name ~= "LoadoutFrame" and name ~= "InventoryUI" and name ~= "InventoryUI2" then
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

		-- Show InventoryUI2 (sell mode controls)
		local inventoryUI2 = gui:FindFirstChild("InventoryUI2")
		if inventoryUI2 then
			inventoryUI2.Visible = true
			-- Make sure sell/cancel buttons are hidden on open (not in sell mode)
			local sellButton = inventoryUI2:FindFirstChild("SellButton")
			local cancelButton = inventoryUI2:FindFirstChild("CancelButton")
			local lockUnitBtn = inventoryUI2:FindFirstChild("LockUnit")
			local sellUnitBtn = inventoryUI2:FindFirstChild("SellUnit")
			if sellButton then sellButton.Visible = false end
			if cancelButton then cancelButton.Visible = false end
			if lockUnitBtn then lockUnitBtn.Visible = true end
			if sellUnitBtn then sellUnitBtn.Visible = true end
		end

		-- Remove old dynamically-created close button if it exists
		local oldCloseBtn = inventoryUI:FindFirstChild("CloseInventoryButton")
		if oldCloseBtn then
			oldCloseBtn:Destroy()
		end

		-- Default Overview side button to selected state
		if sideButtonStates.Overview then
			sideButtonStates.Overview.select(false)
		end

		-- Auto-select first unit in inventory
		local gridFrame = inventoryUI:FindFirstChild("GridFrame")
		if gridFrame then
			-- Find the first slot (lowest LayoutOrder)
			local firstSlot = nil
			local lowestOrder = math.huge
			for _, child in ipairs(gridFrame:GetChildren()) do
				if (child:IsA("Frame") or child:IsA("ImageButton")) and child.Name ~= "Template" and child.Visible then
					if child.LayoutOrder < lowestOrder then
						lowestOrder = child.LayoutOrder
						firstSlot = child
					end
				end
			end

			if firstSlot then
				local instanceId = firstSlot:GetAttribute("InstanceId")
				if instanceId then
					-- Clear any previous selection
					for _, otherSlot in ipairs(gridFrame:GetChildren()) do
						if otherSlot:IsA("Frame") or otherSlot:IsA("ImageButton") then
							local highlight = otherSlot:FindFirstChild("SelectionHighlight")
							if highlight then
								highlight:Destroy()
							end
						end
					end

					-- Display the unit info and model but do NOT enter selection mode
					-- (user must click the unit again to enter loadout placement mode)
					local inventory = GetInventoryFunction:InvokeServer()
					for _, unitData in ipairs(inventory) do
						if unitData.InstanceId == instanceId then
							local tower = TowerData.GetTowerById(unitData.TowerId)
							if tower then
								print("LobbyController: Auto-displaying unit:", tower.Name)
								SpawnInventoryDisplayModel(tower.ID)
							end
							break
						end
					end

					-- Add selection highlight (visual only, not loadout placement)
					local highlight = Instance.new("UIStroke")
					highlight.Name = "SelectionHighlight"
					highlight.Color = Color3.fromRGB(255, 255, 0)
					highlight.Thickness = 3
					highlight.Parent = firstSlot
				end
			end
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

	-- Clean up reflection ripple connection
	if reflectionRippleConnection then
		reflectionRippleConnection:Disconnect()
		reflectionRippleConnection = nil
	end
	-- Clean up DepthOfField
	if inventoryDepthOfField then
		inventoryDepthOfField:Destroy()
		inventoryDepthOfField = nil
	end
	inventoryModelRotation = 160 -- Reset rotation to default angle

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

	-- Exit sell mode if active
	if sellModeActive then
		LobbyController.ExitSellMode()
	end

	-- Clear selected unit so swap mode doesn't persist
	ClearSelectedUnit()

	-- Reset Overview side button to deselected
	if sideButtonStates.Overview then
		sideButtonStates.Overview.deselect(false)
	end

	-- Reset tab state so next open starts fresh
	currentInventoryTab = "Overview"

	-- Hide inventory UI
	if gui:FindFirstChild("InventoryUI") then
		gui.InventoryUI.Visible = false
	end

	-- Hide InventoryUI2 (sell mode controls)
	local inventoryUI2 = gui:FindFirstChild("InventoryUI2")
	if inventoryUI2 then
		inventoryUI2.Visible = false
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

	-- Restore clock time
	if savedClockTime then
		Lighting.ClockTime = savedClockTime
	end

	-- Clear saved states
	savedInventoryCameraCFrame = nil
	savedInventoryCameraType = nil
	savedSky = nil
	savedAtmosphere = nil
	savedClockTime = nil

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

--------------------------------------------------------------------------------
-- SELL MODE FUNCTIONS
--------------------------------------------------------------------------------

-- Enter sell mode
function LobbyController.EnterSellMode()
	if sellModeActive then return end

	sellModeActive = true
	unitsToSell = {}

	-- Show sell/cancel buttons, hide other InventoryUI2 buttons
	local inventoryUI2 = gui:FindFirstChild("InventoryUI2")
	if inventoryUI2 then
		local sellButton = inventoryUI2:FindFirstChild("SellButton")
		local cancelButton = inventoryUI2:FindFirstChild("CancelButton")
		local lockUnitBtn = inventoryUI2:FindFirstChild("LockUnit")
		local sellUnitBtn = inventoryUI2:FindFirstChild("SellUnit")

		if sellButton then sellButton.Visible = true end
		if cancelButton then cancelButton.Visible = true end
		if lockUnitBtn then lockUnitBtn.Visible = false end
		if sellUnitBtn then sellUnitBtn.Visible = false end
	end

	print("LobbyController: Entered sell mode")
end

-- Exit sell mode without selling
function LobbyController.ExitSellMode()
	if not sellModeActive then return end

	-- Clear all sell markers from inventory slots
	local inventoryUI = gui:FindFirstChild("InventoryUI")
	if inventoryUI then
		local gridFrame = inventoryUI:FindFirstChild("GridFrame")
		if gridFrame then
			for _, slot in ipairs(gridFrame:GetChildren()) do
				if slot:IsA("Frame") or slot:IsA("ImageButton") then
					-- Remove sell marker
					local sellMarker = slot:FindFirstChild("SellMarker")
					if sellMarker then
						sellMarker:Destroy()
					end
					-- Restore original background
					local originalColor = slot:GetAttribute("OriginalBackgroundColor")
					if originalColor then
						slot.BackgroundColor3 = originalColor
						slot:SetAttribute("OriginalBackgroundColor", nil)
					end
				end
			end
		end
	end

	sellModeActive = false
	unitsToSell = {}

	-- Hide sell/cancel buttons, show other InventoryUI2 buttons
	local inventoryUI2 = gui:FindFirstChild("InventoryUI2")
	if inventoryUI2 then
		local sellButton = inventoryUI2:FindFirstChild("SellButton")
		local cancelButton = inventoryUI2:FindFirstChild("CancelButton")
		local lockUnitBtn = inventoryUI2:FindFirstChild("LockUnit")
		local sellUnitBtn = inventoryUI2:FindFirstChild("SellUnit")

		if sellButton then sellButton.Visible = false end
		if cancelButton then cancelButton.Visible = false end
		if lockUnitBtn then lockUnitBtn.Visible = true end
		if sellUnitBtn then sellUnitBtn.Visible = true end
	end

	print("LobbyController: Exited sell mode")
end

-- Toggle unit for selling (called when clicking a unit in sell mode)
function LobbyController.ToggleUnitForSale(slot, instanceId, isLocked)
	if not sellModeActive then return end

	-- Can't sell locked units
	if isLocked then
		print("LobbyController: Cannot sell locked unit")
		return
	end

	local isMarked = unitsToSell[instanceId] ~= nil

	if isMarked then
		-- Unmark for sale
		unitsToSell[instanceId] = nil

		-- Remove visual marker
		local sellMarker = slot:FindFirstChild("SellMarker")
		if sellMarker then
			sellMarker:Destroy()
		end

		-- Restore original background
		local originalColor = slot:GetAttribute("OriginalBackgroundColor")
		if originalColor then
			slot.BackgroundColor3 = originalColor
		end
	else
		-- Mark for sale
		unitsToSell[instanceId] = true

		-- Save original background color
		if not slot:GetAttribute("OriginalBackgroundColor") then
			slot:SetAttribute("OriginalBackgroundColor", slot.BackgroundColor3)
		end

		-- Set red background
		slot.BackgroundColor3 = Color3.fromRGB(180, 50, 50)

		-- Add dollar sign overlay
		local sellMarker = Instance.new("ImageLabel")
		sellMarker.Name = "SellMarker"
		sellMarker.Size = UDim2.new(0.5, 0, 0.5, 0)
		sellMarker.Position = UDim2.new(0.25, 0, 0.25, 0)
		sellMarker.BackgroundTransparency = 1
		sellMarker.Image = SELL_DOLLAR_IMAGE
		sellMarker.ImageColor3 = Color3.new(1, 1, 1)
		sellMarker.ZIndex = 10
		sellMarker.Parent = slot
	end
end

-- Confirm and sell all marked units
function LobbyController.ConfirmSellUnits()
	if not sellModeActive then return end

	-- Collect all instance IDs to sell
	local instanceIds = {}
	for instanceId, _ in pairs(unitsToSell) do
		table.insert(instanceIds, instanceId)
	end

	if #instanceIds == 0 then
		print("LobbyController: No units selected to sell")
		LobbyController.ExitSellMode()
		return
	end

	if not SellUnitsFunction then
		LobbyController.ShowError("Sell system not available")
		return
	end

	print("LobbyController: Selling", #instanceIds, "units")

	local result = SellUnitsFunction:InvokeServer(instanceIds)

	if result.Success then
		print("LobbyController: Sold", result.SoldCount, "units for", result.TotalCoins, "coins")

		-- Show feedback to player
		if result.SoldCount > 0 then
			-- TODO: Show nice feedback UI
			print("Earned " .. result.TotalCoins .. " coins!")
		end

		if result.SkippedLocked > 0 then
			print("Skipped", result.SkippedLocked, "locked units")
		end

		if result.SkippedLoadout > 0 then
			print("Skipped", result.SkippedLoadout, "units in loadout")
		end
	else
		LobbyController.ShowError(result.Error or "Failed to sell units")
	end

	-- Exit sell mode and refresh inventory
	LobbyController.ExitSellMode()
	LobbyController.LoadInventory()
end

-- Lock/unlock the currently selected unit
function LobbyController.ToggleUnitLock()
	if not selectedUnit then
		print("LobbyController: No unit selected to lock/unlock")
		return
	end

	if not LockUnitFunction then
		LobbyController.ShowError("Lock system not available")
		return
	end

	-- Get current lock status from the slot
	local inventoryUI = gui:FindFirstChild("InventoryUI")
	if not inventoryUI then return end

	local gridFrame = inventoryUI:FindFirstChild("GridFrame")
	if not gridFrame then return end

	local slot = gridFrame:FindFirstChild(selectedUnit)
	if not slot then return end

	local currentlyLocked = slot:GetAttribute("IsLocked") or false
	local newLockState = not currentlyLocked

	local result = LockUnitFunction:InvokeServer(selectedUnit, newLockState)

	if result.Success then
		print("LobbyController: Unit lock state changed to", result.Locked)
		-- Refresh inventory to show lock status
		LobbyController.LoadInventory()
	else
		LobbyController.ShowError(result.Error or "Failed to change lock status")
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
					if gui:FindFirstChild("LoadoutFrame") then
						gui.LoadoutFrame.Visible = false
					end
				else
					-- Show Gems and Loadout when closing SummonUI
					if gui:FindFirstChild("GemsDisplay") then
						gui.GemsDisplay.Visible = true
					end
					if gui:FindFirstChild("LoadoutFrame") then
						gui.LoadoutFrame.Visible = true
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
				if gui:FindFirstChild("LoadoutFrame") then
					gui.LoadoutFrame.Visible = true
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

	-- Connect InventoryUI2 buttons (sell mode controls)
	local inventoryUI2 = gui:FindFirstChild("InventoryUI2")
	if inventoryUI2 then
		print("LobbyController: Found InventoryUI2")

		-- CloseButton (directly under InventoryUI2)
		local closeBtn = inventoryUI2:FindFirstChild("CloseButton")
		if closeBtn then
			local closeBtnClickTarget = closeBtn:FindFirstChild("Button") or closeBtn
			closeBtnClickTarget.Activated:Connect(function()
				animateButtonPress(closeBtn)
				LobbyController.CloseInventoryMode()
			end)
			print("LobbyController: Connected InventoryUI2 CloseButton")
		end

		-- InventoryUI2.Buttons connections
		local buttonsFrame = inventoryUI2:FindFirstChild("Buttons")
		if buttonsFrame then
			local unitsTab = buttonsFrame:FindFirstChild("Units")
			local itemsTab = buttonsFrame:FindFirstChild("Items")
			local line = buttonsFrame:FindFirstChild("Line")

			local lineUnitsPos = UDim2.new(0.404, 0, 0.681, 0)
			local lineUnitsSize = UDim2.new(0.055, 0, 0.07, 0)
			local lineItemsPos = UDim2.new(0.584, 0, 0.681, 0)
			local lineItemsSize = UDim2.new(0.058, 0, 0.07, 0)
			local currentTab = "Units"

			if unitsTab and line then
				unitsTab.Activated:Connect(function()
					if currentTab == "Units" then return end
					currentTab = "Units"
					animateButtonPress(unitsTab)
					local tween = TweenService:Create(line, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
						Position = lineUnitsPos,
						Size = lineUnitsSize
					})
					tween:Play()
					print("LobbyController: Switched to Units tab")
				end)
			end

			if itemsTab and line then
				itemsTab.Activated:Connect(function()
					if currentTab == "Items" then return end
					currentTab = "Items"
					animateButtonPress(itemsTab)
					local tween = TweenService:Create(line, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
						Position = lineItemsPos,
						Size = lineItemsSize
					})
					tween:Play()
					print("LobbyController: Switched to Items tab")
				end)
			end
		end

		-- LockUnit button - locks/unlocks the selected unit
		local lockUnitBtn = inventoryUI2:FindFirstChild("LockUnit")
		if lockUnitBtn then
			print("LobbyController: Connected LockUnit button")
			lockUnitBtn.Activated:Connect(function()
				animateButtonPress(lockUnitBtn)
				LobbyController.ToggleUnitLock()
			end)
		end

		-- SellUnit button - enters sell mode
		local sellUnitBtn = inventoryUI2:FindFirstChild("SellUnit")
		if sellUnitBtn then
			print("LobbyController: Connected SellUnit button")
			sellUnitBtn.Activated:Connect(function()
				animateButtonPress(sellUnitBtn)
				LobbyController.EnterSellMode()
			end)
		end

		-- SellButton - confirms sale of marked units
		local sellButton = inventoryUI2:FindFirstChild("SellButton")
		if sellButton then
			print("LobbyController: Connected SellButton")
			sellButton.Visible = false -- Hidden by default
			sellButton.Activated:Connect(function()
				animateButtonPress(sellButton)
				LobbyController.ConfirmSellUnits()
			end)
		end

		-- CancelButton - exits sell mode without selling
		local cancelButton = inventoryUI2:FindFirstChild("CancelButton")
		if cancelButton then
			print("LobbyController: Connected CancelButton")
			cancelButton.Visible = false -- Hidden by default
			cancelButton.Activated:Connect(function()
				animateButtonPress(cancelButton)
				LobbyController.ExitSellMode()
			end)
		end
		-- SideButtons
		local sideButtons = inventoryUI2:FindFirstChild("SideButtons")
		if sideButtons then
			local overviewBtn = sideButtons:FindFirstChild("Overview")
			if overviewBtn then
				local origPos = overviewBtn.Position
				local origBgColor = overviewBtn.BackgroundColor3
				local icon = overviewBtn:FindFirstChildWhichIsA("ImageLabel")
				local origImgColor = icon and icon.ImageColor3 or nil
				local hoverOffset = UDim2.new(-0.02, 0, 0, 0)
				local selectOffset = UDim2.new(-0.05, 0, 0, 0)

				-- Store state and helpers in module-level table
				local activeTweens = {}
				local function cancelActiveTweens()
					for _, tw in ipairs(activeTweens) do tw:Cancel() end
					activeTweens = {}
				end
				sideButtonStates.Overview = {
					selected = false,
					select = function(animate)
						cancelActiveTweens()
						sideButtonStates.Overview.selected = true
						if animate then
							local t1 = TweenService:Create(overviewBtn, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
								Position = origPos + selectOffset,
								BackgroundColor3 = Color3.fromRGB(255, 255, 255)
							})
							t1:Play()
							table.insert(activeTweens, t1)
							if icon then
								local t2 = TweenService:Create(icon, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
									ImageColor3 = Color3.fromRGB(0, 0, 0)
								})
								t2:Play()
								table.insert(activeTweens, t2)
							end
						else
							overviewBtn.Position = origPos + selectOffset
							overviewBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
							if icon then icon.ImageColor3 = Color3.fromRGB(0, 0, 0) end
						end
					end,
					deselect = function(animate)
						cancelActiveTweens()
						sideButtonStates.Overview.selected = false
						if animate then
							local t1 = TweenService:Create(overviewBtn, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
								Position = origPos,
								BackgroundColor3 = origBgColor
							})
							t1:Play()
							table.insert(activeTweens, t1)
							if icon and origImgColor then
								local t2 = TweenService:Create(icon, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
									ImageColor3 = origImgColor
								})
								t2:Play()
								table.insert(activeTweens, t2)
							end
						else
							overviewBtn.Position = origPos
							overviewBtn.BackgroundColor3 = origBgColor
							if icon and origImgColor then icon.ImageColor3 = origImgColor end
						end
					end,
				}

				overviewBtn.MouseEnter:Connect(function()
					if sideButtonStates.Overview.selected then return end
					TweenService:Create(overviewBtn, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Position = origPos + hoverOffset
					}):Play()
				end)

				overviewBtn.MouseLeave:Connect(function()
					if sideButtonStates.Overview.selected then return end
					TweenService:Create(overviewBtn, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Position = origPos
					}):Play()
				end)

				overviewBtn.Activated:Connect(function()
					if sideButtonStates.Overview.selected then return end
					-- Deselect all other side buttons instantly to avoid flash
					for otherName, state in pairs(sideButtonStates) do
						if otherName ~= "Overview" and state.selected then
							state.deselect(false)
						end
					end
					sideButtonStates.Overview.select(true)
					SwitchInventoryTab("Overview")
				end)

				print("LobbyController: Connected SideButtons.Overview")
			end

			-- Helper to set up additional side buttons (same behavior as Overview)
			local function setupSideButton(name)
				local btn = sideButtons:FindFirstChild(name)
				if not btn then return end

				local btnOrigPos = btn.Position
				local btnOrigBgColor = btn.BackgroundColor3
				local btnIcon = btn:FindFirstChildWhichIsA("ImageLabel")
				local btnOrigImgColor = btnIcon and btnIcon.ImageColor3 or nil
				local btnHoverOffset = UDim2.new(-0.02, 0, 0, 0)
				local btnSelectOffset = UDim2.new(-0.05, 0, 0, 0)

				local btnActiveTweens = {}
				local function cancelBtnTweens()
					for _, tw in ipairs(btnActiveTweens) do tw:Cancel() end
					btnActiveTweens = {}
				end
				sideButtonStates[name] = {
					selected = false,
					select = function(animate)
						cancelBtnTweens()
						sideButtonStates[name].selected = true
						if animate then
							local t1 = TweenService:Create(btn, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
								Position = btnOrigPos + btnSelectOffset,
								BackgroundColor3 = Color3.fromRGB(255, 255, 255)
							})
							t1:Play()
							table.insert(btnActiveTweens, t1)
							if btnIcon then
								local t2 = TweenService:Create(btnIcon, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
									ImageColor3 = Color3.fromRGB(0, 0, 0)
								})
								t2:Play()
								table.insert(btnActiveTweens, t2)
							end
						else
							btn.Position = btnOrigPos + btnSelectOffset
							btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
							if btnIcon then btnIcon.ImageColor3 = Color3.fromRGB(0, 0, 0) end
						end
					end,
					deselect = function(animate)
						cancelBtnTweens()
						sideButtonStates[name].selected = false
						if animate then
							local t1 = TweenService:Create(btn, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
								Position = btnOrigPos,
								BackgroundColor3 = btnOrigBgColor
							})
							t1:Play()
							table.insert(btnActiveTweens, t1)
							if btnIcon and btnOrigImgColor then
								local t2 = TweenService:Create(btnIcon, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
									ImageColor3 = btnOrigImgColor
								})
								t2:Play()
								table.insert(btnActiveTweens, t2)
							end
						else
							btn.Position = btnOrigPos
							btn.BackgroundColor3 = btnOrigBgColor
							if btnIcon and btnOrigImgColor then btnIcon.ImageColor3 = btnOrigImgColor end
						end
					end,
				}

				btn.MouseEnter:Connect(function()
					if sideButtonStates[name].selected then return end
					TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Position = btnOrigPos + btnHoverOffset
					}):Play()
				end)

				btn.MouseLeave:Connect(function()
					if sideButtonStates[name].selected then return end
					TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Position = btnOrigPos
					}):Play()
				end)

				btn.Activated:Connect(function()
					if sideButtonStates[name].selected then return end
					-- Deselect all other side buttons instantly to avoid flash
					for otherName, state in pairs(sideButtonStates) do
						if otherName ~= name and state.selected then
							state.deselect(false)
						end
					end
					sideButtonStates[name].select(true)
					SwitchInventoryTab(name)
				end)

				print("LobbyController: Connected SideButtons." .. name)
			end

			setupSideButton("Traits")
			setupSideButton("Relics")
			setupSideButton("Evolution")
		end
	else
		warn("LobbyController: InventoryUI2 not found")
	end

	-- Hide LoadoutFrame and GemsDisplay if SummonUI is initially visible
	local summonUI = gui:FindFirstChild("SummonUI")
	if summonUI and summonUI.Visible then
		if gui:FindFirstChild("LoadoutFrame") then
			gui.LoadoutFrame.Visible = false
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

		-- Preload all tab animations (idles + directional transitions)
		local preloadedIds = {}
		for _, id in pairs(TAB_IDLE_ANIMS) do
			if id and not preloadedIds[id] then
				preloadedIds[id] = true
				local anim = Instance.new("Animation")
				anim.AnimationId = id
				table.insert(assetsToPreload, anim)
			end
		end
		for _, toTable in pairs(TAB_TRANSITIONS) do
			for _, id in pairs(toTable) do
				if id and not preloadedIds[id] then
					preloadedIds[id] = true
					local anim = Instance.new("Animation")
					anim.AnimationId = id
					table.insert(assetsToPreload, anim)
				end
			end
		end

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
