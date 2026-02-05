--[[
	TagSystem.lua
	Unit tags and synergy bonuses system
	
	Usage:
		local TagSystem = require(path.to.TagSystem)
		local bonus = TagSystem.GetMapBonus(unitTags, "GrandLine")
		local synergies = TagSystem.CalculateTeamSynergy(teamUnits)
]]

local TagSystem = {}

-- Tag categories
TagSystem.Categories = {
	ANIME = {"OnePiece", "Naruto", "DragonBall", "Bleach", "JJK", "DemonSlayer", "AOT", "MHA"},
	FACTION = {"StrawHat", "Akatsuki", "Saiyan", "Marine", "Shinigami", "Hashira", "SurveyCorps", "Espada", "Gotei13"},
	ROLE = {"Captain", "Swordsman", "Support", "Tank", "Assassin", "Healer", "Buffer", "DPS", "Controller"},
	STYLE = {"Melee", "Ranged", "Magic", "AOE", "SingleTarget", "DoT", "Burst"},
}

-- Build valid tags lookup
TagSystem.ValidTags = {}
for cat, tags in pairs(TagSystem.Categories) do
	for _, tag in ipairs(tags) do
		TagSystem.ValidTags[tag] = cat
	end
end

-- Map-specific buffs for thematic bonuses
TagSystem.MapBuffs = {
	GrandLine = {Tags = {"OnePiece", "StrawHat", "Marine"}, Bonus = 0.20},
	HiddenLeaf = {Tags = {"Naruto", "Akatsuki"}, Bonus = 0.20},
	Namek = {Tags = {"DragonBall", "Saiyan"}, Bonus = 0.20},
	SoulSociety = {Tags = {"Bleach", "Shinigami", "Gotei13", "Espada"}, Bonus = 0.20},
	ShibuyaStation = {Tags = {"JJK"}, Bonus = 0.25},
	DemonSlayerVillage = {Tags = {"DemonSlayer", "Hashira"}, Bonus = 0.20},
	Paradis = {Tags = {"AOT", "SurveyCorps"}, Bonus = 0.20},
	UAHighSchool = {Tags = {"MHA"}, Bonus = 0.20},
}

-- Synergy thresholds and bonuses
TagSystem.SynergyBonus = {
	ANIME = {[3] = 0.10, [5] = 0.20},
	FACTION = {[3] = 0.15, [5] = 0.25},
	ROLE = {[4] = 0.10, [6] = 0.15}, -- Diversity bonus (different roles)
}

-- Maximum total synergy bonus cap
TagSystem.MaxSynergyTotal = 0.50

-- Get map bonus for a unit based on tags
function TagSystem.GetMapBonus(unitTags: {string}?, mapId: string?): number
	if not unitTags or not mapId then
		return 0
	end
	
	local buff = TagSystem.MapBuffs[mapId]
	if not buff then
		return 0
	end
	
	for _, tag in ipairs(unitTags) do
		for _, buffTag in ipairs(buff.Tags) do
			if tag == buffTag then
				return buff.Bonus
			end
		end
	end
	
	return 0
end

-- Validate tags against known valid tags
function TagSystem.ValidateTags(tags: {string}?): {string}
	if not tags then
		return {}
	end
	
	local validatedTags = {}
	for _, tag in ipairs(tags) do
		if TagSystem.ValidTags[tag] then
			table.insert(validatedTags, tag)
		else
			warn("[TagSystem] Unknown tag:", tag)
		end
	end
	return validatedTags
end

-- Get the category of a tag
function TagSystem.GetTagCategory(tag: string?): string?
	return tag and TagSystem.ValidTags[tag] or nil
end

-- Calculate team synergy bonuses based on deployed units
-- teamUnits: array of {Tags = {"tag1", "tag2"}, ...}
function TagSystem.CalculateTeamSynergy(teamUnits: {{Tags: {string}}}): {Damage: number, AttackSpeed: number, Range: number}
	local result = {Damage = 0, AttackSpeed = 0, Range = 0}
	
	if not teamUnits or #teamUnits == 0 then
		return result
	end
	
	local categoryCounts = {}
	
	-- Count tags by category
	for _, unit in ipairs(teamUnits) do
		for _, tag in ipairs(unit.Tags or {}) do
			local cat = TagSystem.ValidTags[tag]
			if cat then
				categoryCounts[cat] = categoryCounts[cat] or {}
				categoryCounts[cat][tag] = (categoryCounts[cat][tag] or 0) + 1
			end
		end
	end
	
	-- Calculate synergy bonuses
	for cat, tagCounts in pairs(categoryCounts) do
		local bonus = TagSystem.SynergyBonus[cat]
		if bonus then
			local maxCount = 0
			for _, count in pairs(tagCounts) do
				maxCount = math.max(maxCount, count)
			end
			
			-- Check thresholds (apply highest matching)
			local appliedBonus = 0
			for threshold, value in pairs(bonus) do
				if maxCount >= threshold and value > appliedBonus then
					appliedBonus = value
				end
			end
			result.Damage = result.Damage + appliedBonus
		end
	end
	
	-- Cap total synergy
	result.Damage = math.min(result.Damage, TagSystem.MaxSynergyTotal)
	
	return result
end

-- Get all tags a unit has in a specific category
function TagSystem.GetTagsInCategory(unitTags: {string}?, category: string): {string}
	local result = {}
	if not unitTags then
		return result
	end
	
	for _, tag in ipairs(unitTags) do
		if TagSystem.ValidTags[tag] == category then
			table.insert(result, tag)
		end
	end
	return result
end

-- Check if unit has a specific tag
function TagSystem.HasTag(unitTags: {string}?, targetTag: string): boolean
	if not unitTags or not targetTag then
		return false
	end
	
	for _, tag in ipairs(unitTags) do
		if tag == targetTag then
			return true
		end
	end
	return false
end

-- Check if unit has any tag from a list
function TagSystem.HasAnyTag(unitTags: {string}?, targetTags: {string}): boolean
	if not unitTags or not targetTags then
		return false
	end
	
	for _, tag in ipairs(unitTags) do
		for _, target in ipairs(targetTags) do
			if tag == target then
				return true
			end
		end
	end
	return false
end

return TagSystem
