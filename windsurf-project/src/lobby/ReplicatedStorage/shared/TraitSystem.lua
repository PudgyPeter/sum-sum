--[[
	TraitSystem.lua
	Random unit traits system
	
	Usage:
		local TraitSystem = require(path.to.TraitSystem)
		local traits = TraitSystem.Generate("Epic")
		local bonuses = TraitSystem.Calculate(traits)
]]

local TraitSystem = {}

-- Trait definitions with categories and effects
TraitSystem.Traits = {
	-- Offensive traits
	Berserker = {Category = "Offensive", Rarity = "Rare", Effects = {Damage = 0.30, Defense = -0.20}, Description = "+30% damage, -20% defense"},
	Precision = {Category = "Offensive", Rarity = "Rare", Effects = {CritChance = 15}, Description = "+15% crit chance"},
	Relentless = {Category = "Offensive", Rarity = "Epic", Effects = {ArmorPen = 0.20}, Description = "+20% armor penetration"},
	Deadly = {Category = "Offensive", Rarity = "Epic", Effects = {CritDamage = 0.50}, Description = "+50% crit damage"},
	Savage = {Category = "Offensive", Rarity = "Legendary", Effects = {Damage = 0.20, CritChance = 10, CritDamage = 0.25}, Description = "+20% damage, +10% crit, +25% crit damage"},
	
	-- Defensive traits
	Fortified = {Category = "Defensive", Rarity = "Rare", Effects = {HP = 0.25}, Description = "+25% HP"},
	Regeneration = {Category = "Defensive", Rarity = "Rare", Effects = {HPRegen = 0.01}, Description = "+1% HP regen per second"},
	Resilient = {Category = "Defensive", Rarity = "Epic", Effects = {Defense = 0.20, HP = 0.10}, Description = "+20% defense, +10% HP"},
	Unyielding = {Category = "Defensive", Rarity = "Legendary", Effects = {HP = 0.30, Defense = 0.15, HPRegen = 0.005}, Description = "+30% HP, +15% defense, +0.5% regen"},
	
	-- Utility traits
	Swift = {Category = "Utility", Rarity = "Common", Effects = {AttackSpeed = 0.15}, Description = "+15% attack speed"},
	FarSight = {Category = "Utility", Rarity = "Common", Effects = {Range = 0.20}, Description = "+20% range"},
	Economy = {Category = "Utility", Rarity = "Rare", Effects = {CashBonus = 0.10}, Description = "+10% cash from kills"},
	Experienced = {Category = "Utility", Rarity = "Rare", Effects = {XPBonus = 0.25}, Description = "+25% XP gain"},
	Tactical = {Category = "Utility", Rarity = "Epic", Effects = {AttackSpeed = 0.10, Range = 0.10, CooldownReduction = 0.10}, Description = "+10% speed, range, and CDR"},
	
	-- Special traits
	Elemental = {Category = "Special", Rarity = "Epic", Effects = {TypeDamageBonus = 0.15}, Description = "+15% type advantage damage"},
	Vampiric = {Category = "Special", Rarity = "Epic", Effects = {Lifesteal = 0.10}, Description = "+10% lifesteal"},
	Lucky = {Category = "Special", Rarity = "Legendary", Effects = {CritChance = 10, CashBonus = 0.15, XPBonus = 0.15}, Description = "+10% crit, +15% cash and XP"},
}

-- Rarity weights for trait generation
TraitSystem.RarityWeights = {
	Common = 50,
	Rare = 30,
	Epic = 15,
	Legendary = 5,
}

-- Number of traits based on unit rarity
TraitSystem.CountByRarity = {
	Common = {0, 1},
	Rare = {1, 1},
	Epic = {1, 2},
	Legendary = {1, 2},
	Mythic = {2, 3},
}

-- Categories that can't have multiple traits
TraitSystem.ExclusiveCategories = {"Offensive", "Defensive", "Special"}

-- Get trait definition
function TraitSystem.GetTrait(traitName: string): {[string]: any}?
	return TraitSystem.Traits[traitName]
end

-- Check if trait exists
function TraitSystem.IsValidTrait(traitName: string): boolean
	return TraitSystem.Traits[traitName] ~= nil
end

-- Get all traits in a category
function TraitSystem.GetTraitsByCategory(category: string): {string}
	local result = {}
	for name, data in pairs(TraitSystem.Traits) do
		if data.Category == category then
			table.insert(result, name)
		end
	end
	return result
end

-- Get all traits of a rarity
function TraitSystem.GetTraitsByRarity(rarity: string): {string}
	local result = {}
	for name, data in pairs(TraitSystem.Traits) do
		if data.Rarity == rarity then
			table.insert(result, name)
		end
	end
	return result
end

-- Generate random traits based on unit rarity
function TraitSystem.Generate(unitRarity: string): {string}
	local range = TraitSystem.CountByRarity[unitRarity] or {0, 1}
	local count = math.random(range[1], range[2])
	
	if count == 0 then
		return {}
	end
	
	-- Build weighted pool
	local pool = {}
	for name, data in pairs(TraitSystem.Traits) do
		local weight = TraitSystem.RarityWeights[data.Rarity or "Common"] or 10
		for i = 1, weight do
			table.insert(pool, name)
		end
	end
	
	local usedCategories = {}
	local result = {}
	
	for i = 1, count do
		-- Try to find a valid trait (max 50 attempts to avoid infinite loop)
		for attempt = 1, 50 do
			local name = pool[math.random(#pool)]
			local trait = TraitSystem.Traits[name]
			local category = trait.Category
			
			-- Check if category is exclusive and already used
			local isExclusive = table.find(TraitSystem.ExclusiveCategories, category)
			if not isExclusive or not usedCategories[category] then
				-- Check if trait already selected
				if not table.find(result, name) then
					table.insert(result, name)
					if isExclusive then
						usedCategories[category] = true
					end
					break
				end
			end
		end
	end
	
	return result
end

-- Calculate total bonuses from traits
function TraitSystem.Calculate(traits: {string}): {[string]: number}
	local bonuses = {}
	
	for _, name in ipairs(traits) do
		local trait = TraitSystem.Traits[name]
		if trait and trait.Effects then
			for stat, value in pairs(trait.Effects) do
				bonuses[stat] = (bonuses[stat] or 0) + value
			end
		end
	end
	
	return bonuses
end

-- Get description of all traits
function TraitSystem.GetDescriptions(traits: {string}): {[string]: string}
	local descriptions = {}
	
	for _, name in ipairs(traits) do
		local trait = TraitSystem.Traits[name]
		if trait then
			descriptions[name] = trait.Description or "No description"
		end
	end
	
	return descriptions
end

-- Reroll a specific trait (for reroll mechanics)
function TraitSystem.Reroll(currentTraits: {string}, traitToReroll: string, unitRarity: string): {string}
	local newTraits = {}
	local usedCategories = {}
	
	-- Copy existing traits except the one being rerolled
	for _, name in ipairs(currentTraits) do
		if name ~= traitToReroll then
			table.insert(newTraits, name)
			local trait = TraitSystem.Traits[name]
			if trait and table.find(TraitSystem.ExclusiveCategories, trait.Category) then
				usedCategories[trait.Category] = true
			end
		end
	end
	
	-- Generate a new trait
	local pool = {}
	for name, data in pairs(TraitSystem.Traits) do
		-- Skip already used traits
		if table.find(newTraits, name) then
			continue
		end
		
		-- Skip if exclusive category already used
		local isExclusive = table.find(TraitSystem.ExclusiveCategories, data.Category)
		if isExclusive and usedCategories[data.Category] then
			continue
		end
		
		local weight = TraitSystem.RarityWeights[data.Rarity or "Common"] or 10
		for i = 1, weight do
			table.insert(pool, name)
		end
	end
	
	if #pool > 0 then
		local newTrait = pool[math.random(#pool)]
		table.insert(newTraits, newTrait)
	end
	
	return newTraits
end

-- Register a custom trait (for extensibility)
function TraitSystem.RegisterTrait(name: string, data: {[string]: any})
	TraitSystem.Traits[name] = data
end

return TraitSystem
