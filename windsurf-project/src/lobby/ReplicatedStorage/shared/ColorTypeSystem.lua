--[[
	ColorTypeSystem.lua
	Elemental type advantages system for damage multipliers
	
	Usage:
		local ColorTypeSystem = require(path.to.ColorTypeSystem)
		local mult = ColorTypeSystem.GetDamageMultiplier("RED", "YEL")
]]

local ColorTypeSystem = {}

-- Type definitions with relationships
-- ImageId: Replace with your Roblox asset IDs (rbxassetid://XXXXXXX)
ColorTypeSystem.Types = {
		RED = {Name = "Fire", Color = Color3.fromRGB(255, 20, 20), StrongAgainst = "YEL", WeakAgainst = "BLU", ImageId = "rbxassetid://100606913825975"},
	YEL = {Name = "Lightning", Color = Color3.fromRGB(255, 198, 26), StrongAgainst = "PUR", WeakAgainst = "RED", ImageId = "rbxassetid://94085292748940"},
	PUR = {Name = "Shadow", Color = Color3.fromRGB(160, 6, 255), StrongAgainst = "GRN", WeakAgainst = "YEL", ImageId = "rbxassetid://112538491812503"},
	GRN = {Name = "Nature", Color = Color3.fromRGB(36, 220, 33), StrongAgainst = "BLU", WeakAgainst = "PUR", ImageId = "rbxassetid://133963631601218"},
	BLU = {Name = "Water", Color = Color3.fromRGB(17, 112, 255), StrongAgainst = "RED", WeakAgainst = "GRN", ImageId = "rbxassetid://113350576194356"},
	LIGHT = {Name = "Holy", Color = Color3.fromRGB(255, 255, 226), StrongAgainst = "DARK", WeakAgainst = "DARK", ImageId = "rbxassetid://130913462019729"},
	DARK = {Name = "Void", Color = Color3.fromRGB(111, 84, 150), StrongAgainst = "LIGHT", WeakAgainst = "LIGHT", ImageId = "rbxassetid://89165904195114"},
}

-- Configurable multipliers
ColorTypeSystem.Multipliers = {
	Advantage = 1.3,
	Disadvantage = 0.7,
	Neutral = 1.0,
	Mutual = 1.2, -- LIGHT vs DARK (both strong against each other)
}

-- Pre-built lookup cache for O(1) access
local cache = {}
for aType, aData in pairs(ColorTypeSystem.Types) do
	cache[aType] = {}
	for dType in pairs(ColorTypeSystem.Types) do
		if aData.StrongAgainst == dType then
			-- LIGHT/DARK mutual advantage
			if (aType == "LIGHT" or aType == "DARK") then
				cache[aType][dType] = ColorTypeSystem.Multipliers.Mutual
			else
				cache[aType][dType] = ColorTypeSystem.Multipliers.Advantage
			end
		elseif aData.WeakAgainst == dType then
			cache[aType][dType] = ColorTypeSystem.Multipliers.Disadvantage
		else
			cache[aType][dType] = ColorTypeSystem.Multipliers.Neutral
		end
	end
end

-- Get damage multiplier between attacker and defender types
function ColorTypeSystem.GetDamageMultiplier(attackerType: string?, defenderType: string?): number
	if not attackerType or not defenderType then
		return 1.0
	end
	return cache[attackerType] and cache[attackerType][defenderType] or 1.0
end

-- Get the color for a type
function ColorTypeSystem.GetTypeColor(colorType: string?): Color3
	if not colorType or not ColorTypeSystem.Types[colorType] then
		return Color3.new(1, 1, 1)
	end
	return ColorTypeSystem.Types[colorType].Color
end

-- Get the display name for a type
function ColorTypeSystem.GetTypeName(colorType: string?): string
	if not colorType or not ColorTypeSystem.Types[colorType] then
		return "Neutral"
	end
	return ColorTypeSystem.Types[colorType].Name
end

-- Get the image ID for a type
function ColorTypeSystem.GetTypeImage(colorType: string?): string
	if not colorType or not ColorTypeSystem.Types[colorType] then
		return ""
	end
	return ColorTypeSystem.Types[colorType].ImageId or ""
end

-- Check if attacker has advantage over defender
function ColorTypeSystem.HasAdvantage(attackerType: string?, defenderType: string?): boolean
	return ColorTypeSystem.GetDamageMultiplier(attackerType, defenderType) > 1
end

-- Check if attacker has disadvantage against defender
function ColorTypeSystem.HasDisadvantage(attackerType: string?, defenderType: string?): boolean
	return ColorTypeSystem.GetDamageMultiplier(attackerType, defenderType) < 1
end

-- Get all types as a list
function ColorTypeSystem.GetAllTypes(): {string}
	local types = {}
	for typeKey in pairs(ColorTypeSystem.Types) do
		table.insert(types, typeKey)
	end
	return types
end

-- Validate if a type exists
function ColorTypeSystem.IsValidType(colorType: string?): boolean
	return colorType ~= nil and ColorTypeSystem.Types[colorType] ~= nil
end

return ColorTypeSystem
