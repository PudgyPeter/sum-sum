--[[
	EvolutionSystem.lua
	XP and evolution stages system for units
	
	Usage:
		local EvolutionSystem = require(path.to.EvolutionSystem)
		local stage = EvolutionSystem.GetStage("Luffy", 5000)
		local mult = EvolutionSystem.GetStatMultiplier("Luffy", stage)
]]

local EvolutionSystem = {}

-- XP gain values for different events
EvolutionSystem.XPGain = {
	MobKill = 1,
	EliteKill = 5,
	BossKill = 25,
	WaveComplete = 50,
	ActComplete = 500,
}

-- Unit-specific evolution data
-- Each stage can have: XP threshold, StatMult, Model, Abilities, RequiresTrial
EvolutionSystem.Data = {
	["Luffy"] = {
		[0] = {Name = "East Blue", XP = 0, StatMult = 1.0, Model = "Luffy_Base"},
		[1] = {Name = "Gear 2", XP = 1000, StatMult = 1.25, Model = "Luffy_Gear2", Abilities = {"JetPistol"}},
		[2] = {Name = "Haki", XP = 5000, StatMult = 1.5, Model = "Luffy_Haki", Abilities = {"ElephantGun"}},
		[3] = {Name = "Gear 4", XP = 15000, StatMult = 2.0, Model = "Luffy_Gear4", Abilities = {"KingKongGun"}},
		[4] = {Name = "Gear 5", RequiresTrial = "NikaTrial", StatMult = 3.0, Model = "Luffy_Gear5"},
	},
	["Zoro"] = {
		[0] = {Name = "East Blue", XP = 0, StatMult = 1.0, Model = "Zoro_Base"},
		[1] = {Name = "Two Sword", XP = 1000, StatMult = 1.25, Model = "Zoro_TwoSword"},
		[2] = {Name = "Three Sword", XP = 5000, StatMult = 1.5, Model = "Zoro_ThreeSword", Abilities = {"OniGiri"}},
		[3] = {Name = "Haki", XP = 15000, StatMult = 2.0, Model = "Zoro_Haki", Abilities = {"Ashura"}},
		[4] = {Name = "King of Hell", RequiresTrial = "AsuraTrial", StatMult = 3.0, Model = "Zoro_KingOfHell"},
	},
	["Naruto"] = {
		[0] = {Name = "Genin", XP = 0, StatMult = 1.0, Model = "Naruto_Base"},
		[1] = {Name = "Rasengan", XP = 1000, StatMult = 1.25, Model = "Naruto_Rasengan", Abilities = {"Rasengan"}},
		[2] = {Name = "Sage Mode", XP = 5000, StatMult = 1.5, Model = "Naruto_Sage", Abilities = {"RasenshUriken"}},
		[3] = {Name = "KCM", XP = 15000, StatMult = 2.0, Model = "Naruto_KCM", Abilities = {"TailedBeastBomb"}},
		[4] = {Name = "Six Paths", RequiresTrial = "SageOfSixPaths", StatMult = 3.0, Model = "Naruto_SixPaths"},
	},
}

-- Default evolution data for units without specific definitions
EvolutionSystem.Default = {
	[0] = {Name = "Base", XP = 0, StatMult = 1.0},
	[1] = {Name = "Stage 1", XP = 1000, StatMult = 1.2},
	[2] = {Name = "Stage 2", XP = 5000, StatMult = 1.5},
	[3] = {Name = "Stage 3", XP = 15000, StatMult = 2.0},
}

-- Maximum evolution stage (excluding trial-locked stages)
EvolutionSystem.MaxStage = 3
EvolutionSystem.MaxStageWithTrial = 4

-- Get the evolution stage based on XP
function EvolutionSystem.GetStage(unitId: string, xp: number): number
	local data = EvolutionSystem.Data[unitId] or EvolutionSystem.Default
	local stage = 0
	
	for s, d in pairs(data) do
		if type(s) == "number" and not d.RequiresTrial then
			if xp >= (d.XP or 0) and s > stage then
				stage = s
			end
		end
	end
	
	return stage
end

-- Get data for a specific evolution stage
function EvolutionSystem.GetStageData(unitId: string, stage: number): {Name: string?, XP: number?, StatMult: number?, Model: string?, Abilities: {string}?, RequiresTrial: string?}?
	local data = EvolutionSystem.Data[unitId] or EvolutionSystem.Default
	return data[stage]
end

-- Get the stat multiplier for a stage
function EvolutionSystem.GetStatMultiplier(unitId: string, stage: number): number
	local data = EvolutionSystem.GetStageData(unitId, stage)
	return data and data.StatMult or 1.0
end

-- Get the model name for a stage
function EvolutionSystem.GetModel(unitId: string, stage: number): string?
	local data = EvolutionSystem.GetStageData(unitId, stage)
	return data and data.Model or nil
end

-- Get abilities unlocked at a stage
function EvolutionSystem.GetAbilities(unitId: string, stage: number): {string}
	local data = EvolutionSystem.GetStageData(unitId, stage)
	return data and data.Abilities or {}
end

-- Get all abilities unlocked up to and including a stage
function EvolutionSystem.GetAllAbilitiesUpToStage(unitId: string, stage: number): {string}
	local abilities = {}
	local data = EvolutionSystem.Data[unitId] or EvolutionSystem.Default
	
	for s = 0, stage do
		local stageData = data[s]
		if stageData and stageData.Abilities then
			for _, ability in ipairs(stageData.Abilities) do
				table.insert(abilities, ability)
			end
		end
	end
	
	return abilities
end

-- Get the XP required for the next stage
function EvolutionSystem.GetXPForNextStage(unitId: string, currentStage: number): number?
	local nextStage = currentStage + 1
	local data = EvolutionSystem.GetStageData(unitId, nextStage)
	
	if data and not data.RequiresTrial then
		return data.XP
	end
	
	return nil -- No next stage or requires trial
end

-- Check if a stage requires a trial
function EvolutionSystem.RequiresTrial(unitId: string, stage: number): string?
	local data = EvolutionSystem.GetStageData(unitId, stage)
	return data and data.RequiresTrial or nil
end

-- Check if unit can evolve to next stage
function EvolutionSystem.CanEvolve(unitId: string, currentXP: number, currentStage: number, completedTrials: {string}?): (boolean, string?)
	local nextStage = currentStage + 1
	local data = EvolutionSystem.GetStageData(unitId, nextStage)
	
	if not data then
		return false, "Max stage reached"
	end
	
	if data.RequiresTrial then
		if not completedTrials or not table.find(completedTrials, data.RequiresTrial) then
			return false, "Trial required: " .. data.RequiresTrial
		end
	end
	
	if data.XP and currentXP < data.XP then
		return false, string.format("Need %d XP (have %d)", data.XP, currentXP)
	end
	
	return true
end

-- Get evolution progress as percentage
function EvolutionSystem.GetProgress(unitId: string, xp: number, currentStage: number): number
	local currentData = EvolutionSystem.GetStageData(unitId, currentStage)
	local nextData = EvolutionSystem.GetStageData(unitId, currentStage + 1)
	
	if not nextData or nextData.RequiresTrial then
		return 1.0 -- Maxed or trial-locked
	end
	
	local currentXP = currentData and currentData.XP or 0
	local nextXP = nextData.XP or 0
	local range = nextXP - currentXP
	
	if range <= 0 then
		return 1.0
	end
	
	return math.clamp((xp - currentXP) / range, 0, 1)
end

-- Check if unit has specific evolution data defined
function EvolutionSystem.HasCustomEvolution(unitId: string): boolean
	return EvolutionSystem.Data[unitId] ~= nil
end

-- Register custom evolution data for a unit (for extensibility)
function EvolutionSystem.RegisterUnitEvolution(unitId: string, evolutionData: {[number]: any})
	EvolutionSystem.Data[unitId] = evolutionData
end

return EvolutionSystem
