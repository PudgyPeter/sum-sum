-- Shared/TowerUpgradeData
-- This module is accessible from both server and client

local UpgradeData = {}

-- Rewards/Items configuration for mission completion
-- Each item can be awarded on victory
UpgradeData.Rewards = {
	Gems = {
		name = "Gems",
		imageId = "rbxassetid://135875932386277",
		amountPerWin = 20,
	},
	-- Add more reward items here as needed
	-- Example:
	-- Coins = {
	--     name = "Coins",
	--     imageId = "rbxassetid://123456789",
	--     amountPerWin = 100,
	-- },
}

-- Define upgrades per tower type
-- Towers can have 1-3 paths (A, B, C) and an optional Paragon upgrade
UpgradeData["Silver"] = {
	-- Tower information for tooltip
	Info = "A swift warrior wielding silver blades. Balanced between damage and attack speed, Silver excels at consistent DPS against single targets.",
	
	-- Base stats for the tower
	CritChance = 5, -- 5% crit chance
	CritDamage = 2, -- 2x damage multiplier on crit
	StatusType = "Burn", -- Apply Burn status effect
	
	-- Status effect configuration (customize per character)
	StatusEffect = {
		TickDamage = 3,      -- 3 damage per tick
		Duration = 4,        -- Lasts 4 seconds
		-- TickRate is defined in StatusEffects.lua (0.5s for Burn)
	}
	
	-- Color coding for upgrade paths (optional, defaults to generic colors if not specified)
	PathColors = {
		A = Color3.fromRGB(255, 100, 100), -- Red for damage-focused path
		B = Color3.fromRGB(100, 150, 255), -- Blue for range-focused path
		C = Color3.fromRGB(255, 220, 100), -- Yellow for speed-focused path
	},
	A = {
		[1] = { damage = 2, cost = 100, name = "Sharp Blades" },
		[2] = { damage = 4, cost = 150, name = "Razor Edge" },
		[3] = { damage = 8, cost = 250, name = "Steel Storm" },
		[4] = { damage = 15, cost = 500, name = "Silver Slash" },
		[5] = { damage = 25, cost = 1000, name = "Moonlight Fury" },
		[6] = { damage = 50, cost = 2500, name = "Celestial Blade" },
	},
	B = {
		[1] = { range = 5, cost = 120, name = "Eagle Eye" },
		[2] = { range = 10, cost = 200, name = "Far Sight" },
		[3] = { range = 15, cost = 400, name = "Sniper Vision" },
	},
	C = {
		[1] = { spa = -0.1, cost = 150, name = "Quick Draw" },
		[2] = { spa = -0.2, cost = 300, name = "Rapid Fire" },
		[3] = { spa = -0.3, cost = 600, name = "Lightning Speed" },
		[4] = { spa = -0.1, cost = 700, name = "Blur" },
		[5] = { spa = -0.2, cost = 800, name = "Time Warp" },
		[6] = { spa = -0.3, cost = 1200, name = "Instant Strike" },
	},
	-- Optional Paragon upgrade
	-- Requirements: any path at tier 6 (primary) + any other path at tier 3 (secondary)
	Paragon = {
		requiresPrimary = 6,  -- One path must be at this level
		requiresSecondary = 3, -- Another path must be at this level
		cost = 50000,
		name = "ULTIMATE SILVER WARRIOR",
		damage = 100,
		range = 20,
		spa = -0.5,
		model = "SuperSilver"
	}
}

-- Example: Tower with only 2 paths, no paragon
--[[
UpgradeData["ExampleTwoPath"] = {
	A = {
		[1] = { damage = 5, cost = 200, name = "Power Strike" },
		-- ... up to tier 6
	},
	B = {
		[1] = { range = 8, cost = 180, name = "Long Reach" },
		-- ... up to tier 6
	},
	-- No C path
	-- No Paragon
}
]]

-- Example: Tower with 3 paths and paragon
--[[
UpgradeData["ExampleThreePath"] = {
	A = {
		[1] = { damage = 10, cost = 300, name = "Form Alpha" },
		-- ... up to tier 6
	},
	B = {
		[1] = { spa = -0.15, cost = 250, name = "Form Beta" },
		-- ... up to tier 6
	},
	C = {
		[1] = { range = 12, cost = 280, name = "Form Gamma" },
		-- ... up to tier 6
	},
	Paragon = {
		requiresPrimary = 6,   -- Any path at tier 6
		requiresSecondary = 3, -- Any other path at tier 3
		cost = 75000,
		name = "ULTIMATE TRANSFORMATION",
		damage = 200,
		range = 30,
		spa = -1.0,
	}
}
]]

--[[
VISUAL MODEL UPGRADES:
You can change the tower's appearance at specific upgrade tiers by adding a "model" field.
The model name must match a tower model in ReplicatedStorage.Towers

Example with visual upgrades:
UpgradeData["Warrior"] = {
	A = {
		[1] = { damage = 5, cost = 100, name = "Iron Sword" },
		[2] = { damage = 10, cost = 200, name = "Steel Blade" },
		[3] = { damage = 15, cost = 400, name = "Knight's Edge", model = "WarriorKnight" }, -- Changes to WarriorKnight model
		[4] = { damage = 25, cost = 800, name = "Royal Guard" },
		[5] = { damage = 40, cost = 1500, name = "Paladin's Wrath", model = "WarriorPaladin" }, -- Changes to WarriorPaladin model
		[6] = { damage = 75, cost = 3000, name = "Divine Champion" },
	},
	Paragon = {
		requiresPrimary = 6,
		requiresSecondary = 3,
		cost = 100000,
		name = "GOD OF WAR",
		damage = 500,
		range = 50,
		spa = -1.5,
		model = "WarriorGod", -- PARAGON gets unique model
	}
}

IMPORTANT NOTES:
- Model swaps preserve all tower state (upgrades, stats, position, target mode, etc.)
- The new model must exist in ReplicatedStorage.Towers
- You can swap at any tier (1-6) or at Paragon
- Models should have the same structure (HumanoidRootPart, Config folder, etc.)
- The tower will seamlessly transition to the new model while maintaining functionality
]]

-- Helper function to check if a tower has a specific path
function UpgradeData.HasPath(towerType, path)
	if not UpgradeData[towerType] then
		return false
	end
	return UpgradeData[towerType][path] ~= nil
end

-- Helper function to get available paths for a tower
function UpgradeData.GetAvailablePaths(towerType)
	if not UpgradeData[towerType] then
		return {}
	end
	
	local paths = {}
	for _, path in ipairs({"A", "B", "C"}) do
		if UpgradeData[towerType][path] then
			table.insert(paths, path)
		end
	end
	return paths
end

-- Helper function to check if tower has a paragon
function UpgradeData.HasParagon(towerType)
	if not UpgradeData[towerType] then
		return false
	end
	return UpgradeData[towerType].Paragon ~= nil
end

-- Helper function to get paragon data
function UpgradeData.GetParagon(towerType)
	if not UpgradeData[towerType] then
		return nil
	end
	return UpgradeData[towerType].Paragon
end

-- Helper function to check if tower can upgrade to paragon
function UpgradeData.CanUpgradeToParagon(towerType, currentUpgrades)
	local paragon = UpgradeData.GetParagon(towerType)
	if not paragon then
		return false
	end
	
	-- Check flexible requirements: any path at requiresPrimary, any other path at requiresSecondary
	local hasPrimary = false
	local hasSecondary = false
	local primaryPath = nil
	
	-- Find a path at primary level (tier 6)
	for _, path in ipairs({"A", "B", "C"}) do
		if currentUpgrades[path] and currentUpgrades[path].Value >= paragon.requiresPrimary then
			hasPrimary = true
			primaryPath = path
			break
		end
	end
	
	-- Find a different path at secondary level (tier 3)
	if hasPrimary then
		for _, path in ipairs({"A", "B", "C"}) do
			if path ~= primaryPath and currentUpgrades[path] and currentUpgrades[path].Value >= paragon.requiresSecondary then
				hasSecondary = true
				break
			end
		end
	end
	
	return hasPrimary and hasSecondary
end

-- Helper function to get path color
function UpgradeData.GetPathColor(towerType, path)
	-- Default colors if not specified
	local defaultColors = {
		A = Color3.fromRGB(255, 100, 100), -- Red
		B = Color3.fromRGB(100, 150, 255), -- Blue
		C = Color3.fromRGB(255, 220, 100), -- Yellow
	}
	
	if not UpgradeData[towerType] then
		return defaultColors[path] or Color3.fromRGB(200, 200, 200)
	end
	
	-- Use tower-specific colors if defined
	if UpgradeData[towerType].PathColors and UpgradeData[towerType].PathColors[path] then
		return UpgradeData[towerType].PathColors[path]
	end
	
	-- Fall back to default colors
	return defaultColors[path] or Color3.fromRGB(200, 200, 200)
end

-- Helper function to get upgrade data
function UpgradeData.Get(towerType, path, level)
	if not UpgradeData[towerType] then
		warn("No upgrade data for tower:", towerType)
		return nil
	end

	if not UpgradeData[towerType][path] then
		return nil -- Path doesn't exist for this tower
	end

	return UpgradeData[towerType][path][level]
end

-- Client-safe version that only returns cost
function UpgradeData.GetClient(towerType, path, level)
	local data = UpgradeData.Get(towerType, path, level)
	if data then
		return data.cost
	end
	return nil
end

return UpgradeData
