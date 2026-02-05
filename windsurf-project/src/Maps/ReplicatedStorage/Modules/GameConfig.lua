--[[
	GameConfig.lua
	Central configuration for game settings and constants.
]]

local GameConfig = {}

--------------------------------------------------------------------------------
-- CURRENCY SETTINGS
--------------------------------------------------------------------------------

GameConfig.Currency = {
	StartingGems = 1000,
	StartingCoins = 500,
	StartingTickets = 5,
}

-- Get starting currency amount by type
function GameConfig.GetStartingCurrency(currencyType)
	if currencyType == "Gems" then
		return GameConfig.Currency.StartingGems
	elseif currencyType == "Coins" then
		return GameConfig.Currency.StartingCoins
	elseif currencyType == "Tickets" then
		return GameConfig.Currency.StartingTickets
	else
		return 0
	end
end

--------------------------------------------------------------------------------
-- LOADOUT SETTINGS
--------------------------------------------------------------------------------

GameConfig.Loadout = {
	MaxSlots = 6,
	DefaultSlots = 3,
}

--------------------------------------------------------------------------------
-- GAME SETTINGS
--------------------------------------------------------------------------------

GameConfig.Game = {
	StartingCash = 100,
	BaseHealth = 100,
	WaveDelay = 5, -- seconds between waves
}

--------------------------------------------------------------------------------
-- SUMMONING SETTINGS
--------------------------------------------------------------------------------

GameConfig.Summoning = {
	CostPerSummon = 100,
	PityThreshold = 50, -- Guaranteed legendary every 50 summons
	MythicPityThreshold = 100, -- Guaranteed mythic every 100 summons
}

--------------------------------------------------------------------------------
-- DATASTORE SETTINGS (must match lobby's GameConfig)
--------------------------------------------------------------------------------

GameConfig.DataStore = {
	-- DataStore names (change version suffix to wipe/migrate data)
	-- IMPORTANT: Keep these in sync with lobby's GameConfig!
	PlayerDataStoreName = "PlayerData_v8",
	LoadoutStoreName = "PlayerLoadouts_v8",
	
	-- Retry settings for DataStore operations
	MaxRetries = 3,
	RetryDelay = 1,
}

return GameConfig
