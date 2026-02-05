local mob = require(script.Parent.Mob)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameSpeed = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GameSpeed"))
local round = {}

print("[Round] Loaded - Act-based state system (waves 1-15 per act)")

-- Helper function to spawn multiple mob types
local function spawnWave(mobTypes, map, wave)
	for _, mobData in ipairs(mobTypes) do
		mob.Spawn(mobData.name, mobData.count, map, wave)
		if mobData.delay then
			task.wait(GameSpeed.GetWaitTime(mobData.delay))
		end
	end
end

-- Act 1 wave configurations (waves 1-15)
local function getAct1Wave(wave, map)
	if wave == 1 then
		spawnWave({{name = "PudgePete", count = 2}}, map, wave)
	elseif wave == 2 then
		spawnWave({{name = "PudgePete", count = 4}}, map, wave)
	elseif wave == 3 then
		spawnWave({{name = "PudgePete", count = 6}}, map, wave)
	elseif wave == 4 then
		spawnWave({{name = "PudgePete", count = 8}}, map, wave)
	elseif wave == 5 then
		spawnWave({
			{name = "PudgePete", count = 10},
			{name = "CurioussGorge", count = 5, delay = 1}
		}, map, wave)
	elseif wave == 6 then
		spawnWave({
			{name = "CurioussGorge", count = 6},
			{name = "PudgePete", count = 6, delay = 1}
		}, map, wave)
	elseif wave == 7 then
		spawnWave({
			{name = "PudgePete", count = 7},
			{name = "CurioussGorge", count = 14, delay = 1}
		}, map, wave)
	elseif wave == 8 then
		spawnWave({
			{name = "PudgePete", count = 16},
			{name = "CurioussGorge", count = 16, delay = 1}
		}, map, wave)
	elseif wave == 9 then
		spawnWave({
			{name = "PudgePete", count = 18},
			{name = "CurioussGorge", count = 18, delay = 1},
			{name = "illxstrate", count = 2, delay = 2}
		}, map, wave)
	elseif wave == 10 then
		spawnWave({
			{name = "PudgePete", count = 20},
			{name = "CurioussGorge", count = 20, delay = 1},
			{name = "illxstrate", count = 3, delay = 2}
		}, map, wave)
	elseif wave == 11 then
		spawnWave({
			{name = "PudgePete", count = 33},
			{name = "CurioussGorge", count = 22, delay = 1},
			{name = "illxstrate", count = 4, delay = 2}
		}, map, wave)
	elseif wave == 12 then
		spawnWave({
			{name = "PudgePete", count = 36},
			{name = "CurioussGorge", count = 36, delay = 1},
			{name = "illxstrate", count = 5, delay = 2}
		}, map, wave)
	elseif wave == 13 then
		spawnWave({
			{name = "PudgePete", count = 52},
			{name = "CurioussGorge", count = 39, delay = 1},
			{name = "illxstrate", count = 6, delay = 2}
		}, map, wave)
	elseif wave == 14 then
		spawnWave({
			{name = "PudgePete", count = 56},
			{name = "CurioussGorge", count = 56, delay = 1},
			{name = "illxstrate", count = 7, delay = 2}
		}, map, wave)
	elseif wave == 15 then
		-- Final wave - Boss
		spawnWave({
			{name = "PudgePete", count = 75},
			{name = "CurioussGorge", count = 75, delay = 1},
			{name = "illxstrate", count = 8, delay = 2}
		}, map, wave)
		task.wait(GameSpeed.GetWaitTime(2))
		mob.SpawnBoss(1, map) -- Act 1 boss
	end
end

-- Act 2 wave configurations (waves 1-15)
local function getAct2Wave(wave, map)
	local baseMultiplier = 1.5 -- Act 2 is harder
	if wave == 1 then
		spawnWave({{name = "PudgePete", count = 6}}, map, wave)
	elseif wave == 2 then
		spawnWave({{name = "PudgePete", count = 9}}, map, wave)
	elseif wave == 3 then
		spawnWave({{name = "PudgePete", count = 12}}, map, wave)
	elseif wave == 4 then
		spawnWave({
			{name = "PudgePete", count = 12},
			{name = "CurioussGorge", count = 6, delay = 1}
		}, map, wave)
	elseif wave == 5 then
		spawnWave({
			{name = "PudgePete", count = 15},
			{name = "CurioussGorge", count = 10, delay = 1}
		}, map, wave)
	elseif wave == 6 then
		spawnWave({
			{name = "PudgePete", count = 18},
			{name = "CurioussGorge", count = 12, delay = 1},
			{name = "illxstrate", count = 3, delay = 2}
		}, map, wave)
	elseif wave == 7 then
		spawnWave({
			{name = "PudgePete", count = 21},
			{name = "CurioussGorge", count = 14, delay = 1},
			{name = "illxstrate", count = 4, delay = 2}
		}, map, wave)
	elseif wave == 8 then
		spawnWave({
			{name = "PudgePete", count = 24},
			{name = "CurioussGorge", count = 16, delay = 1},
			{name = "illxstrate", count = 5, delay = 2}
		}, map, wave)
	elseif wave == 9 then
		spawnWave({
			{name = "PudgePete", count = 27},
			{name = "CurioussGorge", count = 18, delay = 1},
			{name = "illxstrate", count = 6, delay = 2}
		}, map, wave)
	elseif wave == 10 then
		spawnWave({
			{name = "PudgePete", count = 30},
			{name = "CurioussGorge", count = 20, delay = 1},
			{name = "illxstrate", count = 7, delay = 2}
		}, map, wave)
	elseif wave == 11 then
		spawnWave({
			{name = "PudgePete", count = 33},
			{name = "CurioussGorge", count = 22, delay = 1},
			{name = "illxstrate", count = 8, delay = 2}
		}, map, wave)
	elseif wave == 12 then
		spawnWave({
			{name = "PudgePete", count = 36},
			{name = "CurioussGorge", count = 24, delay = 1},
			{name = "illxstrate", count = 9, delay = 2}
		}, map, wave)
	elseif wave == 13 then
		spawnWave({
			{name = "PudgePete", count = 39},
			{name = "CurioussGorge", count = 26, delay = 1},
			{name = "illxstrate", count = 10, delay = 2}
		}, map, wave)
	elseif wave == 14 then
		spawnWave({
			{name = "PudgePete", count = 42},
			{name = "CurioussGorge", count = 28, delay = 1},
			{name = "illxstrate", count = 11, delay = 2}
		}, map, wave)
	elseif wave == 15 then
		-- Final wave - Boss
		spawnWave({
			{name = "PudgePete", count = 50},
			{name = "CurioussGorge", count = 35, delay = 1},
			{name = "illxstrate", count = 15, delay = 2}
		}, map, wave)
		task.wait(GameSpeed.GetWaitTime(2))
		mob.SpawnBoss(2, map) -- Act 2 boss
	end
end

-- Act 3 wave configurations (waves 1-15)
local function getAct3Wave(wave, map)
	local baseCount = 8 + (wave * 3)
	if wave == 15 then
		-- Final wave - Boss
		spawnWave({
			{name = "PudgePete", count = 60},
			{name = "CurioussGorge", count = 45, delay = 1},
			{name = "illxstrate", count = 20, delay = 2}
		}, map, wave)
		task.wait(GameSpeed.GetWaitTime(2))
		mob.SpawnBoss(3, map) -- Act 3 boss
	else
		spawnWave({
			{name = "PudgePete", count = baseCount},
			{name = "CurioussGorge", count = math.floor(baseCount * 0.75), delay = 1},
			{name = "illxstrate", count = math.floor(wave * 0.8), delay = 2}
		}, map, wave)
	end
end

-- Act 4 wave configurations (waves 1-15)
local function getAct4Wave(wave, map)
	local baseCount = 12 + (wave * 4)
	if wave == 15 then
		-- Final wave - Boss
		spawnWave({
			{name = "PudgePete", count = 80},
			{name = "CurioussGorge", count = 60, delay = 1},
			{name = "illxstrate", count = 25, delay = 2}
		}, map, wave)
		task.wait(GameSpeed.GetWaitTime(2))
		mob.SpawnBoss(4, map) -- Act 4 boss
	else
		spawnWave({
			{name = "PudgePete", count = baseCount},
			{name = "CurioussGorge", count = math.floor(baseCount * 0.8), delay = 1},
			{name = "illxstrate", count = wave, delay = 2}
		}, map, wave)
	end
end

-- Act 5 wave configurations (waves 1-15)
local function getAct5Wave(wave, map)
	local baseCount = 16 + (wave * 5)
	if wave == 15 then
		-- Final wave - Boss
		spawnWave({
			{name = "PudgePete", count = 100},
			{name = "CurioussGorge", count = 80, delay = 1},
			{name = "illxstrate", count = 30, delay = 2}
		}, map, wave)
		task.wait(GameSpeed.GetWaitTime(2))
		mob.SpawnBoss(5, map) -- Act 5 boss (final boss)
	else
		spawnWave({
			{name = "PudgePete", count = baseCount},
			{name = "CurioussGorge", count = math.floor(baseCount * 0.85), delay = 1},
			{name = "illxstrate", count = wave + 2, delay = 2}
		}, map, wave)
	end
end

-- Main function: takes act and wave (both 1-indexed)
function round.GetWave(act, wave, map)
	print("[Round] Act", act, "Wave", wave)
	
	if act == 1 then
		getAct1Wave(wave, map)
	elseif act == 2 then
		getAct2Wave(wave, map)
	elseif act == 3 then
		getAct3Wave(wave, map)
	elseif act == 4 then
		getAct4Wave(wave, map)
	elseif act == 5 then
		getAct5Wave(wave, map)
	else
		warn("[Round] Unknown act:", act)
		spawnWave({{name = "PudgePete", count = 5}}, map, wave)
	end
end

return round
