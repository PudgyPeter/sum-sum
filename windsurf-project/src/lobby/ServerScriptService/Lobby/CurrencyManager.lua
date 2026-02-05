--[[
	CurrencyManager.lua
	Centralized currency management for all currency types.
	Handles gems, coins, tickets, and any future currencies.
	
	Usage:
		local CurrencyManager = require(script.Parent.CurrencyManager)
		CurrencyManager.Add(player, "Gems", 100)
		CurrencyManager.Spend(player, "Gems", 50)
		local balance = CurrencyManager.Get(player, "Gems")
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local CurrencyManager = {}

--------------------------------------------------------------------------------
-- CURRENCY DEFINITIONS
-- Add new currencies here. Each currency needs:
--   - StartingAmount: How much new players start with
--   - MaxAmount: Maximum allowed (0 = unlimited)
--   - CanGoNegative: Whether balance can go below 0
--------------------------------------------------------------------------------
CurrencyManager.Currencies = {
	Gems = {
		StartingAmount = function()
			return GameConfig.GetStartingCurrency("Gems")
		end,
		MaxAmount = 0, -- Unlimited
		CanGoNegative = false,
	},
	Coins = {
		StartingAmount = function()
			return GameConfig.GetStartingCurrency("Coins")
		end,
		MaxAmount = 0,
		CanGoNegative = false,
	},
	Tickets = {
		StartingAmount = function()
			return GameConfig.GetStartingCurrency("Tickets")
		end,
		MaxAmount = 0,
		CanGoNegative = false,
	},
	-- Add more currencies as needed:
	-- PremiumGems = { StartingAmount = 0, MaxAmount = 0, CanGoNegative = false },
	-- EventTokens = { StartingAmount = 0, MaxAmount = 0, CanGoNegative = false },
}

--------------------------------------------------------------------------------
-- INTERNAL HELPERS
--------------------------------------------------------------------------------

-- Get the IntValue for a currency
local function getCurrencyValue(player, currencyName)
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then return nil end
	return playerData:FindFirstChild(currencyName)
end

-- Get starting amount (handles function or number)
local function getStartingAmount(currencyName)
	local currency = CurrencyManager.Currencies[currencyName]
	if not currency then return 0 end
	
	if type(currency.StartingAmount) == "function" then
		return currency.StartingAmount()
	end
	return currency.StartingAmount or 0
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

-- Initialize all currencies for a player (called during SetupPlayer)
function CurrencyManager.InitializePlayer(playerDataFolder)
	for currencyName, currencyDef in pairs(CurrencyManager.Currencies) do
		local currencyValue = Instance.new("IntValue")
		currencyValue.Name = currencyName
		currencyValue.Value = getStartingAmount(currencyName)
		currencyValue.Parent = playerDataFolder
	end
end

-- Load currencies from saved data (deep merge with defaults)
function CurrencyManager.LoadFromData(playerDataFolder, savedData)
	for currencyName, _ in pairs(CurrencyManager.Currencies) do
		local currencyValue = playerDataFolder:FindFirstChild(currencyName)
		if currencyValue then
			-- Use saved value if exists, otherwise keep default
			if savedData and savedData[currencyName] ~= nil then
				currencyValue.Value = savedData[currencyName]
			end
		end
	end
end

-- Serialize all currencies for saving
function CurrencyManager.Serialize(player)
	local data = {}
	for currencyName, _ in pairs(CurrencyManager.Currencies) do
		local currencyValue = getCurrencyValue(player, currencyName)
		if currencyValue then
			data[currencyName] = currencyValue.Value
		end
	end
	return data
end

-- Get current balance of a currency
function CurrencyManager.Get(player, currencyName)
	local currencyValue = getCurrencyValue(player, currencyName)
	if currencyValue then
		return currencyValue.Value
	end
	return 0
end

-- Set currency to specific amount
function CurrencyManager.Set(player, currencyName, amount)
	local currencyValue = getCurrencyValue(player, currencyName)
	if not currencyValue then
		warn("[Currency] Currency not found:", currencyName, "for", player.Name)
		return false
	end
	
	local currency = CurrencyManager.Currencies[currencyName]
	if not currency then return false end
	
	-- Clamp to max if set
	if currency.MaxAmount > 0 then
		amount = math.min(amount, currency.MaxAmount)
	end
	
	-- Prevent negative if not allowed
	if not currency.CanGoNegative then
		amount = math.max(0, amount)
	end
	
	currencyValue.Value = amount
	return true
end

-- Add currency (positive amount)
function CurrencyManager.Add(player, currencyName, amount)
	if amount < 0 then
		warn("[Currency] Use Spend() for negative amounts")
		return false
	end
	
	local current = CurrencyManager.Get(player, currencyName)
	return CurrencyManager.Set(player, currencyName, current + amount)
end

-- Spend currency (returns false if insufficient funds)
function CurrencyManager.Spend(player, currencyName, amount)
	if amount < 0 then
		warn("[Currency] Spend amount must be positive")
		return false
	end
	
	local current = CurrencyManager.Get(player, currencyName)
	local currency = CurrencyManager.Currencies[currencyName]
	
	-- Check if player can afford it
	if not currency.CanGoNegative and current < amount then
		return false, "Insufficient " .. currencyName
	end
	
	return CurrencyManager.Set(player, currencyName, current - amount)
end

-- Check if player can afford an amount
function CurrencyManager.CanAfford(player, currencyName, amount)
	local current = CurrencyManager.Get(player, currencyName)
	return current >= amount
end

-- Modify currency (positive or negative, with tracking)
function CurrencyManager.Modify(player, currencyName, amount)
	if amount >= 0 then
		return CurrencyManager.Add(player, currencyName, amount)
	else
		return CurrencyManager.Spend(player, currencyName, math.abs(amount))
	end
end

-- Get all currency balances for a player
function CurrencyManager.GetAll(player)
	local balances = {}
	for currencyName, _ in pairs(CurrencyManager.Currencies) do
		balances[currencyName] = CurrencyManager.Get(player, currencyName)
	end
	return balances
end

-- Check if a currency type exists
function CurrencyManager.Exists(currencyName)
	return CurrencyManager.Currencies[currencyName] ~= nil
end

-- Get list of all currency names
function CurrencyManager.GetCurrencyNames()
	local names = {}
	for name, _ in pairs(CurrencyManager.Currencies) do
		table.insert(names, name)
	end
	return names
end

return CurrencyManager
