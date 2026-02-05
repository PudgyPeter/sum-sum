--[[
	AbilitySystem.lua
	Active abilities system for units
	
	Usage:
		local AbilitySystem = require(path.to.AbilitySystem)
		local canUse, reason = AbilitySystem.CanUse(tower, "KingKongGun")
		local success = AbilitySystem.Use(tower, "KingKongGun", target, player)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbilitySystem = {}

-- Cooldown tracking per tower
local cooldowns = {} -- {[tower] = {[abilityName] = lastUsedTime}}

-- Ability definitions
-- Note: Execute functions should be overridden by server to include actual logic
AbilitySystem.Abilities = {
	-- One Piece
	KingKongGun = {
		Cooldown = 60,
		Type = "Damage",
		Description = "Massive punch dealing 10x damage to a single target",
		DamageMultiplier = 10,
		TargetType = "Single",
	},
	
	ConquerorsHaki = {
		Cooldown = 45,
		Type = "AOE",
		Range = 30,
		Description = "Stuns all enemies in range for 3 seconds",
		Duration = 3,
		TargetType = "AOE",
	},
	
	JetPistol = {
		Cooldown = 15,
		Type = "Damage",
		Description = "Fast punch dealing 3x damage",
		DamageMultiplier = 3,
		TargetType = "Single",
	},
	
	ElephantGun = {
		Cooldown = 30,
		Type = "Damage",
		Description = "Enlarged fist dealing 5x damage with knockback",
		DamageMultiplier = 5,
		TargetType = "Single",
		Knockback = 10,
	},
	
	OniGiri = {
		Cooldown = 20,
		Type = "Damage",
		Description = "Triple slash dealing 4x damage",
		DamageMultiplier = 4,
		TargetType = "Single",
	},
	
	Ashura = {
		Cooldown = 45,
		Type = "AOE",
		Range = 15,
		Description = "9-sword style attack hitting all enemies in range for 6x damage",
		DamageMultiplier = 6,
		TargetType = "AOE",
	},
	
	-- Naruto
	Rasengan = {
		Cooldown = 20,
		Type = "Damage",
		Description = "Spiraling sphere dealing 4x damage",
		DamageMultiplier = 4,
		TargetType = "Single",
	},
	
	RasenshUriken = {
		Cooldown = 35,
		Type = "AOE",
		Range = 20,
		Description = "Wind-enhanced rasengan hitting all enemies in range",
		DamageMultiplier = 5,
		TargetType = "AOE",
	},
	
	ShadowClone = {
		Cooldown = 40,
		Type = "Summon",
		Description = "Creates 3 shadow clones that deal 50% damage for 15 seconds",
		CloneCount = 3,
		CloneDamagePercent = 0.5,
		Duration = 15,
		TargetType = "Self",
	},
	
	TailedBeastBomb = {
		Cooldown = 60,
		Type = "AOE",
		Range = 40,
		Description = "Massive energy ball dealing 8x damage in a huge area",
		DamageMultiplier = 8,
		TargetType = "AOE",
	},
	
	-- Generic abilities
	PowerStrike = {
		Cooldown = 15,
		Type = "Damage",
		Description = "Enhanced attack dealing 3x damage",
		DamageMultiplier = 3,
		TargetType = "Single",
	},
	
	WarCry = {
		Cooldown = 30,
		Type = "Buff",
		Range = 25,
		Description = "Boosts all nearby towers' damage by 25% for 10 seconds",
		BuffAmount = 0.25,
		Duration = 10,
		TargetType = "AlliesAOE",
	},
	
	HealingAura = {
		Cooldown = 25,
		Type = "Heal",
		Range = 20,
		Description = "Heals all nearby allies",
		HealPercent = 0.20,
		TargetType = "AlliesAOE",
	},
}

-- Check if an ability can be used
function AbilitySystem.CanUse(tower: any, abilityName: string): (boolean, string?)
	local def = AbilitySystem.Abilities[abilityName]
	if not def then
		return false, "Unknown ability"
	end
	
	local last = cooldowns[tower] and cooldowns[tower][abilityName]
	if last and tick() - last < def.Cooldown then
		local remaining = def.Cooldown - (tick() - last)
		return false, string.format("%.1fs cooldown", remaining)
	end
	
	return true, nil
end

-- Get remaining cooldown for an ability
function AbilitySystem.GetCooldown(tower: any, abilityName: string): number
	local def = AbilitySystem.Abilities[abilityName]
	if not def then
		return 0
	end
	
	local last = cooldowns[tower] and cooldowns[tower][abilityName]
	if not last then
		return 0
	end
	
	local remaining = def.Cooldown - (tick() - last)
	return math.max(0, remaining)
end

-- Get cooldown as a percentage (0 = ready, 1 = just used)
function AbilitySystem.GetCooldownPercent(tower: any, abilityName: string): number
	local def = AbilitySystem.Abilities[abilityName]
	if not def then
		return 0
	end
	
	local remaining = AbilitySystem.GetCooldown(tower, abilityName)
	return remaining / def.Cooldown
end

-- Start cooldown for an ability (called by server after successful use)
function AbilitySystem.StartCooldown(tower: any, abilityName: string)
	cooldowns[tower] = cooldowns[tower] or {}
	cooldowns[tower][abilityName] = tick()
end

-- Get ability definition
function AbilitySystem.GetAbility(abilityName: string): {[string]: any}?
	return AbilitySystem.Abilities[abilityName]
end

-- Get all abilities for a tower
function AbilitySystem.GetTowerAbilities(tower: any): {string}
	local abilities = {}
	
	-- Check tower attributes for ability list
	local abilityList = tower:GetAttribute("Abilities")
	if abilityList then
		-- Parse comma-separated string or return table
		if type(abilityList) == "string" then
			for ability in string.gmatch(abilityList, "[^,]+") do
				table.insert(abilities, ability:match("^%s*(.-)%s*$")) -- Trim whitespace
			end
		end
	end
	
	return abilities
end

-- Check if ability exists
function AbilitySystem.IsValidAbility(abilityName: string): boolean
	return AbilitySystem.Abilities[abilityName] ~= nil
end

-- Cleanup cooldowns for a destroyed tower
function AbilitySystem.Cleanup(tower: any)
	cooldowns[tower] = nil
end

-- Register a custom ability (for extensibility)
function AbilitySystem.RegisterAbility(name: string, data: {[string]: any})
	AbilitySystem.Abilities[name] = data
end

-- Get abilities by type
function AbilitySystem.GetAbilitiesByType(abilityType: string): {string}
	local result = {}
	for name, data in pairs(AbilitySystem.Abilities) do
		if data.Type == abilityType then
			table.insert(result, name)
		end
	end
	return result
end

return AbilitySystem
