print("LobbyController: Script starting...")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
print("LobbyController: Got player:", player.Name)

local gui = player:WaitForChild("PlayerGui"):WaitForChild("LobbyGui")
print("LobbyController: Found LobbyGui")

local TowerData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TowerData"))
local MapData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MapData"))
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

local LobbyController = {}

-- State variables
local selectedMapId = nil
local selectedAct = 1
local selectedUnit = nil -- Currently selected unit from inventory for swap system

-- VFX display variables
local vfxDisplayModel = nil
local vfxRenderConnection = nil
local savedCameraCFrame = nil
local savedCameraType = nil

-- Rainbow gradient animation for Mythic rarity
local rainbowConnection = nil

-- Map selector variable
local selectedMapId = nil

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

			-- Click to select unit for swap system (using instanceId for new system)
			local instanceId = towerData.InstanceId
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
		if child:IsA("Frame") and child.Name ~= "Template" and child.Name ~= "LockedTemplate" then
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
		if child:IsA("Frame") and child.Name ~= "Template" and child.Name ~= "LockedTemplate" then
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
			-- Just toggle visibility, inventory is already preloaded
			if gui:FindFirstChild("InventoryUI") then
				gui.InventoryUI.Visible = not gui.InventoryUI.Visible
			end
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
end

-- Auto-initialize
LobbyController.Initialize()

return LobbyController
