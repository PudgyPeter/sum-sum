--[[
	TowerData.lua
	Defines all towers and their properties.
	Mirrors lobby/shared/TowerData.lua for consistency.
]]

local TowerData = {}

-- All available towers with their rarities, types, and tags
TowerData.Towers = {
----------------------------------------------------------------------------------------------------------------------------------	
-------------------------------------------------- COMMON TOWERS -----------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------
	{
		ID = "Silver_hog",
		Name = "Silver",
		Rarity = "Common",
		Description = "Basic ranged tower with decent attack speed",
		ModelName = "Silver",
		ColorType = "GRN",
		Tags = {"SonicTheHedgehog", "Ranged", "Support"},
	},
--[[
----------------------------------------------------------------------------------------------------------------------------------	
-------------------------------------------------- RARE TOWERS -------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------
	{
		ID = "Luffy_Base",
		Name = "Luffy",
		Rarity = "Rare",
		Description = "Rubber pirate with stretchy attacks",
		ModelName = "Luffy",
		ColorType = "RED",
		Tags = {"OnePiece", "StrawHat", "Captain", "Melee"},
	},
	{
		ID = "Naruto_Base",
		Name = "Naruto",
		Rarity = "Rare",
		Description = "Ninja with shadow clone jutsu",
		ModelName = "Naruto",
		ColorType = "YEL",
		Tags = {"Naruto", "Konoha", "Jinchuriki", "Melee"},
	},

----------------------------------------------------------------------------------------------------------------------------------	
-------------------------------------------------- EPIC TOWERS -------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------
	{
		ID = "Zoro_Base",
		Name = "Zoro",
		Rarity = "Epic",
		Description = "Three-sword style swordsman",
		ModelName = "Zoro",
		ColorType = "GRN",
		Tags = {"OnePiece", "StrawHat", "Swordsman", "Melee"},
	},
	{
		ID = "Sasuke_Base",
		Name = "Sasuke",
		Rarity = "Epic",
		Description = "Uchiha prodigy with Sharingan",
		ModelName = "Sasuke",
		ColorType = "PUR",
		Tags = {"Naruto", "Uchiha", "Ranged", "AOE"},
	},

----------------------------------------------------------------------------------------------------------------------------------	
-------------------------------------------------- LEGENDARY TOWERS --------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------
	{
		ID = "Goku_Base",
		Name = "Goku",
		Rarity = "Legendary",
		Description = "Saiyan warrior with incredible power",
		ModelName = "Goku",
		ColorType = "YEL",
		Tags = {"DragonBall", "Saiyan", "Melee", "AOE"},
	},
	{
		ID = "Ichigo_Base",
		Name = "Ichigo",
		Rarity = "Legendary",
		Description = "Substitute Soul Reaper",
		ModelName = "Ichigo",
		ColorType = "BLU",
		Tags = {"Bleach", "SoulReaper", "Swordsman", "Melee"},
	},

----------------------------------------------------------------------------------------------------------------------------------	
-------------------------------------------------- MYTHIC TOWERS -----------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------
	{
		ID = "Saitama_Base",
		Name = "Saitama",
		Rarity = "Mythic",
		Description = "One Punch Man - defeats enemies in one hit",
		ModelName = "Saitama",
		ColorType = "LIGHT",
		Tags = {"OnePunchMan", "Hero", "Melee", "Boss"},
	},
	]]
}

-- Get tower by ID
function TowerData.GetTowerById(id)
	for _, tower in ipairs(TowerData.Towers) do
		if tower.ID == id then
			return tower
		end
	end
	return nil
end

-- Get tower ColorType
function TowerData.GetColorType(towerId)
	local tower = TowerData.GetTowerById(towerId)
	return tower and tower.ColorType or "GRN"
end

-- Get tower Tags
function TowerData.GetTags(towerId)
	local tower = TowerData.GetTowerById(towerId)
	return tower and tower.Tags or {}
end

-- Get all towers of a specific rarity
function TowerData.GetTowersByRarity(rarity)
	local towers = {}
	for _, tower in ipairs(TowerData.Towers) do
		if tower.Rarity == rarity then
			table.insert(towers, tower)
		end
	end
	return towers
end

-- Get all towers with a specific tag
function TowerData.GetTowersByTag(tag)
	local towers = {}
	for _, tower in ipairs(TowerData.Towers) do
		if tower.Tags and table.find(tower.Tags, tag) then
			table.insert(towers, tower)
		end
	end
	return towers
end

-- Get all towers of a specific ColorType
function TowerData.GetTowersByColorType(colorType)
	local towers = {}
	for _, tower in ipairs(TowerData.Towers) do
		if tower.ColorType == colorType then
			table.insert(towers, tower)
		end
	end
	return towers
end

return TowerData
