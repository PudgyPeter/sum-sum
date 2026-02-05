-- StatusEffects.lua
-- Defines all status effects and their base parameters
-- Each effect can be customized per character in TowerUpgradeData

local StatusEffects = {}

-- Effect type definitions with default parameters
StatusEffects.Effects = {
	-- BURN: Damage over time that resets on reapplication
	Burn = {
		Type = "DoT",
		TickDamage = 5,           -- Damage per tick (adjustable per character)
		TickRate = 0.5,           -- Time between ticks in seconds
		Duration = 3,             -- Total duration in seconds
		Stackable = false,        -- Reapplying resets timer instead of stacking
		Color = Color3.fromRGB(255, 100, 0), -- Visual indicator color
	},
	
	-- HELLFIRE: Weaker burn that boosts other burn effects
	Hellfire = {
		Type = "DoT",
		TickDamage = 3,           -- Lower damage than regular burn
		TickRate = 0.5,
		Duration = 4,
		Stackable = false,
		BurnBoostMultiplier = 1.2, -- Multiplies burn-type damage by 1.2x
		BoostStackable = false,   -- Boost doesn't stack (stays at 1.2x)
		Color = Color3.fromRGB(200, 0, 255), -- Purple-ish fire
	},
	
	-- BLACK FLAME: Permanent burn that absorbs other burn effects
	BlackFlame = {
		Type = "DoT",
		TickDamage = 2,           -- Starts weak
		TickRate = 0.5,
		Duration = math.huge,     -- Infinite duration
		Stackable = false,
		AbsorbMultiplier = 0.25,  -- Absorbs 1/4 of other burn damage
		AbsorbsBurnTypes = true,  -- Removes and absorbs Burn/Hellfire
		Color = Color3.fromRGB(50, 0, 100), -- Dark purple/black
	},
	
	-- BLEED: Stackable damage over time
	Bleed = {
		Type = "DoT",
		TickDamage = 2,           -- Low damage per stack (adjustable per character)
		TickRate = 0.5,
		Duration = 5,             -- Duration per stack (adjustable per character)
		Stackable = true,         -- Multiple applications stack
		MaxStacks = 10,           -- Maximum stacks allowed
		Color = Color3.fromRGB(150, 0, 0), -- Dark red
	},
	
	-- HEMORRHAGE: Heavy permanent bleed for bleed-focused characters
	Hemorrhage = {
		Type = "DoT",
		TickDamage = 15,          -- Heavy damage (adjustable per character)
		TickRate = 0.5,
		Duration = math.huge,     -- Permanent
		Stackable = false,
		RequiresBleedCharacter = true, -- Only certain characters can apply
		EnablesAbilities = true,  -- Can trigger special abilities
		Color = Color3.fromRGB(100, 0, 0), -- Very dark red
	},
	
	-- STUN: Prevents all movement and actions
	Stun = {
		Type = "Control",
		Duration = 2,             -- Duration in seconds (adjustable per character)
		SpeedMultiplier = 0,      -- Completely stops movement
		Stackable = false,        -- Reapplying resets timer
		Color = Color3.fromRGB(255, 255, 100), -- Yellow
	},
	
	-- SLOW: Reduces movement speed
	Slow = {
		Type = "Movement",
		Duration = 3,             -- Duration in seconds (adjustable per character)
		SpeedMultiplier = 0.5,    -- 50% speed (adjustable per character)
		Stackable = false,        -- Reapplying resets timer
		Color = Color3.fromRGB(100, 100, 150), -- Grayish blue
	},
	
	-- HYPNOTIZED: Defected enemy (placeholder for future team-switching mechanic)
	Hypnotized = {
		Type = "Control",
		Duration = 5,             -- Duration in seconds (adjustable per character)
		DefectsEnemy = true,      -- Makes enemy fight for player (WIP)
		Stackable = false,
		Color = Color3.fromRGB(200, 100, 200), -- Pink/purple
	},
}

-- Helper function to get effect data
function StatusEffects.GetEffect(effectName)
	return StatusEffects.Effects[effectName]
end

-- Helper function to check if effect is a burn type
function StatusEffects.IsBurnType(effectName)
	return effectName == "Burn" or effectName == "Hellfire" or effectName == "BlackFlame"
end

-- Helper function to check if effect is a DoT type
function StatusEffects.IsDoTType(effectName)
	local effect = StatusEffects.GetEffect(effectName)
	return effect and effect.Type == "DoT"
end

-- Helper function to check if effect is a control type
function StatusEffects.IsControlType(effectName)
	local effect = StatusEffects.GetEffect(effectName)
	return effect and (effect.Type == "Control" or effect.Type == "Movement")
end

-- Calculate total damage for a DoT effect over its duration
function StatusEffects.CalculateTotalDamage(effectName, tickDamage, duration)
	local effect = StatusEffects.GetEffect(effectName)
	if not effect or not StatusEffects.IsDoTType(effectName) then
		return 0
	end
	
	local ticks = math.floor(duration / effect.TickRate)
	return tickDamage * ticks
end

-- Calculate DPS for a DoT effect
function StatusEffects.CalculateDPS(effectName, tickDamage)
	local effect = StatusEffects.GetEffect(effectName)
	if not effect or not StatusEffects.IsDoTType(effectName) then
		return 0
	end
	
	return tickDamage / effect.TickRate
end

print("StatusEffects module loaded")

return StatusEffects
