--[[
	RelicSystem.lua
	Equipment/Relic system for units
	
	Usage:
		local RelicSystem = require(path.to.RelicSystem)
		local relic = RelicSystem.Generate("Weapon", "Epic", "Warrior")
		local bonuses = RelicSystem.Calculate(equippedRelics)
]]

local HttpService = game:GetService("HttpService")

local RelicSystem = {}

-- Equipment slots
RelicSystem.Slots = {"Weapon", "Armor", "Accessory", "Artifact"}

-- Set bonuses (2-piece and 4-piece)
RelicSystem.Sets = {
	Warrior = {
		[2] = {Damage = 0.15},
		[4] = {Damage = 0.30, ArmorPen = 0.10},
		Description = "Offensive set focused on raw damage",
	},
	Guardian = {
		[2] = {HP = 0.20},
		[4] = {HP = 0.40, Reflect = 0.05},
		Description = "Defensive set for tankiness",
	},
	Swift = {
		[2] = {AttackSpeed = 0.10},
		[4] = {AttackSpeed = 0.25},
		Description = "Speed-focused set",
	},
	Vampire = {
		[2] = {Lifesteal = 0.05},
		[4] = {Lifesteal = 0.15},
		Description = "Sustain through lifesteal",
	},
	Precision = {
		[2] = {CritChance = 10},
		[4] = {CritChance = 20, CritDamage = 0.30},
		Description = "Critical strike focused",
	},
	Sage = {
		[2] = {Range = 0.15},
		[4] = {Range = 0.30, CooldownReduction = 0.15},
		Description = "Utility and ability focused",
	},
	Fortune = {
		[2] = {CashBonus = 0.10},
		[4] = {CashBonus = 0.25, XPBonus = 0.15},
		Description = "Economy focused",
	},
}

-- Rarity multipliers for stats
RelicSystem.RarityMult = {
	Common = 1.0,
	Rare = 1.25,
	Epic = 1.5,
	Legendary = 2.0,
	Mythic = 2.5,
}

-- Number of substats by rarity
RelicSystem.SubstatCount = {
	Common = 1,
	Rare = 2,
	Epic = 3,
	Legendary = 4,
	Mythic = 4,
}

-- Main stats by slot
RelicSystem.MainStats = {
	Weapon = {"Damage", "CritDamage"},
	Armor = {"HP", "Defense"},
	Accessory = {"CritChance", "Range"},
	Artifact = {"CooldownReduction", "AbilityDamage"},
}

-- Substat pool
RelicSystem.SubstatPool = {"Damage", "HP", "AttackSpeed", "CritChance", "CritDamage", "Range", "Defense", "Lifesteal"}

-- Base values for main stats
RelicSystem.MainStatBaseValues = {
	Damage = 10,
	CritDamage = 0.15,
	HP = 100,
	Defense = 10,
	CritChance = 5,
	Range = 5,
	CooldownReduction = 0.05,
	AbilityDamage = 0.10,
}

-- Base values for substats (typically 50% of main stat)
RelicSystem.SubstatBaseValues = {
	Damage = 5,
	HP = 50,
	AttackSpeed = 0.03,
	CritChance = 3,
	CritDamage = 0.08,
	Range = 2,
	Defense = 5,
	Lifesteal = 0.02,
}

-- Generate a new relic
function RelicSystem.Generate(slot: string, rarity: string, setName: string?): {[string]: any}
	-- Validate slot
	if not table.find(RelicSystem.Slots, slot) then
		warn("[RelicSystem] Invalid slot:", slot)
		return nil
	end
	
	-- Get multiplier
	local mult = RelicSystem.RarityMult[rarity] or 1.0
	
	-- Pick main stat
	local mainStatOptions = RelicSystem.MainStats[slot]
	local mainStat = mainStatOptions[math.random(#mainStatOptions)]
	local mainValue = (RelicSystem.MainStatBaseValues[mainStat] or 10) * mult
	
	-- Generate substats
	local substats = {}
	local substatCount = RelicSystem.SubstatCount[rarity] or 1
	local availableSubstats = {}
	
	-- Copy pool excluding main stat
	for _, stat in ipairs(RelicSystem.SubstatPool) do
		if stat ~= mainStat then
			table.insert(availableSubstats, stat)
		end
	end
	
	-- Pick random substats
	for i = 1, substatCount do
		if #availableSubstats > 0 then
			local idx = math.random(#availableSubstats)
			local stat = availableSubstats[idx]
			local baseValue = RelicSystem.SubstatBaseValues[stat] or 5
			substats[stat] = baseValue * mult * (0.8 + math.random() * 0.4) -- 80-120% variance
			table.remove(availableSubstats, idx)
		end
	end
	
	-- Validate set if provided
	if setName and not RelicSystem.Sets[setName] then
		setName = nil
	end
	
	return {
		ID = HttpService:GenerateGUID(false),
		Slot = slot,
		Rarity = rarity,
		Set = setName,
		MainStat = mainStat,
		MainValue = mainValue,
		Substats = substats,
		Level = 0,
		MaxLevel = rarity == "Mythic" and 20 or rarity == "Legendary" and 16 or rarity == "Epic" and 12 or 8,
	}
end

-- Calculate total bonuses from equipped relics
function RelicSystem.Calculate(equippedRelics: {[string]: {[string]: any}}): {[string]: number}
	local bonuses = {}
	local setCounts = {}
	
	for slot, relic in pairs(equippedRelics) do
		if relic then
			-- Add main stat
			bonuses[relic.MainStat] = (bonuses[relic.MainStat] or 0) + relic.MainValue
			
			-- Add substats
			for stat, value in pairs(relic.Substats or {}) do
				bonuses[stat] = (bonuses[stat] or 0) + value
			end
			
			-- Count set pieces
			if relic.Set then
				setCounts[relic.Set] = (setCounts[relic.Set] or 0) + 1
			end
		end
	end
	
	-- Apply set bonuses
	for setName, count in pairs(setCounts) do
		local setData = RelicSystem.Sets[setName]
		if setData then
			for threshold, bonus in pairs(setData) do
				if type(threshold) == "number" and count >= threshold then
					for stat, value in pairs(bonus) do
						bonuses[stat] = (bonuses[stat] or 0) + value
					end
				end
			end
		end
	end
	
	return bonuses
end

-- Get set bonus info
function RelicSystem.GetSetBonus(setName: string, pieceCount: number): {[string]: number}?
	local setData = RelicSystem.Sets[setName]
	if not setData then
		return nil
	end
	
	local bonuses = {}
	for threshold, bonus in pairs(setData) do
		if type(threshold) == "number" and pieceCount >= threshold then
			for stat, value in pairs(bonus) do
				bonuses[stat] = (bonuses[stat] or 0) + value
			end
		end
	end
	
	return bonuses
end

-- Check if relic can be equipped in slot
function RelicSystem.CanEquip(relic: {[string]: any}, slot: string): boolean
	return relic and relic.Slot == slot
end

-- Upgrade relic (increase level)
function RelicSystem.Upgrade(relic: {[string]: any}): boolean
	if not relic or relic.Level >= relic.MaxLevel then
		return false
	end
	
	relic.Level = relic.Level + 1
	
	-- Increase main stat by 10% per level
	relic.MainValue = relic.MainValue * 1.10
	
	-- Every 4 levels, increase a random substat
	if relic.Level % 4 == 0 then
		local substatNames = {}
		for stat in pairs(relic.Substats) do
			table.insert(substatNames, stat)
		end
		
		if #substatNames > 0 then
			local stat = substatNames[math.random(#substatNames)]
			relic.Substats[stat] = relic.Substats[stat] * 1.20
		end
	end
	
	return true
end

-- Get all available sets
function RelicSystem.GetSets(): {string}
	local sets = {}
	for name in pairs(RelicSystem.Sets) do
		table.insert(sets, name)
	end
	return sets
end

-- Get set description
function RelicSystem.GetSetDescription(setName: string): string?
	local setData = RelicSystem.Sets[setName]
	return setData and setData.Description or nil
end

-- Validate relic structure
function RelicSystem.IsValidRelic(relic: {[string]: any}?): boolean
	if not relic then
		return false
	end
	
	return relic.ID ~= nil and
		relic.Slot ~= nil and
		table.find(RelicSystem.Slots, relic.Slot) ~= nil and
		relic.MainStat ~= nil and
		relic.MainValue ~= nil
end

return RelicSystem
