--[[
	ModMenu.client.lua
	Debug/Testing menu for modifying tower stats, traits, colors, and tags at runtime
	Type /modmenu or /mm in chat to toggle
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local modules = ReplicatedStorage:WaitForChild("Modules")

-- Safe requires with fallback empty tables
local ColorTypeSystem, TagSystem, TraitSystem

local success, result = pcall(function()
	return require(modules:WaitForChild("ColorTypeSystem", 3))
end)
ColorTypeSystem = success and result or {Types = {}}

success, result = pcall(function()
	return require(modules:WaitForChild("TagSystem", 3))
end)
TagSystem = success and result or {ValidTags = {}}

success, result = pcall(function()
	return require(modules:WaitForChild("TraitSystem", 3))
end)
TraitSystem = success and result or {Traits = {}}

local functions = ReplicatedStorage:WaitForChild("Functions")
local modMenuFunction = functions:WaitForChild("ModMenu", 5)

if not modMenuFunction then
	modMenuFunction = Instance.new("RemoteFunction")
	modMenuFunction.Name = "ModMenu"
	modMenuFunction.Parent = functions
end

-- Create UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ModMenuGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Main frame
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 400, 0, 500)
mainFrame.Position = UDim2.new(0.5, -200, 0.5, -250)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = mainFrame

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 10)
titleCorner.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, -50, 1, 0)
titleLabel.Position = UDim2.new(0, 10, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "🔧 Mod Menu (/mm to toggle)"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 18
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local closeButton = Instance.new("TextButton")
closeButton.Name = "Close"
closeButton.Size = UDim2.new(0, 30, 0, 30)
closeButton.Position = UDim2.new(1, -35, 0, 5)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.TextSize = 16
closeButton.Font = Enum.Font.GothamBold
closeButton.Parent = titleBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 5)
closeCorner.Parent = closeButton

-- Content area with scroll
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "Content"
scrollFrame.Size = UDim2.new(1, -20, 1, -50)
scrollFrame.Position = UDim2.new(0, 10, 0, 45)
scrollFrame.BackgroundTransparency = 1
scrollFrame.ScrollBarThickness = 6
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 2500) -- Increased for all content
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y -- Auto-resize based on content
scrollFrame.Parent = mainFrame

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 8)
layout.Parent = scrollFrame

-- Helper function to create section headers
local function CreateSection(name, order)
	local section = Instance.new("Frame")
	section.Name = name
	section.Size = UDim2.new(1, 0, 0, 30)
	section.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
	section.BorderSizePixel = 0
	section.LayoutOrder = order
	section.Parent = scrollFrame
	
	local sCorner = Instance.new("UICorner")
	sCorner.CornerRadius = UDim.new(0, 5)
	sCorner.Parent = section
	
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "▼ " .. name
	label.TextColor3 = Color3.fromRGB(255, 200, 100)
	label.TextSize = 16
	label.Font = Enum.Font.GothamBold
	label.Parent = section
	
	return section
end

-- Helper function to create stat sliders
local function CreateSlider(name, min, max, default, order, callback)
	local container = Instance.new("Frame")
	container.Name = name .. "Slider"
	container.Size = UDim2.new(1, 0, 0, 50)
	container.BackgroundTransparency = 1
	container.LayoutOrder = order
	container.Parent = scrollFrame
	
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.4, 0, 0, 20)
	label.BackgroundTransparency = 1
	label.Text = name
	label.TextColor3 = Color3.fromRGB(200, 200, 200)
	label.TextSize = 14
	label.Font = Enum.Font.Gotham
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = container
	
	local valueLabel = Instance.new("TextLabel")
	valueLabel.Name = "Value"
	valueLabel.Size = UDim2.new(0.2, 0, 0, 20)
	valueLabel.Position = UDim2.new(0.8, 0, 0, 0)
	valueLabel.BackgroundTransparency = 1
	valueLabel.Text = tostring(default)
	valueLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
	valueLabel.TextSize = 14
	valueLabel.Font = Enum.Font.GothamBold
	valueLabel.Parent = container
	
	local sliderBg = Instance.new("Frame")
	sliderBg.Size = UDim2.new(1, 0, 0, 20)
	sliderBg.Position = UDim2.new(0, 0, 0, 25)
	sliderBg.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	sliderBg.BorderSizePixel = 0
	sliderBg.Parent = container
	
	local sliderCorner = Instance.new("UICorner")
	sliderCorner.CornerRadius = UDim.new(0, 5)
	sliderCorner.Parent = sliderBg
	
	local sliderFill = Instance.new("Frame")
	sliderFill.Name = "Fill"
	sliderFill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
	sliderFill.BackgroundColor3 = Color3.fromRGB(80, 150, 255)
	sliderFill.BorderSizePixel = 0
	sliderFill.Parent = sliderBg
	
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 5)
	fillCorner.Parent = sliderFill
	
	local dragging = false
	
	sliderBg.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
		end
	end)
	
	sliderBg.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local pos = UserInputService:GetMouseLocation()
			local relativeX = (pos.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X
			relativeX = math.clamp(relativeX, 0, 1)
			
			sliderFill.Size = UDim2.new(relativeX, 0, 1, 0)
			local value = min + (max - min) * relativeX
			value = math.floor(value * 100) / 100
			valueLabel.Text = tostring(value)
			
			if callback then callback(value) end
		end
	end)
	
	return container
end

-- Helper function to create toggle buttons
local function CreateToggle(name, order, callback)
	local container = Instance.new("Frame")
	container.Name = name .. "Toggle"
	container.Size = UDim2.new(1, 0, 0, 30)
	container.BackgroundTransparency = 1
	container.LayoutOrder = order
	container.Parent = scrollFrame
	
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.7, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = name
	label.TextColor3 = Color3.fromRGB(200, 200, 200)
	label.TextSize = 14
	label.Font = Enum.Font.Gotham
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = container
	
	local toggle = Instance.new("TextButton")
	toggle.Name = "Toggle"
	toggle.Size = UDim2.new(0, 50, 0, 24)
	toggle.Position = UDim2.new(1, -55, 0.5, -12)
	toggle.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
	toggle.Text = "OFF"
	toggle.TextColor3 = Color3.fromRGB(150, 150, 150)
	toggle.TextSize = 12
	toggle.Font = Enum.Font.GothamBold
	toggle.Parent = container
	
	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = UDim.new(0, 5)
	toggleCorner.Parent = toggle
	
	local enabled = false
	
	toggle.MouseButton1Click:Connect(function()
		enabled = not enabled
		if enabled then
			toggle.BackgroundColor3 = Color3.fromRGB(80, 180, 80)
			toggle.Text = "ON"
			toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
		else
			toggle.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
			toggle.Text = "OFF"
			toggle.TextColor3 = Color3.fromRGB(150, 150, 150)
		end
		if callback then callback(enabled) end
	end)
	
	return container, toggle
end

-- Helper function to create dropdown
local activeDropdown = nil -- Track active dropdown to close others

local function CreateDropdown(name, options, order, callback)
	local container = Instance.new("Frame")
	container.Name = name .. "Dropdown"
	container.Size = UDim2.new(1, 0, 0, 30)
	container.BackgroundTransparency = 1
	container.LayoutOrder = order
	container.Parent = scrollFrame
	
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.4, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = name
	label.TextColor3 = Color3.fromRGB(200, 200, 200)
	label.TextSize = 14
	label.Font = Enum.Font.Gotham
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = container
	
	local dropdown = Instance.new("TextButton")
	dropdown.Name = "Button"
	dropdown.Size = UDim2.new(0.55, 0, 0, 26)
	dropdown.Position = UDim2.new(0.45, 0, 0, 2)
	dropdown.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	dropdown.Text = options[1] or "Select..."
	dropdown.TextColor3 = Color3.fromRGB(255, 255, 255)
	dropdown.TextSize = 12
	dropdown.Font = Enum.Font.Gotham
	dropdown.Parent = container
	
	local dropCorner = Instance.new("UICorner")
	dropCorner.CornerRadius = UDim.new(0, 5)
	dropCorner.Parent = dropdown
	
	-- Parent options to screenGui so it's not clipped by scrollFrame
	local optionsList = Instance.new("Frame")
	optionsList.Name = "Options_" .. name
	optionsList.Size = UDim2.new(0, 150, 0, math.min(#options * 25, 150))
	optionsList.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	optionsList.BorderSizePixel = 2
	optionsList.BorderColor3 = Color3.fromRGB(80, 80, 100)
	optionsList.Visible = false
	optionsList.ZIndex = 100
	optionsList.Parent = screenGui
	
	local optCorner = Instance.new("UICorner")
	optCorner.CornerRadius = UDim.new(0, 5)
	optCorner.Parent = optionsList
	
	local optScroll = Instance.new("ScrollingFrame")
	optScroll.Size = UDim2.new(1, 0, 1, 0)
	optScroll.BackgroundTransparency = 1
	optScroll.ScrollBarThickness = 4
	optScroll.CanvasSize = UDim2.new(0, 0, 0, #options * 25)
	optScroll.ZIndex = 101
	optScroll.Parent = optionsList
	
	local optLayout = Instance.new("UIListLayout")
	optLayout.Parent = optScroll
	
	for i, opt in ipairs(options) do
		local optBtn = Instance.new("TextButton")
		optBtn.Size = UDim2.new(1, 0, 0, 25)
		optBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
		optBtn.BackgroundTransparency = 0.5
		optBtn.Text = opt
		optBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
		optBtn.TextSize = 12
		optBtn.Font = Enum.Font.Gotham
		optBtn.ZIndex = 102
		optBtn.Parent = optScroll
		
		optBtn.MouseEnter:Connect(function()
			optBtn.BackgroundTransparency = 0
		end)
		optBtn.MouseLeave:Connect(function()
			optBtn.BackgroundTransparency = 0.5
		end)
		
		optBtn.MouseButton1Click:Connect(function()
			dropdown.Text = opt
			optionsList.Visible = false
			activeDropdown = nil
			if callback then callback(opt) end
		end)
	end
	
	dropdown.MouseButton1Click:Connect(function()
		-- Close any other open dropdown
		if activeDropdown and activeDropdown ~= optionsList then
			activeDropdown.Visible = false
		end
		
		-- Position the dropdown below the button
		local absPos = dropdown.AbsolutePosition
		local absSize = dropdown.AbsoluteSize
		optionsList.Position = UDim2.new(0, absPos.X, 0, absPos.Y + absSize.Y + 2)
		optionsList.Size = UDim2.new(0, absSize.X, 0, math.min(#options * 25, 150))
		
		optionsList.Visible = not optionsList.Visible
		activeDropdown = optionsList.Visible and optionsList or nil
	end)
	
	return container
end

-- Store current modifications
local currentMods = {
	DamageMultiplier = 1.0,
	HPMultiplier = 1.0,
	RangeMultiplier = 1.0,
	AttackSpeedMultiplier = 1.0,
	ColorType = nil,
	Traits = {},
	Tags = {},
	GodMode = false,
	InfiniteRange = false,
	InstantKill = false,
}

-- Apply mods to selected tower
local function ApplyMods()
	local result = modMenuFunction:InvokeServer("ApplyMods", currentMods)
	if result then
		print("[ModMenu] Mods applied successfully")
	end
end

-- Get list of player's towers
local function GetPlayerTowers()
	local towers = {}
	local towersFolder = workspace:FindFirstChild("Towers")
	if towersFolder then
		for _, tower in ipairs(towersFolder:GetChildren()) do
			if tower:IsA("Model") then
				local config = tower:FindFirstChild("Config")
				if config then
					local owner = config:FindFirstChild("Owner")
					if owner and owner.Value == player.Name then
						table.insert(towers, tower.Name)
					end
				end
			end
		end
	end
	return towers
end

-- ===== CREATE UI ELEMENTS =====

-- TARGET SECTION
CreateSection("🎯 Target Tower (Apply to ALL your towers)", 1)

-- Info label
local infoContainer = Instance.new("Frame")
infoContainer.Name = "InfoContainer"
infoContainer.Size = UDim2.new(1, 0, 0, 25)
infoContainer.BackgroundTransparency = 1
infoContainer.LayoutOrder = 2
infoContainer.Parent = scrollFrame

local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, 0, 1, 0)
infoLabel.BackgroundTransparency = 1
infoLabel.Text = "Mods apply to ALL your placed towers"
infoLabel.TextColor3 = Color3.fromRGB(150, 200, 150)
infoLabel.TextSize = 12
infoLabel.Font = Enum.Font.GothamBold
infoLabel.Parent = infoContainer

-- STATS SECTION
CreateSection("📊 Stat Multipliers", 10)

CreateSlider("Damage", 0.1, 10, 1, 11, function(val)
	currentMods.DamageMultiplier = val
end)

CreateSlider("HP", 0.1, 10, 1, 12, function(val)
	currentMods.HPMultiplier = val
end)

CreateSlider("Range", 0.1, 5, 1, 13, function(val)
	currentMods.RangeMultiplier = val
end)

CreateSlider("Attack Speed", 0.1, 5, 1, 14, function(val)
	currentMods.AttackSpeedMultiplier = val
end)

-- COLOR TYPE SECTION
CreateSection("🎨 Color Type", 20)

local colorTypes = {"None"}
if ColorTypeSystem and ColorTypeSystem.Types then
	for colorType in pairs(ColorTypeSystem.Types) do
		table.insert(colorTypes, colorType)
	end
	table.sort(colorTypes)
end

CreateDropdown("Set ColorType", colorTypes, 21, function(colorType)
	currentMods.ColorType = colorType ~= "None" and colorType or nil
end)

-- TRAITS SECTION
CreateSection("⭐ Traits", 30)

local traitNames = {}
if TraitSystem and TraitSystem.Traits then
	for traitName in pairs(TraitSystem.Traits) do
		table.insert(traitNames, traitName)
	end
	table.sort(traitNames)
end

local traitOrder = 31
for _, traitName in ipairs(traitNames) do
	local traitData = TraitSystem.Traits[traitName]
	if traitData then
		CreateToggle(traitName .. " (" .. (traitData.Rarity or "?") .. ")", traitOrder, function(enabled)
			if enabled then
				currentMods.Traits[traitName] = true
			else
				currentMods.Traits[traitName] = nil
			end
		end)
		traitOrder = traitOrder + 1
	end
end

-- TAGS SECTION
CreateSection("🏷️ Tags", 100)

local allTags = {}
if TagSystem and TagSystem.ValidTags then
	for tag in pairs(TagSystem.ValidTags) do
		table.insert(allTags, tag)
	end
	table.sort(allTags)
end

local tagOrder = 101
for _, tagName in ipairs(allTags) do
	CreateToggle(tagName, tagOrder, function(enabled)
		if enabled then
			currentMods.Tags[tagName] = true
		else
			currentMods.Tags[tagName] = nil
		end
	end)
	tagOrder = tagOrder + 1
end

-- CHEATS SECTION
CreateSection("💀 Cheats (Testing Only)", 200)

CreateToggle("God Mode (No Damage)", 201, function(enabled)
	currentMods.GodMode = enabled
end)

CreateToggle("Infinite Range", 202, function(enabled)
	currentMods.InfiniteRange = enabled
end)

CreateToggle("Instant Kill", 203, function(enabled)
	currentMods.InstantKill = enabled
end)

-- APPLY BUTTON
local applyBtn = Instance.new("TextButton")
applyBtn.Name = "ApplyButton"
applyBtn.Size = UDim2.new(1, 0, 0, 40)
applyBtn.BackgroundColor3 = Color3.fromRGB(80, 180, 80)
applyBtn.Text = "✓ APPLY MODS TO ALL TOWERS"
applyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
applyBtn.TextSize = 16
applyBtn.Font = Enum.Font.GothamBold
applyBtn.LayoutOrder = 300
applyBtn.Parent = scrollFrame

local applyCorner = Instance.new("UICorner")
applyCorner.CornerRadius = UDim.new(0, 8)
applyCorner.Parent = applyBtn

applyBtn.MouseButton1Click:Connect(ApplyMods)

-- RESET BUTTON
local resetBtn = Instance.new("TextButton")
resetBtn.Name = "ResetButton"
resetBtn.Size = UDim2.new(1, 0, 0, 30)
resetBtn.BackgroundColor3 = Color3.fromRGB(180, 80, 80)
resetBtn.Text = "↺ Reset All Mods"
resetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
resetBtn.TextSize = 14
resetBtn.Font = Enum.Font.GothamBold
resetBtn.LayoutOrder = 301
resetBtn.Parent = scrollFrame

local resetCorner = Instance.new("UICorner")
resetCorner.CornerRadius = UDim.new(0, 8)
resetCorner.Parent = resetBtn

resetBtn.MouseButton1Click:Connect(function()
	modMenuFunction:InvokeServer("ResetMods")
	print("[ModMenu] All mods reset")
end)

-- Toggle visibility with chat command "/modmenu" or "/mm"
closeButton.MouseButton1Click:Connect(function()
	mainFrame.Visible = false
end)

-- Listen for chat commands
player.Chatted:Connect(function(message)
	local lowerMsg = message:lower()
	if lowerMsg == "/modmenu" or lowerMsg == "/mm" then
		mainFrame.Visible = not mainFrame.Visible
	end
end)

-- Make frame draggable
local dragging = false
local dragStart = nil
local startPos = nil

titleBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		startPos = mainFrame.Position
	end
end)

titleBar.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Position - dragStart
		mainFrame.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end
end)

print("[ModMenu] Loaded - Type /modmenu or /mm in chat to open")
