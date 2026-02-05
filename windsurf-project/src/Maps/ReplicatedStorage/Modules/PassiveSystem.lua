--[[
	PassiveSystem.lua
	Passive abilities and auras system for units
	
	Usage:
		local PassiveSystem = require(path.to.PassiveSystem)
		PassiveSystem.ProcessAuras(allTowers)
		PassiveSystem.OnAttack(tower, target, player)
]]

local PassiveSystem = {}

-- Passive ability definitions
PassiveSystem.Passives = {
	-- Aura passives (affect nearby towers)
	DrumsOfLiberation = {
		Type = "Aura",
		Range = 30,
		Buffs = {AttackSpeedBonus = 0.20},
		Description = "Nearby towers attack 20% faster",
	},
	
	HakiPresence = {
		Type = "Aura",
		Range = 25,
		Buffs = {DamageBonus = 0.15},
		Description = "Nearby towers deal 15% more damage",
	},
	
	InspiringLeader = {
		Type = "Aura",
		Range = 35,
		Buffs = {AttackSpeedBonus = 0.10, DamageBonus = 0.10},
		Description = "Nearby towers gain 10% attack speed and damage",
	},
	
	-- On-kill passives
	GoldDigger = {
		Type = "OnKill",
		BonusCash = 5,
		Description = "Gain 5 extra cash on kill",
	},
	
	SoulReaper = {
		Type = "OnKill",
		XPBonus = 2,
		Description = "Gain double XP on kill",
	},
	
	Executioner = {
		Type = "OnKill",
		DamageStackPercent = 0.01,
		MaxStacks = 100,
		Description = "Gain 1% damage per kill, up to 100%",
	},
	
	-- On-hit passives (chance-based)
	BurningStrike = {
		Type = "OnHit",
		Chance = 0.10,
		StatusEffect = "Burn",
		TickDamagePercent = 0.10,
		Duration = 3,
		Description = "10% chance to burn target for 10% damage over 3s",
	},
	
	FrostTouch = {
		Type = "OnHit",
		Chance = 0.15,
		StatusEffect = "Slow",
		SlowPercent = 0.30,
		Duration = 2,
		Description = "15% chance to slow target by 30% for 2s",
	},
	
	ArmorBreaker = {
		Type = "OnHit",
		Chance = 0.20,
		ArmorReduction = 0.10,
		Duration = 5,
		Description = "20% chance to reduce target armor by 10% for 5s",
	},
	
	Lifesteal = {
		Type = "OnHit",
		Chance = 1.0, -- Always triggers
		HealPercent = 0.05,
		Description = "Heal for 5% of damage dealt",
	},
	
	-- Stacking passives (build up over attacks)
	Momentum = {
		Type = "Stacking",
		MaxStacks = 50,
		PerStack = {DamagePercent = 0.01},
		DecayAfter = 3, -- Seconds without attacking
		DecayAmount = 5, -- Stacks lost per decay tick
		Description = "Gain 1% damage per attack, up to 50%. Decays after 3s idle.",
	},
	
	Frenzy = {
		Type = "Stacking",
		MaxStacks = 30,
		PerStack = {AttackSpeedPercent = 0.01},
		DecayAfter = 2,
		DecayAmount = 3,
		Description = "Gain 1% attack speed per attack, up to 30%.",
	},
	
	-- Conditional passives
	GiantSlayer = {
		Type = "Conditional",
		Condition = "TargetIsBoss",
		Buffs = {DamageBonus = 0.50},
		Description = "Deal 50% more damage to bosses",
	},
	
	Underdog = {
		Type = "Conditional",
		Condition = "LowHP",
		Threshold = 0.30, -- Below 30% HP
		Buffs = {DamageBonus = 0.25, AttackSpeedBonus = 0.25},
		Description = "When below 30% HP, gain 25% damage and attack speed",
	},
	
	FirstStrike = {
		Type = "Conditional",
		Condition = "TargetFullHP",
		Buffs = {CritChanceBonus = 25},
		Description = "+25% crit chance against full HP targets",
	},
}

-- Runtime state tracking
local auraTargets = {} -- {[tower] = {affected towers}}
local stacks = {} -- {[tower] = {[passive] = {count, lastAttack}}}
local killStacks = {} -- {[tower] = {[passive] = count}}

-- Get passive definition
function PassiveSystem.GetPassive(passiveName: string): {[string]: any}?
	return PassiveSystem.Passives[passiveName]
end

-- Check if passive exists
function PassiveSystem.IsValidPassive(passiveName: string): boolean
	return PassiveSystem.Passives[passiveName] ~= nil
end

-- Get passive type
function PassiveSystem.GetPassiveType(passiveName: string): string?
	local passive = PassiveSystem.Passives[passiveName]
	return passive and passive.Type or nil
end

-- Get all passives of a specific type
function PassiveSystem.GetPassivesByType(passiveType: string): {string}
	local result = {}
	for name, data in pairs(PassiveSystem.Passives) do
		if data.Type == passiveType then
			table.insert(result, name)
		end
	end
	return result
end

-- Get passives from tower attributes
function PassiveSystem.GetTowerPassives(tower: any): {string}
	local passives = {}
	
	local passiveList = tower:GetAttribute("Passives")
	if passiveList then
		if type(passiveList) == "string" then
			for passive in string.gmatch(passiveList, "[^,]+") do
				table.insert(passives, passive:match("^%s*(.-)%s*$"))
			end
		end
	end
	
	return passives
end

-- Calculate stacking passive bonus
function PassiveSystem.GetStackBonus(tower: any, passiveName: string): {[string]: number}
	local bonuses = {}
	local passive = PassiveSystem.Passives[passiveName]
	
	if not passive or passive.Type ~= "Stacking" then
		return bonuses
	end
	
	local towerStacks = stacks[tower] and stacks[tower][passiveName]
	if not towerStacks then
		return bonuses
	end
	
	local count = towerStacks.count or 0
	for stat, value in pairs(passive.PerStack) do
		bonuses[stat] = value * count
	end
	
	return bonuses
end

-- Get kill stack count
function PassiveSystem.GetKillStacks(tower: any, passiveName: string): number
	return killStacks[tower] and killStacks[tower][passiveName] or 0
end

-- Add a stack (for stacking passives)
function PassiveSystem.AddStack(tower: any, passiveName: string)
	local passive = PassiveSystem.Passives[passiveName]
	if not passive or passive.Type ~= "Stacking" then
		return
	end
	
	stacks[tower] = stacks[tower] or {}
	stacks[tower][passiveName] = stacks[tower][passiveName] or {count = 0, lastAttack = 0}
	
	local s = stacks[tower][passiveName]
	s.count = math.min(s.count + 1, passive.MaxStacks)
	s.lastAttack = tick()
end

-- Add kill stack (for on-kill stacking)
function PassiveSystem.AddKillStack(tower: any, passiveName: string)
	local passive = PassiveSystem.Passives[passiveName]
	if not passive then
		return
	end
	
	killStacks[tower] = killStacks[tower] or {}
	local maxStacks = passive.MaxStacks or 100
	killStacks[tower][passiveName] = math.min((killStacks[tower][passiveName] or 0) + 1, maxStacks)
end

-- Process stack decay (should be called periodically)
function PassiveSystem.ProcessDecay(tower: any)
	if not stacks[tower] then
		return
	end
	
	local currentTime = tick()
	for passiveName, stackData in pairs(stacks[tower]) do
		local passive = PassiveSystem.Passives[passiveName]
		if passive and passive.DecayAfter then
			local timeSinceAttack = currentTime - stackData.lastAttack
			if timeSinceAttack >= passive.DecayAfter then
				stackData.count = math.max(0, stackData.count - (passive.DecayAmount or 1))
			end
		end
	end
end

-- Check if on-hit passive triggers
function PassiveSystem.CheckOnHitTrigger(passiveName: string): boolean
	local passive = PassiveSystem.Passives[passiveName]
	if not passive or passive.Type ~= "OnHit" then
		return false
	end
	
	return math.random() < (passive.Chance or 0)
end

-- Check conditional passive
function PassiveSystem.CheckCondition(passiveName: string, context: {[string]: any}): boolean
	local passive = PassiveSystem.Passives[passiveName]
	if not passive or passive.Type ~= "Conditional" then
		return false
	end
	
	local condition = passive.Condition
	
	if condition == "TargetIsBoss" then
		return context.target and context.target:FindFirstChild("BossType") ~= nil
	elseif condition == "LowHP" then
		local tower = context.tower
		if tower and tower:FindFirstChild("Humanoid") then
			local hpPercent = tower.Humanoid.Health / tower.Humanoid.MaxHealth
			return hpPercent < (passive.Threshold or 0.30)
		end
	elseif condition == "TargetFullHP" then
		local target = context.target
		if target and target:FindFirstChild("Humanoid") then
			return target.Humanoid.Health >= target.Humanoid.MaxHealth
		end
	end
	
	return false
end

-- Calculate total passive bonuses for a tower
function PassiveSystem.CalculateBonuses(tower: any, context: {[string]: any}?): {[string]: number}
	local bonuses = {}
	local passives = PassiveSystem.GetTowerPassives(tower)
	context = context or {}
	context.tower = tower
	
	for _, passiveName in ipairs(passives) do
		local passive = PassiveSystem.Passives[passiveName]
		if passive then
			-- Aura buffs (applied separately via ProcessAuras)
			-- Stacking bonuses
			if passive.Type == "Stacking" then
				local stackBonus = PassiveSystem.GetStackBonus(tower, passiveName)
				for stat, value in pairs(stackBonus) do
					bonuses[stat] = (bonuses[stat] or 0) + value
				end
			-- On-kill stacking
			elseif passive.Type == "OnKill" and passive.DamageStackPercent then
				local killCount = PassiveSystem.GetKillStacks(tower, passiveName)
				bonuses.DamagePercent = (bonuses.DamagePercent or 0) + (passive.DamageStackPercent * killCount)
			-- Conditional
			elseif passive.Type == "Conditional" and PassiveSystem.CheckCondition(passiveName, context) then
				for stat, value in pairs(passive.Buffs or {}) do
					bonuses[stat] = (bonuses[stat] or 0) + value
				end
			end
		end
	end
	
	return bonuses
end

-- Cleanup when tower is destroyed
function PassiveSystem.Cleanup(tower: any)
	auraTargets[tower] = nil
	stacks[tower] = nil
	killStacks[tower] = nil
end

-- Register a custom passive (for extensibility)
function PassiveSystem.RegisterPassive(name: string, data: {[string]: any})
	PassiveSystem.Passives[name] = data
end

return PassiveSystem
