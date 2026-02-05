--[[
	ModMenuHandler.lua
	Server-side handler for the Mod Menu
	Applies stat modifications, traits, colors, and tags to towers for testing
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local functions = ReplicatedStorage:WaitForChild("Functions")
local modules = ReplicatedStorage:WaitForChild("Modules")

local ColorTypeSystem = require(modules:WaitForChild("ColorTypeSystem"))
local TagSystem = require(modules:WaitForChild("TagSystem"))
local TraitSystem = require(modules:WaitForChild("TraitSystem"))

local ModMenuHandler = {}

-- Create or get the ModMenu remote function
local modMenuFunction = functions:FindFirstChild("ModMenu")
if not modMenuFunction then
	modMenuFunction = Instance.new("RemoteFunction")
	modMenuFunction.Name = "ModMenu"
	modMenuFunction.Parent = functions
end

-- Store active mods per player
local playerMods = {}

-- Store original tower stats for reset
local originalStats = {}

-- Get the selected tower for a player (last clicked tower they own)
local function GetSelectedTower(player)
	local selectedTower = player:GetAttribute("SelectedTower")
	if selectedTower then
		local tower = workspace.Towers:FindFirstChild(selectedTower)
		if tower then
			local owner = tower:FindFirstChild("Config") and tower.Config:FindFirstChild("Owner")
			if owner and owner.Value == player.Name then
				return tower
			end
		end
	end
	return nil
end

-- Store original stats before modifying
local function StoreOriginalStats(tower)
	if originalStats[tower] then return end
	
	local config = tower:FindFirstChild("Config")
	if not config then return end
	
	originalStats[tower] = {
		Damage = config:FindFirstChild("Damage") and config.Damage.Value or nil,
		Range = config:FindFirstChild("Range") and config.Range.Value or nil,
		Cooldown = config:FindFirstChild("Cooldown") and config.Cooldown.Value or nil,
		ColorType = config:GetAttribute("ColorType"),
		Tags = config:GetAttribute("Tags"),
	}
end

-- Apply stat multipliers to a tower
local function ApplyStatMods(tower, mods)
	local config = tower:FindFirstChild("Config")
	if not config then return false end
	
	StoreOriginalStats(tower)
	local orig = originalStats[tower]
	
	-- Damage multiplier
	if mods.DamageMultiplier and orig.Damage then
		local dmgValue = config:FindFirstChild("Damage")
		if dmgValue then
			dmgValue.Value = orig.Damage * mods.DamageMultiplier
		end
	end
	
	-- Range multiplier
	if mods.RangeMultiplier and orig.Range then
		local rangeValue = config:FindFirstChild("Range")
		if rangeValue then
			rangeValue.Value = orig.Range * mods.RangeMultiplier
		end
	end
	
	-- Attack speed (cooldown) multiplier - inverse relationship
	if mods.AttackSpeedMultiplier and orig.Cooldown then
		local cooldownValue = config:FindFirstChild("Cooldown")
		if cooldownValue then
			cooldownValue.Value = orig.Cooldown / mods.AttackSpeedMultiplier
		end
	end
	
	-- Infinite range cheat
	if mods.InfiniteRange then
		local rangeValue = config:FindFirstChild("Range")
		if rangeValue then
			rangeValue.Value = 9999
		end
	end
	
	-- Instant kill cheat
	if mods.InstantKill then
		local dmgValue = config:FindFirstChild("Damage")
		if dmgValue then
			dmgValue.Value = 999999
		end
	end
	
	return true
end

-- Apply color type to a tower
local function ApplyColorType(tower, colorType)
	local config = tower:FindFirstChild("Config")
	if not config then return false end
	
	if colorType and ColorTypeSystem.Types[colorType] then
		config:SetAttribute("ColorType", colorType)
		print("[ModMenu] Set ColorType to", colorType, "for", tower.Name)
	end
	
	return true
end

-- Apply traits to a tower
local function ApplyTraits(tower, traits)
	local config = tower:FindFirstChild("Config")
	if not config then return false end
	
	-- Create or get traits folder
	local traitsFolder = config:FindFirstChild("ModdedTraits")
	if not traitsFolder then
		traitsFolder = Instance.new("Folder")
		traitsFolder.Name = "ModdedTraits"
		traitsFolder.Parent = config
	else
		traitsFolder:ClearAllChildren()
	end
	
	-- Add enabled traits
	for traitName, enabled in pairs(traits) do
		if enabled and TraitSystem.Traits[traitName] then
			local traitValue = Instance.new("StringValue")
			traitValue.Name = traitName
			traitValue.Value = traitName
			traitValue.Parent = traitsFolder
			
			-- Apply trait effects to stats
			local traitData = TraitSystem.Traits[traitName]
			if traitData.Effects then
				for stat, value in pairs(traitData.Effects) do
					if stat == "Damage" then
						local dmg = config:FindFirstChild("Damage")
						if dmg then dmg.Value = dmg.Value * (1 + value) end
					elseif stat == "Range" then
						local range = config:FindFirstChild("Range")
						if range then range.Value = range.Value * (1 + value) end
					elseif stat == "AttackSpeed" then
						local cooldown = config:FindFirstChild("Cooldown")
						if cooldown then cooldown.Value = cooldown.Value / (1 + value) end
					end
				end
			end
		end
	end
	
	print("[ModMenu] Applied", traitsFolder and #traitsFolder:GetChildren() or 0, "traits to", tower.Name)
	return true
end

-- Apply tags to a tower
local function ApplyTags(tower, tags)
	local config = tower:FindFirstChild("Config")
	if not config then return false end
	
	local tagList = {}
	for tagName, enabled in pairs(tags) do
		if enabled and TagSystem.ValidTags[tagName] then
			table.insert(tagList, tagName)
		end
	end
	
	if #tagList > 0 then
		config:SetAttribute("Tags", table.concat(tagList, ","))
		print("[ModMenu] Set Tags to", table.concat(tagList, ", "), "for", tower.Name)
	end
	
	return true
end

-- Reset a tower to original stats
local function ResetTower(tower)
	if not originalStats[tower] then return false end
	
	local config = tower:FindFirstChild("Config")
	if not config then return false end
	
	local orig = originalStats[tower]
	
	if orig.Damage then
		local dmg = config:FindFirstChild("Damage")
		if dmg then dmg.Value = orig.Damage end
	end
	
	if orig.Range then
		local range = config:FindFirstChild("Range")
		if range then range.Value = orig.Range end
	end
	
	if orig.Cooldown then
		local cooldown = config:FindFirstChild("Cooldown")
		if cooldown then cooldown.Value = orig.Cooldown end
	end
	
	if orig.ColorType then
		config:SetAttribute("ColorType", orig.ColorType)
	end
	
	if orig.Tags then
		config:SetAttribute("Tags", orig.Tags)
	end
	
	-- Remove modded traits
	local moddedTraits = config:FindFirstChild("ModdedTraits")
	if moddedTraits then
		moddedTraits:Destroy()
	end
	
	originalStats[tower] = nil
	print("[ModMenu] Reset", tower.Name, "to original stats")
	return true
end

-- Handle mod menu requests
modMenuFunction.OnServerInvoke = function(player, action, data)
	print("[ModMenu] Request from", player.Name, "- Action:", action)
	
	if action == "ApplyMods" then
		-- Apply to all owned towers if no specific target
		local towersModified = 0
		
		for _, tower in ipairs(workspace.Towers:GetChildren()) do
			if tower:IsA("Model") then
				local config = tower:FindFirstChild("Config")
				if config then
					local owner = config:FindFirstChild("Owner")
					if owner and owner.Value == player.Name then
						ApplyStatMods(tower, data)
						
						if data.ColorType then
							ApplyColorType(tower, data.ColorType)
						end
						
						if data.Traits then
							ApplyTraits(tower, data.Traits)
						end
						
						if data.Tags then
							ApplyTags(tower, data.Tags)
						end
						
						towersModified = towersModified + 1
					end
				end
			end
		end
		
		-- Store mods for future towers
		playerMods[player.UserId] = data
		
		return {Success = true, TowersModified = towersModified}
		
	elseif action == "ResetMods" then
		local towersReset = 0
		
		for _, tower in ipairs(workspace.Towers:GetChildren()) do
			if tower:IsA("Model") then
				local config = tower:FindFirstChild("Config")
				if config then
					local owner = config:FindFirstChild("Owner")
					if owner and owner.Value == player.Name then
						if ResetTower(tower) then
							towersReset = towersReset + 1
						end
					end
				end
			end
		end
		
		playerMods[player.UserId] = nil
		
		return {Success = true, TowersReset = towersReset}
		
	elseif action == "GetTowers" then
		local towers = {}
		
		for _, tower in ipairs(workspace.Towers:GetChildren()) do
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
		
		return towers
	end
	
	return {Success = false, Error = "Unknown action"}
end

-- Apply stored mods to newly placed towers
workspace.Towers.ChildAdded:Connect(function(tower)
	task.wait(0.1) -- Wait for tower to be fully set up
	
	if not tower:IsA("Model") then return end
	
	local config = tower:FindFirstChild("Config")
	if not config then return end
	
	local owner = config:FindFirstChild("Owner")
	if not owner then return end
	
	-- Find player
	local player = Players:FindFirstChild(owner.Value)
	if not player then return end
	
	-- Check if player has active mods
	local mods = playerMods[player.UserId]
	if not mods then return end
	
	print("[ModMenu] Auto-applying mods to new tower:", tower.Name)
	
	ApplyStatMods(tower, mods)
	
	if mods.ColorType then
		ApplyColorType(tower, mods.ColorType)
	end
	
	if mods.Traits then
		ApplyTraits(tower, mods.Traits)
	end
	
	if mods.Tags then
		ApplyTags(tower, mods.Tags)
	end
end)

-- Cleanup on player leave
Players.PlayerRemoving:Connect(function(player)
	playerMods[player.UserId] = nil
end)

print("[ModMenuHandler] Loaded - Debug mod menu ready")

return ModMenuHandler
