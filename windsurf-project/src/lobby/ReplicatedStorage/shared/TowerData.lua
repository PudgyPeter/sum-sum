--[[
	TowerData.lua
	Defines all towers and their properties.
	Rarity rates and colors come from GameConfig.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Try to get GameConfig (may not exist in all places)
local GameConfig
local success = pcall(function()
	local Shared = ReplicatedStorage:WaitForChild("Shared", 5)
	if Shared then
		GameConfig = require(Shared:WaitForChild("GameConfig", 5))
	end
end)

local TowerData = {}

-- Get rarities from GameConfig or use fallback
local function getRarities()
	if GameConfig and GameConfig.Rarities then
		return GameConfig.Rarities
	end
	-- Fallback if GameConfig not available
	return {
		Common = { Color = Color3.fromRGB(150, 150, 150), PullRate = 0.70 },
		Rare = { Color = Color3.fromRGB(0, 150, 255), PullRate = 0.20 },
		Epic = { Color = Color3.fromRGB(150, 0, 255), PullRate = 0.08 },
		Legendary = { Color = Color3.fromRGB(255, 215, 0), PullRate = 0.015 },
		Mythic = { Color = Color3.fromRGB(255, 0, 255), PullRate = 0.005 },
	}
end

-- Get pity thresholds from GameConfig or use fallback
local function getPityThresholds()
	if GameConfig and GameConfig.Summoning then
		return {
			Legendary = GameConfig.Summoning.LegendaryPityThreshold,
			Mythic = GameConfig.Summoning.MythicPityThreshold,
		}
	end
	-- Fallback
	return { Legendary = 50, Mythic = 100 }
end

-- Expose rarities (reads from GameConfig)
TowerData.Rarities = getRarities()

-- All available towers with their rarities, types, and tags
TowerData.Towers = {
----------------------------------------------------------------------------------------------------------------------------------	
-------------------------------------------------- COMMON TOWERS ------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------
	{
		ID = "Silver_hog",
		Name = "Silver",
		Rarity = "Common",
		Description = "Basic ranged tower with decent attack speed",
		ModelName = "Silver",
		ColorType = "GRN", -- Green type
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
-------------------------------------------------- MYTHIC TOWERS --------------------------------------------------------------
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

-- Get tower by ID
function TowerData.GetTowerById(id)
	for _, tower in ipairs(TowerData.Towers) do
		if tower.ID == id then
			return tower
		end
	end
	return nil
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

-- Get random tower based on rarity rates
-- pityCounter = summons since last legendary
-- mythicPityCounter = summons since last mythic (optional)
function TowerData.GetRandomTower(pityCounter, mythicPityCounter)
	-- Safety check: if no towers exist, return nil
	if #TowerData.Towers == 0 then
		warn("[TowerData] No towers defined!")
		return nil
	end

	local rarities = getRarities()
	local pityThresholds = getPityThresholds()
	local rand = math.random()
	local cumulativeRate = 0

	-- Check if mythic pity triggers first (higher priority)
	if mythicPityCounter and pityThresholds.Mythic and mythicPityCounter >= pityThresholds.Mythic then
		local mythicTowers = TowerData.GetTowersByRarity("Mythic")
		if #mythicTowers > 0 then
			return mythicTowers[math.random(1, #mythicTowers)]
		end
		warn("[TowerData] Mythic pity triggered but no Mythic towers exist!")
	end

	-- Check if legendary pity triggers
	if pityCounter and pityThresholds.Legendary and pityCounter >= pityThresholds.Legendary then
		local legendaryTowers = TowerData.GetTowersByRarity("Legendary")
		if #legendaryTowers > 0 then
			return legendaryTowers[math.random(1, #legendaryTowers)]
		end
		warn("[TowerData] Legendary pity triggered but no Legendary towers exist!")
	end

	-- Normal random pull
	local rarityOrder = GameConfig and GameConfig.RarityOrder or {"Mythic", "Legendary", "Epic", "Rare", "Common"}
	local selectedRarity = nil

	for _, rarity in ipairs(rarityOrder) do
		if rarities[rarity] then
			cumulativeRate = cumulativeRate + rarities[rarity].PullRate
			if rand <= cumulativeRate then
				selectedRarity = rarity
				break
			end
		end
	end

	-- Get random tower from selected rarity
	local towersInRarity = TowerData.GetTowersByRarity(selectedRarity)
	if #towersInRarity > 0 then
		return towersInRarity[math.random(1, #towersInRarity)]
	end

	-- Fallback: try each rarity in order until we find one with towers
	for _, rarity in ipairs({"Common", "Rare", "Epic", "Legendary", "Mythic"}) do
		local towers = TowerData.GetTowersByRarity(rarity)
		if #towers > 0 then
			warn("[TowerData] Selected rarity had no towers, falling back to", rarity)
			return towers[math.random(1, #towers)]
		end
	end

	-- Last resort: return any random tower
	warn("[TowerData] No towers found in any rarity, returning random tower")
	return TowerData.Towers[math.random(1, #TowerData.Towers)]
end

-- Get rarity color (from GameConfig)
function TowerData.GetRarityColor(rarity)
	local rarities = getRarities()
	if rarities[rarity] then
		return rarities[rarity].Color
	end
	return Color3.fromRGB(255, 255, 255)
end

return TowerData
