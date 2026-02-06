--[[
	GameConfig.lua
	Central configuration for all tweakable game values.
	Place in ReplicatedStorage.Shared so both client and server can access.
	
	Usage: local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
]]

local GameConfig = {}

--------------------------------------------------------------------------------
-- CURRENCY SETTINGS
--------------------------------------------------------------------------------
GameConfig.Currency = {
	-- Set to true during development for extra starting currency
	TestingMode = true,
	
	-- Gems (main summoning currency)
	Gems = {
		Starting = 100,
		TestingStarting = 10000,
	},
	
	-- Coins (earned from gameplay, used for upgrades)
	Coins = {
		Starting = 0,
		TestingStarting = 5000,
	},
	
	-- Tickets (premium currency, used for special summons)
	Tickets = {
		Starting = 0,
		TestingStarting = 10,
	},
}

--------------------------------------------------------------------------------
-- SUMMONING SETTINGS
--------------------------------------------------------------------------------
GameConfig.Summoning = {
	-- Cost for a single summon
	SingleSummonCost = 50,
	
	-- Cost for multi-summon (10 pulls)
	-- Discounted from 10x single cost (500 -> 450 = 10% discount)
	MultiSummonCost = 450,
	
	-- Number of pulls in a multi-summon
	MultiSummonCount = 10,
	
	-- Pity system: guaranteed legendary after this many summons without one
	LegendaryPityThreshold = 50,
	
	-- Pity system: guaranteed mythic after this many summons without one
	MythicPityThreshold = 100,
}

--------------------------------------------------------------------------------
-- RARITY SETTINGS
--------------------------------------------------------------------------------
GameConfig.Rarities = {
	Common = {
		Color = Color3.fromRGB(150, 150, 150),
		PullRate = 0.70, -- 70%
	},
	Rare = {
		Color = Color3.fromRGB(0, 150, 255),
		PullRate = 0.20, -- 20%
	},
	Epic = {
		Color = Color3.fromRGB(150, 0, 255),
		PullRate = 0.08, -- 8%
	},
	Legendary = {
		Color = Color3.fromRGB(255, 215, 0),
		PullRate = 0.015, -- 1.5%
	},
	Mythic = {
		Color = Color3.fromRGB(255, 0, 255),
		PullRate = 0.005, -- 0.5%
	},
}

-- Order for rarity checks (highest to lowest)
GameConfig.RarityOrder = {"Mythic", "Legendary", "Epic", "Rare", "Common"}

--------------------------------------------------------------------------------
-- LOADOUT SETTINGS
--------------------------------------------------------------------------------
GameConfig.Loadout = {
	-- Maximum number of towers in a loadout
	MaxSlots = 6,
}

--------------------------------------------------------------------------------
-- INVENTORY SETTINGS
--------------------------------------------------------------------------------
GameConfig.Inventory = {
	-- Maximum towers a player can hold (0 = unlimited)
	MaxCapacity = 0,
}

--------------------------------------------------------------------------------
-- DATA STORE SETTINGS
--------------------------------------------------------------------------------
GameConfig.DataStore = {
	-- DataStore names (change version suffix to wipe/migrate data)
	PlayerDataStoreName = "PlayerData_v11",
	LoadoutStoreName = "PlayerLoadouts_v11",
	
	-- Retry settings for DataStore operations
	MaxRetries = 3,
	RetryDelay = 1, -- seconds between retries
	
	-- Auto-save interval in seconds (0 = disabled)
	AutoSaveInterval = 300, -- 5 minutes
}

--------------------------------------------------------------------------------
-- TRAIT SYSTEM SETTINGS
--------------------------------------------------------------------------------
GameConfig.Traits = {
	-- Cost to reroll a single trait (in Coins)
	RerollCost = 100,
	
	-- Cost multiplier per reroll attempt (increases each time)
	RerollCostMultiplier = 1.5,
	
	-- Max reroll cost cap
	RerollCostCap = 1000,
}

--------------------------------------------------------------------------------
-- RELIC SYSTEM SETTINGS
--------------------------------------------------------------------------------
GameConfig.Relics = {
	-- Cost to upgrade a relic (base cost, scales with level)
	UpgradeCostBase = 50,
	UpgradeCostPerLevel = 25,
	
	-- Currency used for relic upgrades
	UpgradeCurrency = "Coins",
}

--------------------------------------------------------------------------------
-- EVOLUTION SYSTEM SETTINGS
--------------------------------------------------------------------------------
GameConfig.Evolution = {
	-- Cost to manually evolve (if player has enough XP)
	EvolveCost = 0, -- Free if XP requirement met
	
	-- Currency used for evolution
	EvolveCurrency = "Coins",
}

--------------------------------------------------------------------------------
-- DUPLICATE HANDLING
--------------------------------------------------------------------------------
GameConfig.Duplicates = {
	-- What happens when player gets a duplicate tower they already own
	-- Options: "keep" (keep duplicate), "convert" (convert to currency)
	Mode = "keep",
	
	-- If Mode is "convert", how many gems per rarity
	ConversionRates = {
		Common = 5,
		Rare = 15,
		Epic = 50,
		Legendary = 200,
		Mythic = 500,
	},
}

--------------------------------------------------------------------------------
-- SELL SYSTEM SETTINGS
--------------------------------------------------------------------------------
GameConfig.Selling = {
	-- Coins earned per unit rarity when selling
	CoinRates = {
		Common = 5,
		Rare = 15,
		Epic = 50,
		Legendary = 200,
		Mythic = 500,
	},
}

--------------------------------------------------------------------------------
-- HELPER FUNCTIONS
--------------------------------------------------------------------------------

-- Get starting amount for any currency based on testing mode
function GameConfig.GetStartingCurrency(currencyName)
	local currencyConfig = GameConfig.Currency[currencyName]
	if not currencyConfig then return 0 end
	
	if GameConfig.Currency.TestingMode then
		return currencyConfig.TestingStarting or currencyConfig.Starting or 0
	end
	return currencyConfig.Starting or 0
end

-- Shorthand for gems (backward compatibility)
function GameConfig.GetStartingGems()
	return GameConfig.GetStartingCurrency("Gems")
end

-- Get rarity color
function GameConfig.GetRarityColor(rarity)
	local rarityData = GameConfig.Rarities[rarity]
	if rarityData then
		return rarityData.Color
	end
	return Color3.fromRGB(255, 255, 255) -- Default white
end

return GameConfig
