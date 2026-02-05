local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")
local UpgradeData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("TowerUpgradeData"))
local StatusEffects = require(script.Parent.StatusEffects)
local GameSpeed = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GameSpeed"))
local ColorTypeSystem = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ColorTypeSystem"))
local TowerData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("TowerData"))
local XPManager = require(script.Parent.XPManager)

local events = ReplicatedStorage:WaitForChild("Events")
local functions = ReplicatedStorage:WaitForChild("Functions")
local requestTowerFunction = functions:WaitForChild("RequestTower")
local changeTowerPriorityFunction = functions:WaitForChild("ChangeTowerPriority")
local spawnTowerFunction = functions:WaitForChild("SpawnTower")
local AnimateTowerEvent = events:WaitForChild("AnimateTower")
local sellTowerFunction = functions:WaitForChild("SellTower")

-- Get pre-created events
local DamageIndicatorEvent = events:WaitForChild("DamageIndicator")
local PlayerKillEvent = events:WaitForChild("PlayerKill")
local PlayerDamageEvent = events:WaitForChild("PlayerDamage")

local map = workspace.RockMap

local maxTowers = 10
local Tower = {}
local AOE = nil

-- Load GameManager to initialize game state and rewards
local GameManager = require(script.Parent.GameManager)

print("Upgrade data loaded successfully!")
print(UpgradeData)

-- Check if tower has line of sight to target (no obstacles blocking)
local function HasLineOfSight(tower, target)
	if not tower or not target then return false end
	
	local towerRoot = tower:FindFirstChild("HumanoidRootPart")
	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	
	if not towerRoot or not targetRoot then return false end
	
	-- Create raycast from tower to target
	local origin = towerRoot.Position
	local direction = (targetRoot.Position - origin)
	local distance = direction.Magnitude
	
	-- Raycast parameters
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {tower, target, workspace.Mobs, workspace.Towers}
	raycastParams.IgnoreWater = true
	
	-- Perform raycast
	local raycastResult = workspace:Raycast(origin, direction, raycastParams)
	
	-- If raycast hit something, there's an obstacle
	if raycastResult then
		-- Check if hit object is part of the map/obstacle
		local hitPart = raycastResult.Instance
		if hitPart and hitPart.Parent then
			-- If we hit something that's not the target or tower, line of sight is blocked
			return false
		end
	end
	
	-- No obstacles detected
	return true
end

function Tower.FindTarget (newTower,range, mode)
	local bestTarget = nil

	local bestWaypoint = nil
	local bestDistance = nil
	local bestHealth = nil

	for i, mob in ipairs(workspace.Mobs:GetChildren()) do
		-- Skip dead mobs to prevent targeting errors and allow VFX to complete
		if mob:FindFirstChild("IsDead") then
			continue
		end
		
		local distanceToMob = (mob.HumanoidRootPart.Position - newTower.HumanoidRootPart.Position).Magnitude
		local distanceToWaypoint = (mob.HumanoidRootPart.Position - map.Waypoints[mob.MovingTo.Value].Position).Magnitude

		-- Check if mob is in range AND tower has line of sight
		if distanceToMob <= range and HasLineOfSight(newTower, mob) then
			if mode == "Near" then
				range = distanceToMob
				bestTarget = mob
			elseif mode == "First" then
				if not bestWaypoint or mob.MovingTo.Value > bestWaypoint then
					-- Found a mob at a higher waypoint (closer to base)
					bestWaypoint = mob.MovingTo.Value
					bestDistance = distanceToWaypoint
					bestTarget = mob
				elseif mob.MovingTo.Value == bestWaypoint then
					-- Same waypoint, pick the one closest to that waypoint
					if distanceToWaypoint < bestDistance then
						bestDistance = distanceToWaypoint
						bestTarget = mob
					end
				end
			elseif mode == "Last" then
				if not bestWaypoint or mob.MovingTo.Value <= bestWaypoint then
					if bestWaypoint then
						bestDistance = nil
					end
					bestWaypoint = mob.MovingTo.Value

					if not bestDistance or distanceToWaypoint > bestDistance then
						bestDistance = distanceToWaypoint
						bestTarget = mob
					end
				end
			elseif mode == "Strong" then
				if not bestHealth or mob.Humanoid.Health > bestHealth then
					bestHealth = mob.Humanoid.Health
					bestTarget = mob
				end
			elseif mode == "Weak" then
				if not bestHealth or mob.Humanoid.Health < bestHealth then
					bestHealth = mob.Humanoid.Health
					bestTarget = mob
				end
			end
		end
	end
	return bestTarget
end


function Tower.Attack(newTower, player)
	local config = newTower.Config
	local target = Tower.FindTarget(newTower, config.Range.Value, config.TargetMode.Value)

	if target and target:FindFirstChild("Humanoid") and target.Humanoid.Health > 0 then

		local targetCFrame = CFrame.lookAt(newTower.HumanoidRootPart.Position, target.HumanoidRootPart.Position)
		newTower.HumanoidRootPart.BodyGyro.CFrame = targetCFrame

		AnimateTowerEvent:FireAllClients(newTower, "Attack", target)

		local damageAmount = config.Damage.Value
		local isCrit = false
		
		-- Check for critical hit
		local critChance = config:FindFirstChild("CritChance")
		local critDamage = config:FindFirstChild("CritDamage")
		
		if critChance and critDamage then
			local roll = math.random(1, 100)
			if roll <= critChance.Value then
				-- Critical hit!
				isCrit = true
				damageAmount = damageAmount * critDamage.Value
			end
		end
		
		-- Apply color type damage multiplier
		-- Check config first, then fallback to TowerData lookup by tower name
		local towerType = config:FindFirstChild("ColorType") and config.ColorType.Value
		if not towerType then
			towerType = TowerData.GetColorType(newTower.Name) or TowerData.GetColorType(newTower.Name .. "_Base")
		end
		local mobType = target:FindFirstChild("ColorType") and target.ColorType.Value
		local typeMult = ColorTypeSystem.GetDamageMultiplier(towerType, mobType)
		if typeMult ~= 1.0 then
			damageAmount = math.floor(damageAmount * typeMult)
		end
		
		-- Debug: Log damage for bosses
		if target:FindFirstChild("BossType") then
			print(string.format("TOWER ATTACK DEBUG: Tower=%s, Damage=%d%s, Boss=%s, BossHP=%d/%d", 
				newTower.Name, damageAmount, isCrit and " (CRIT!)" or "", target:FindFirstChild("BossType").Value, 
				target.Humanoid.Health, target.Humanoid.MaxHealth))
		end
		
		local isKillingBlow = target.Humanoid.Health <= damageAmount
		target.Humanoid:TakeDamage(damageAmount)
		
		-- Apply status effects if tower has them
		local statusType = config:FindFirstChild("StatusType")
		if statusType and statusType.Value ~= "None" and target.Humanoid.Health > 0 then
			local statusConfig = config:FindFirstChild("StatusEffectConfig")
			Tower.ApplyStatusEffect(target, statusType.Value, statusConfig, newTower)
		end
		
		-- Track tower stats
		local stats = config:FindFirstChild("Stats")
		if not stats then
			stats = Instance.new("Folder")
			stats.Name = "Stats"
			stats.Parent = config
			
			local totalDamage = Instance.new("NumberValue")
			totalDamage.Name = "TotalDamage"
			totalDamage.Value = 0
			totalDamage.Parent = stats
			
			local kills = Instance.new("IntValue")
			kills.Name = "Kills"
			kills.Value = 0
			kills.Parent = stats
		end
		
		-- Update total damage
		local totalDamageValue = stats:FindFirstChild("TotalDamage")
		if totalDamageValue then
			totalDamageValue.Value = totalDamageValue.Value + damageAmount
		end
		
		-- Fire damage event to tower owner for stats tracking
		PlayerDamageEvent:FireClient(player, damageAmount)
		
		-- Fire damage indicator to all clients (with killing blow flag)
		DamageIndicatorEvent:FireAllClients(target, damageAmount, isKillingBlow)

		if target.Humanoid.Health <= 0 then
			local baseReward = target.Humanoid.MaxHealth / 5
			local sharedReward = baseReward * 0.5
			local killerBonus = baseReward * 0.5
			
			-- Give 50% to all players
			for _, plr in ipairs(game.Players:GetPlayers()) do
				plr.Cash.Value += sharedReward
			end
			
			-- Give additional 50% to tower owner (total 100% for killer)
			player.Cash.Value += killerBonus
			
			-- Update kill count
			local killsValue = stats:FindFirstChild("Kills")
			if killsValue then
				killsValue.Value = killsValue.Value + 1
			end
			
			-- Award XP based on mob type
			local xpEvent = "MobKill"
			if target:FindFirstChild("BossType") then
				xpEvent = "BossKill"
			elseif target:FindFirstChild("IsElite") and target.IsElite.Value then
				xpEvent = "EliteKill"
			end
			XPManager.AwardForEvent(player, newTower, xpEvent)
			
			-- Notify tower owner of kill for per-player stats
			PlayerKillEvent:FireClient(player)
		end

		task.wait(GameSpeed.GetWaitTime(config.SPA.Value))
	end

	task.wait(GameSpeed.GetWaitTime(0.1))

	if newTower and newTower.Parent then
		Tower.Attack(newTower, player)
	end
end

-- Apply status effect to a target
function Tower.ApplyStatusEffect(target, effectName, statusConfig, tower)
	if not target or not target:FindFirstChild("Humanoid") then return end
	
	local effectData = StatusEffects.GetEffect(effectName)
	if not effectData then
		warn("Unknown status effect:", effectName)
		return
	end
	
	-- Get or create StatusEffects folder on target
	local statusFolder = target:FindFirstChild("StatusEffects")
	if not statusFolder then
		statusFolder = Instance.new("Folder")
		statusFolder.Name = "StatusEffects"
		statusFolder.Parent = target
	end
	
	-- Get custom values from tower config or use defaults
	local tickDamage = effectData.TickDamage
	local duration = effectData.Duration
	local maxStacks = effectData.MaxStacks
	
	if statusConfig then
		tickDamage = statusConfig:FindFirstChild("TickDamage") and statusConfig.TickDamage.Value or tickDamage
		duration = statusConfig:FindFirstChild("Duration") and statusConfig.Duration.Value or duration
		maxStacks = statusConfig:FindFirstChild("MaxStacks") and statusConfig.MaxStacks.Value or maxStacks
	end
	
	-- Handle Burn (resets timer on reapplication)
	if effectName == "Burn" then
		local existingBurn = statusFolder:FindFirstChild("Burn")
		if existingBurn then
			-- Reset timer
			existingBurn.Duration.Value = duration
			existingBurn.TickDamage.Value = tickDamage
			print(string.format("[STATUS] Burn refreshed on %s - %d damage over %ds", target.Name, tickDamage, duration))
		else
			-- Create new burn effect
			local burnEffect = Instance.new("Folder")
			burnEffect.Name = "Burn"
			burnEffect.Parent = statusFolder
			
			local tickDmg = Instance.new("NumberValue")
			tickDmg.Name = "TickDamage"
			tickDmg.Value = tickDamage
			tickDmg.Parent = burnEffect
			
			local dur = Instance.new("NumberValue")
			dur.Name = "Duration"
			dur.Value = duration
			dur.Parent = burnEffect
			
			local tickRate = Instance.new("NumberValue")
			tickRate.Name = "TickRate"
			tickRate.Value = effectData.TickRate
			tickRate.Parent = burnEffect
			
			local lastTick = Instance.new("NumberValue")
			lastTick.Name = "LastTick"
			lastTick.Value = tick()
			lastTick.Parent = burnEffect
			
			print(string.format("[STATUS] Burn applied to %s - %d damage over %ds", target.Name, tickDamage, duration))
			
			-- Start DoT coroutine
			Tower.StartDoTEffect(target, burnEffect, "Burn")
		end
	
	-- Handle Bleed (stackable)
	elseif effectName == "Bleed" then
		local bleedStacks = statusFolder:GetChildren()
		local currentStacks = 0
		
		-- Count existing bleed stacks
		for _, child in ipairs(bleedStacks) do
			if child.Name:match("^Bleed") then
				currentStacks = currentStacks + 1
			end
		end
		
		-- Check if we can add more stacks
		if currentStacks < (maxStacks or 10) then
			local stackNumber = currentStacks + 1
			local bleedEffect = Instance.new("Folder")
			bleedEffect.Name = "Bleed" .. stackNumber
			bleedEffect.Parent = statusFolder
			
			local tickDmg = Instance.new("NumberValue")
			tickDmg.Name = "TickDamage"
			tickDmg.Value = tickDamage
			tickDmg.Parent = bleedEffect
			
			local dur = Instance.new("NumberValue")
			dur.Name = "Duration"
			dur.Value = duration
			dur.Parent = bleedEffect
			
			local tickRate = Instance.new("NumberValue")
			tickRate.Name = "TickRate"
			tickRate.Value = effectData.TickRate
			tickRate.Parent = bleedEffect
			
			local lastTick = Instance.new("NumberValue")
			lastTick.Name = "LastTick"
			lastTick.Value = tick()
			lastTick.Parent = bleedEffect
			
			print(string.format("[STATUS] Bleed stack %d applied to %s - %d damage over %ds", stackNumber, target.Name, tickDamage, duration))
			
			-- Start DoT coroutine for this stack
			Tower.StartDoTEffect(target, bleedEffect, "Bleed")
		else
			print(string.format("[STATUS] Bleed max stacks (%d) reached on %s", maxStacks or 10, target.Name))
		end
	
	-- Handle Hellfire (weaker burn with damage boost to other burns)
	elseif effectName == "Hellfire" then
		local existingHellfire = statusFolder:FindFirstChild("Hellfire")
		if existingHellfire then
			-- Reset timer
			existingHellfire.Duration.Value = duration
			existingHellfire.TickDamage.Value = tickDamage
			print(string.format("[STATUS] Hellfire refreshed on %s - %d damage over %ds", target.Name, tickDamage, duration))
		else
			-- Create new hellfire effect
			local hellfireEffect = Instance.new("Folder")
			hellfireEffect.Name = "Hellfire"
			hellfireEffect.Parent = statusFolder
			
			local tickDmg = Instance.new("NumberValue")
			tickDmg.Name = "TickDamage"
			tickDmg.Value = tickDamage
			tickDmg.Parent = hellfireEffect
			
			local dur = Instance.new("NumberValue")
			dur.Name = "Duration"
			dur.Value = duration
			dur.Parent = hellfireEffect
			
			local tickRate = Instance.new("NumberValue")
			tickRate.Name = "TickRate"
			tickRate.Value = effectData.TickRate
			tickRate.Parent = hellfireEffect
			
			local lastTick = Instance.new("NumberValue")
			lastTick.Name = "LastTick"
			lastTick.Value = tick()
			lastTick.Parent = hellfireEffect
			
			-- Add burn boost multiplier
			local boostMultiplier = Instance.new("NumberValue")
			boostMultiplier.Name = "BurnBoostMultiplier"
			boostMultiplier.Value = effectData.BurnBoostMultiplier
			boostMultiplier.Parent = hellfireEffect
			
			print(string.format("[STATUS] Hellfire applied to %s - %d damage over %ds (Burn boost: %.1fx)", 
				target.Name, tickDamage, duration, effectData.BurnBoostMultiplier))
			
			-- Start DoT coroutine with burn boost
			Tower.StartDoTEffect(target, hellfireEffect, "Hellfire")
		end
	
	-- Handle BlackFlame (permanent burn that absorbs other burns)
	elseif effectName == "BlackFlame" then
		local existingBlackFlame = statusFolder:FindFirstChild("BlackFlame")
		if existingBlackFlame then
			-- BlackFlame already exists, check for other burns to absorb
			local absorbed = false
			for _, effect in ipairs(statusFolder:GetChildren()) do
				if effect.Name == "Burn" or effect.Name == "Hellfire" then
					local absorbDamage = effect.TickDamage.Value * effectData.AbsorbMultiplier
					existingBlackFlame.TickDamage.Value = existingBlackFlame.TickDamage.Value + absorbDamage
					print(string.format("[STATUS] BlackFlame absorbed %s on %s - added %.1f damage", 
						effect.Name, target.Name, absorbDamage))
					effect:Destroy()
					absorbed = true
				end
			end
			if not absorbed then
				print(string.format("[STATUS] BlackFlame already active on %s - no burns to absorb", target.Name))
			end
		else
			-- Create new black flame effect
			local blackFlameEffect = Instance.new("Folder")
			blackFlameEffect.Name = "BlackFlame"
			blackFlameEffect.Parent = statusFolder
			
			local tickDmg = Instance.new("NumberValue")
			tickDmg.Name = "TickDamage"
			tickDmg.Value = tickDamage
			tickDmg.Parent = blackFlameEffect
			
			local dur = Instance.new("NumberValue")
			dur.Name = "Duration"
			dur.Value = math.huge -- Permanent
			dur.Parent = blackFlameEffect
			
			local tickRate = Instance.new("NumberValue")
			tickRate.Name = "TickRate"
			tickRate.Value = effectData.TickRate
			tickRate.Parent = blackFlameEffect
			
			local lastTick = Instance.new("NumberValue")
			lastTick.Name = "LastTick"
			lastTick.Value = tick()
			lastTick.Parent = blackFlameEffect
			
			print(string.format("[STATUS] BlackFlame applied to %s - %d damage/tick (PERMANENT)", target.Name, tickDamage))
			
			-- Absorb any existing burns
			for _, effect in ipairs(statusFolder:GetChildren()) do
				if effect.Name == "Burn" or effect.Name == "Hellfire" then
					local absorbDamage = effect.TickDamage.Value * effectData.AbsorbMultiplier
					tickDmg.Value = tickDmg.Value + absorbDamage
					print(string.format("[STATUS] BlackFlame absorbed %s on %s - added %.1f damage", 
						effect.Name, target.Name, absorbDamage))
					effect:Destroy()
				end
			end
			
			-- Start DoT coroutine
			Tower.StartDoTEffect(target, blackFlameEffect, "BlackFlame")
		end
	
	-- Handle Hemorrhage (heavy permanent bleed)
	elseif effectName == "Hemorrhage" then
		local existingHemorrhage = statusFolder:FindFirstChild("Hemorrhage")
		if existingHemorrhage then
			print(string.format("[STATUS] Hemorrhage already active on %s", target.Name))
		else
			-- Create new hemorrhage effect
			local hemorrhageEffect = Instance.new("Folder")
			hemorrhageEffect.Name = "Hemorrhage"
			hemorrhageEffect.Parent = statusFolder
			
			local tickDmg = Instance.new("NumberValue")
			tickDmg.Name = "TickDamage"
			tickDmg.Value = tickDamage
			tickDmg.Parent = hemorrhageEffect
			
			local dur = Instance.new("NumberValue")
			dur.Name = "Duration"
			dur.Value = math.huge -- Permanent
			dur.Parent = hemorrhageEffect
			
			local tickRate = Instance.new("NumberValue")
			tickRate.Name = "TickRate"
			tickRate.Value = effectData.TickRate
			tickRate.Parent = hemorrhageEffect
			
			local lastTick = Instance.new("NumberValue")
			lastTick.Name = "LastTick"
			lastTick.Value = tick()
			lastTick.Parent = hemorrhageEffect
			
			print(string.format("[STATUS] Hemorrhage applied to %s - %d damage/tick (PERMANENT)", target.Name, tickDamage))
			
			-- Start DoT coroutine
			Tower.StartDoTEffect(target, hemorrhageEffect, "Hemorrhage")
		end
	
	-- Handle Stun (stops movement)
	elseif effectName == "Stun" then
		local existingStun = statusFolder:FindFirstChild("Stun")
		if existingStun then
			-- Reset timer
			existingStun.Duration.Value = duration
			print(string.format("[STATUS] Stun refreshed on %s - %ds", target.Name, duration))
		else
			-- Create new stun effect
			local stunEffect = Instance.new("Folder")
			stunEffect.Name = "Stun"
			stunEffect.Parent = statusFolder
			
			local dur = Instance.new("NumberValue")
			dur.Name = "Duration"
			dur.Value = duration
			dur.Parent = stunEffect
			
			local speedMult = Instance.new("NumberValue")
			speedMult.Name = "SpeedMultiplier"
			speedMult.Value = 0 -- Complete stop
			speedMult.Parent = stunEffect
			
			print(string.format("[STATUS] Stun applied to %s - %ds", target.Name, duration))
			
			-- Apply movement effect
			Tower.ApplyMovementEffect(target, stunEffect, "Stun")
		end
	
	-- Handle Slow (reduces movement speed)
	elseif effectName == "Slow" then
		local speedMultiplier = effectData.SpeedMultiplier
		if statusConfig and statusConfig:FindFirstChild("SpeedMultiplier") then
			speedMultiplier = statusConfig.SpeedMultiplier.Value
		end
		
		local existingSlow = statusFolder:FindFirstChild("Slow")
		if existingSlow then
			-- Reset timer and update speed
			existingSlow.Duration.Value = duration
			existingSlow.SpeedMultiplier.Value = speedMultiplier
			print(string.format("[STATUS] Slow refreshed on %s - %.0f%% speed for %ds", 
				target.Name, speedMultiplier * 100, duration))
		else
			-- Create new slow effect
			local slowEffect = Instance.new("Folder")
			slowEffect.Name = "Slow"
			slowEffect.Parent = statusFolder
			
			local dur = Instance.new("NumberValue")
			dur.Name = "Duration"
			dur.Value = duration
			dur.Parent = slowEffect
			
			local speedMult = Instance.new("NumberValue")
			speedMult.Name = "SpeedMultiplier"
			speedMult.Value = speedMultiplier
			speedMult.Parent = slowEffect
			
			print(string.format("[STATUS] Slow applied to %s - %.0f%% speed for %ds", 
				target.Name, speedMultiplier * 100, duration))
			
			-- Apply movement effect
			Tower.ApplyMovementEffect(target, slowEffect, "Slow")
		end
	
	-- Handle Hypnotized (defected enemy - placeholder)
	elseif effectName == "Hypnotized" then
		local existingHypnotized = statusFolder:FindFirstChild("Hypnotized")
		if existingHypnotized then
			-- Reset timer
			existingHypnotized.Duration.Value = duration
			print(string.format("[STATUS] Hypnotized refreshed on %s - %ds", target.Name, duration))
		else
			-- Create new hypnotized effect (placeholder for future implementation)
			local hypnotizedEffect = Instance.new("Folder")
			hypnotizedEffect.Name = "Hypnotized"
			hypnotizedEffect.Parent = statusFolder
			
			local dur = Instance.new("NumberValue")
			dur.Name = "Duration"
			dur.Value = duration
			dur.Parent = hypnotizedEffect
			
			print(string.format("[STATUS] Hypnotized applied to %s - %ds (WIP - not fully implemented)", target.Name, duration))
			
			-- Start timer for removal
			task.spawn(function()
				task.wait(GameSpeed.GetWaitTime(duration))
				if hypnotizedEffect.Parent then
					print(string.format("[STATUS] Hypnotized expired on %s", target.Name))
					hypnotizedEffect:Destroy()
				end
			end)
		end
	end
end

-- Start DoT effect coroutine
function Tower.StartDoTEffect(target, effectFolder, effectName)
	task.spawn(function()
		local humanoid = target:FindFirstChild("Humanoid")
		if not humanoid then return end
		
		local tickDamage = effectFolder:FindFirstChild("TickDamage")
		local duration = effectFolder:FindFirstChild("Duration")
		local tickRate = effectFolder:FindFirstChild("TickRate")
		local lastTick = effectFolder:FindFirstChild("LastTick")
		
		if not tickDamage or not duration or not tickRate or not lastTick then
			warn("[STATUS] Missing DoT parameters for", effectName)
			return
		end
		
		local startTime = tick()
		
		while effectFolder.Parent and humanoid.Health > 0 do
			local elapsed = tick() - startTime
			
			-- Check if duration expired
			if elapsed >= duration.Value then
				print(string.format("[STATUS] %s expired on %s", effectName, target.Name))
				effectFolder:Destroy()
				break
			end
			
			-- Check if it's time for a tick
			local timeSinceLastTick = tick() - lastTick.Value
			if timeSinceLastTick >= tickRate.Value then
				local finalDamage = tickDamage.Value
				
				-- Apply Hellfire burn boost if present
				local statusFolder = target:FindFirstChild("StatusEffects")
				if statusFolder then
					local hellfire = statusFolder:FindFirstChild("Hellfire")
					if hellfire and StatusEffects.IsBurnType(effectName) and effectName ~= "Hellfire" then
						local boostMult = hellfire:FindFirstChild("BurnBoostMultiplier")
						if boostMult then
							finalDamage = finalDamage * boostMult.Value
							print(string.format("[STATUS] Hellfire boosted %s damage: %d -> %d", 
								effectName, tickDamage.Value, finalDamage))
						end
					end
				end
				
				-- Deal tick damage
				humanoid:TakeDamage(finalDamage)
				lastTick.Value = tick()
				
				print(string.format("[STATUS] %s tick on %s - %d damage (HP: %d/%d)", 
					effectName, target.Name, finalDamage, humanoid.Health, humanoid.MaxHealth))
				
				-- Check if mob died from DoT
				if humanoid.Health <= 0 then
					print(string.format("[STATUS] %s killed %s", effectName, target.Name))
					effectFolder:Destroy()
					break
				end
			end
			
			task.wait(GameSpeed.GetWaitTime(0.1)) -- Check every 0.1 seconds
		end
	end)
end

-- Apply movement effect (Stun/Slow)
function Tower.ApplyMovementEffect(target, effectFolder, effectName)
	task.spawn(function()
		local humanoid = target:FindFirstChild("Humanoid")
		if not humanoid then return end
		
		local duration = effectFolder:FindFirstChild("Duration")
		local speedMultiplier = effectFolder:FindFirstChild("SpeedMultiplier")
		
		if not duration or not speedMultiplier then
			warn("[STATUS] Missing movement effect parameters for", effectName)
			return
		end
		
		-- Store original speed
		local originalSpeed = humanoid.WalkSpeed
		
		-- Apply speed modification
		humanoid.WalkSpeed = originalSpeed * speedMultiplier.Value
		print(string.format("[STATUS] %s movement applied: %.1f -> %.1f speed", 
			effectName, originalSpeed, humanoid.WalkSpeed))
		
		local startTime = tick()
		
		-- Monitor duration
		while effectFolder.Parent and humanoid.Health > 0 do
			local elapsed = tick() - startTime
			
			-- Check if duration expired
			if elapsed >= duration.Value then
				-- Restore original speed
				humanoid.WalkSpeed = originalSpeed
				print(string.format("[STATUS] %s expired on %s - speed restored to %.1f", 
					effectName, target.Name, originalSpeed))
				effectFolder:Destroy()
				break
			end
			
			-- Reapply speed in case it was changed
			humanoid.WalkSpeed = originalSpeed * speedMultiplier.Value
			
			task.wait(GameSpeed.GetWaitTime(0.1))
		end
		
		-- Cleanup: restore speed if effect is removed early
		if humanoid.Health > 0 then
			humanoid.WalkSpeed = originalSpeed
		end
	end)
end

function Tower.ChangeMode(player,model)
	if model and model:FindFirstChild("Config") then
		local targetMode = model.Config.TargetMode
		local modes = {"First", "Last", "Strongest", "Weakest", "Near"}
		local modeIndex = table.find(modes, targetMode.Value)

		if modeIndex < #modes then
			targetMode.Value = modes[modeIndex + 1]
		else
			targetMode.Value = modes[1]
		end
		return true
	else
		warn ("Unable to change tower mode")
		return false
	end
end

function Tower.Sell(player, model)
	if model and model:FindFirstChild("Config") then
		if model.Config.Owner.Value == player.Name then
			local investment = model.Config:FindFirstChild("TotalInvestment")
			if investment then
				player.Cash.Value += math.floor(investment.Value * 0.7)
			else
				player.Cash.Value += model.Config.Price.Value / 2
			end
			player.PlacedTowers.Value -= 1
			
			-- Cleanup XPManager tracking for this tower
			XPManager.CleanupTower(player, model)
			
			model:Destroy()
			return true
		end
	end

	warn ("Unable to sell tower")
	return false
end

-- NEW: CanUpgrade function
function Tower.CanUpgrade(player, model, path)
	if not model or not model:FindFirstChild("Config") then 
		return false, "Invalid tower"
	end

	local config = model.Config

	if config.Owner.Value ~= player.Name then 
		return false, "Not your tower"
	end

	local upgrades = config.Upgrades
	local primary = config.PrimaryPath.Value
	local towerType = model.Name

	-- Check if this path exists for this tower type
	if not UpgradeData.HasPath(towerType, path) then
		return false, "Path doesn't exist"
	end

	-- Check if upgrade exists
	local upgradeData = UpgradeData.Get(towerType, path, upgrades[path].Value + 1)
	if not upgradeData then
		return false, "Max level reached"
	end

	-- Check cost
	if player.Cash.Value < upgradeData.cost then
		return false, "Not enough cash"
	end

	-- Max primary = 6
	if upgrades[path].Value >= 6 then
		return false, "Path maxed"
	end

	-- Get available paths for this tower
	local availablePaths = UpgradeData.GetAvailablePaths(towerType)
	
	-- Find which paths have upgrades
	local pathsWithUpgrades = {}
	for _, p in ipairs(availablePaths) do
		if upgrades[p] and upgrades[p].Value > 0 then
			table.insert(pathsWithUpgrades, p)
		end
	end

	-- Lock out third path once 2 paths have any upgrades (only if tower has 3 paths)
	if #availablePaths >= 3 and #pathsWithUpgrades >= 2 then
		-- If this path doesn't have upgrades yet, block it
		if upgrades[path].Value == 0 then
			return false, "Only 2 paths allowed"
		end
	end

	-- Before primary is set (no path at tier 4 yet)
	if primary == "" then
		-- Allow any path to go to tier 3
		if upgrades[path].Value < 3 then
			return true
		end
		
		-- Tier 4 upgrade will set the primary path
		if upgrades[path].Value == 3 then
			return true
		end
		
		return false, "Choose primary path first"
	end

	-- Primary path can go to 6
	if path == primary then
		return true
	end

	-- Secondary cap at 3
	if upgrades[path].Value >= 3 then
		return false, "Secondary maxed at tier 3"
	end

	return true
end

-- NEW: Paragon upgrade function
function Tower.UpgradeToParagon(player, model)
	if not model or not model:FindFirstChild("Config") then 
		return false, "Invalid tower"
	end

	local config = model.Config
	local towerType = model.Name

	if config.Owner.Value ~= player.Name then 
		return false, "Not your tower"
	end

	-- Check if tower has paragon
	if not UpgradeData.HasParagon(towerType) then
		return false, "No paragon available"
	end

	-- Check if already paragon
	if config:FindFirstChild("IsParagon") and config.IsParagon.Value then
		return false, "Already a paragon"
	end

	local upgrades = config.Upgrades
	local paragonData = UpgradeData.GetParagon(towerType)

	-- Check if requirements are met
	if not UpgradeData.CanUpgradeToParagon(towerType, upgrades) then
		return false, "Requirements not met"
	end

	-- Check cost
	if player.Cash.Value < paragonData.cost then
		return false, "Not enough cash"
	end

	-- Deduct cost
	player.Cash.Value -= paragonData.cost
	config.TotalInvestment.Value += paragonData.cost

	-- Mark as paragon
	local isParagon = config:FindFirstChild("IsParagon")
	if not isParagon then
		isParagon = Instance.new("BoolValue")
		isParagon.Name = "IsParagon"
		isParagon.Parent = config
	end
	isParagon.Value = true

	-- Apply paragon stat changes
	if paragonData.damage then
		config.Damage.Value += paragonData.damage
	end

	if paragonData.range then
		config.Range.Value += paragonData.range
	end

	if paragonData.spa then
		config.SPA.Value += paragonData.spa
		-- Cap SPA at minimum 0.2 to prevent negative or too-low attack speeds
		if config.SPA.Value < 0.2 then
			config.SPA.Value = 0.2
		end
	end

	-- Swap model if paragon specifies a new model
	if paragonData.model then
		local newTower = Tower.SwapTowerModel(model, paragonData.model)
		if newTower then
			print(string.format("Upgraded %s to PARAGON: %s with model swap to %s", towerType, paragonData.name, paragonData.model))
			return true, newTower
		end
	end

	print(string.format("Upgraded %s to PARAGON: %s", towerType, paragonData.name))

	return true
end

-- NEW: Upgrade function
function Tower.Upgrade(player, model, path)
	local canUpgrade, reason = Tower.CanUpgrade(player, model, path)
	if not canUpgrade then
		warn("Cannot upgrade:", reason)
		return false
	end

	local config = model.Config
	local upgrades = config.Upgrades
	local towerType = model.Name

	-- Get upgrade data
	local level = upgrades[path].Value + 1
	local upgradeData = UpgradeData.Get(towerType, path, level)

	-- Deduct cost
	player.Cash.Value -= upgradeData.cost
	config.TotalInvestment.Value += upgradeData.cost

	-- Update upgrade state
	upgrades[path].Value = level

	-- Set primary path when reaching tier 4
	if config.PrimaryPath.Value == "" and level == 4 then
		config.PrimaryPath.Value = path
		print(string.format("Primary path set to %s for %s", path, towerType))
	end

	-- Apply stat changes
	if upgradeData.damage then
		config.Damage.Value += upgradeData.damage
	end

	if upgradeData.range then
		config.Range.Value += upgradeData.range
	end

	if upgradeData.spa then
		config.SPA.Value += upgradeData.spa
		-- Cap SPA at minimum 0.2 to prevent negative or too-low attack speeds
		if config.SPA.Value < 0.2 then
			config.SPA.Value = 0.2
		end
	end

	-- Swap model if upgrade specifies a new model
	if upgradeData.model then
		local newTower = Tower.SwapTowerModel(model, upgradeData.model)
		if newTower then
			print(string.format("Upgraded %s path %s to level %d with model swap to %s", towerType, path, level, upgradeData.model))
			return true, newTower
		end
	end

	print(string.format("Upgraded %s path %s to level %d", towerType, path, level))

	return true
end

-- NEW: Get upgrade cost and name for UI (client-safe)
function Tower.GetUpgradeCost(player, towerType, path, level)
	local data = UpgradeData.Get(towerType, path, level)
	if data then
		return data.cost, data.name
	end
	return nil, nil
end

-- NEW: Get path color for UI (client-safe)
function Tower.GetPathColor(player, towerType, path)
	return UpgradeData.GetPathColor(towerType, path)
end

-- NEW: Get upgrade stats for preview (client-safe)
function Tower.GetUpgradeStats(player, towerType, path, level)
	local data = UpgradeData.Get(towerType, path, level)
	if data then
		return {
			damage = data.damage or 0,
			range = data.range or 0,
			spa = data.spa or 0
		}
	end
	return nil
end

-- NEW: Get paragon data for preview (client-safe)
function Tower.GetParagonData(player, towerType)
	local paragon = UpgradeData.GetParagon(towerType)
	if paragon then
		return {
			damage = paragon.damage or 0,
			range = paragon.range or 0,
			spa = paragon.spa or 0,
			cost = paragon.cost or 0
		}
	end
	return nil
end

-- Helper function to swap tower model while preserving state
function Tower.SwapTowerModel(oldTower, newModelName)
	-- Find the new model in ReplicatedStorage
	local newModelTemplate = ReplicatedStorage.Towers:FindFirstChild(newModelName)
	if not newModelTemplate then
		warn("Model not found:", newModelName)
		return false
	end
	
	-- Store old tower state
	local oldConfig = oldTower.Config:Clone()
	local oldCFrame = oldTower.HumanoidRootPart.CFrame
	local oldBodyGyro = oldTower.HumanoidRootPart:FindFirstChild("BodyGyro")
	local oldGyroCFrame = oldBodyGyro and oldBodyGyro.CFrame or oldCFrame
	
	-- Clone new model
	local newTower = newModelTemplate:Clone()
	
	-- Remove new model's default config and replace with old config (preserves OriginalTowerType)
	if newTower:FindFirstChild("Config") then
		newTower.Config:Destroy()
	end
	oldConfig.Parent = newTower
	
	-- Position new tower
	newTower.HumanoidRootPart.CFrame = oldCFrame
	
	-- Parent to workspace FIRST (required before SetNetworkOwner)
	newTower.Parent = workspace.Towers
	
	-- Now set network ownership and anchor (must be after parenting)
	newTower.HumanoidRootPart:SetNetworkOwner(nil)
	newTower.HumanoidRootPart.Anchored = true
	
	-- Add BodyGyro
	local bodyGyro = Instance.new("BodyGyro")
	bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	bodyGyro.D = 0
	bodyGyro.CFrame = oldGyroCFrame
	bodyGyro.Parent = newTower.HumanoidRootPart
	
	-- Get player for attack coroutine
	local ownerName = oldConfig.Owner.Value
	local player = game.Players:FindFirstChild(ownerName)
	
	-- Remove old tower
	oldTower:Destroy()
	
	-- Start attack coroutine for new tower
	if player then
		coroutine.wrap(Tower.Attack)(newTower, player)
	end
	
	print(string.format("Swapped tower model to: %s", newModelName))
	return newTower
end

function Tower.Spawn(player, name, cframe, previous)
	local allowedToSpawn = Tower.CheckSpawn(player, name, previous)
	if allowedToSpawn then

		-- PHASE 5: Removed old upgrade model swapping logic
		local newTower = ReplicatedStorage.Towers[name]:Clone()
		local oldMode = nil

		local ownervalue = Instance.new("StringValue")
		ownervalue.Name = "Owner"
		ownervalue.Value = player.Name
		ownervalue.Parent = newTower.Config
		
		-- Store original tower type for tracking through model swaps (e.g., paragon upgrades)
		local originalType = Instance.new("StringValue")
		originalType.Name = "OriginalTowerType"
		originalType.Value = name
		originalType.Parent = newTower.Config

		if not previous then
			local upgrades = Instance.new("Folder")
			upgrades.Name = "Upgrades"
			upgrades.Parent = newTower.Config

			for _, path in ipairs({"A", "B" , "C"}) do
				local v = Instance.new("IntValue")
				v.Name = path
				v.Value = 0
				v.Parent = upgrades
			end

			local primaryPath = Instance.new("StringValue")
			primaryPath.Name = "PrimaryPath"
			primaryPath.Value = ""
			primaryPath.Parent = newTower.Config

			local totalInvestment = Instance.new("IntValue")
			totalInvestment.Name = "TotalInvestment"
			totalInvestment.Value = newTower.Config.Price.Value
			totalInvestment.Parent = newTower.Config
		end

		local targetMode = Instance.new("StringValue")
		targetMode.Name = "TargetMode"
		targetMode.Value = oldMode or "First"
		targetMode.Parent = newTower.Config
		
		-- Add crit and status effect stats from TowerUpgradeData
		local towerData = UpgradeData[name]
		
		local critChance = Instance.new("NumberValue")
		critChance.Name = "CritChance"
		critChance.Value = (towerData and towerData.CritChance) or 0
		critChance.Parent = newTower.Config
		
		local critDamage = Instance.new("NumberValue")
		critDamage.Name = "CritDamage"
		critDamage.Value = (towerData and towerData.CritDamage) or 2
		critDamage.Parent = newTower.Config
		
		local statusType = Instance.new("StringValue")
		statusType.Name = "StatusType"
		statusType.Value = (towerData and towerData.StatusType) or "None"
		statusType.Parent = newTower.Config
		
		-- Add status effect configuration folder if tower has status effects
		if towerData and towerData.StatusType ~= "None" and towerData.StatusEffect then
			local statusConfig = Instance.new("Folder")
			statusConfig.Name = "StatusEffectConfig"
			statusConfig.Parent = newTower.Config
			
			-- Add customizable parameters from TowerUpgradeData
			for paramName, paramValue in pairs(towerData.StatusEffect) do
				local valueInstance
				if type(paramValue) == "number" then
					valueInstance = Instance.new("NumberValue")
				elseif type(paramValue) == "string" then
					valueInstance = Instance.new("StringValue")
				elseif type(paramValue) == "boolean" then
					valueInstance = Instance.new("BoolValue")
				end
				
				if valueInstance then
					valueInstance.Name = paramName
					valueInstance.Value = paramValue
					valueInstance.Parent = statusConfig
				end
			end
		end

		newTower.HumanoidRootPart.CFrame = cframe
		newTower.Parent = workspace.Towers
		newTower.HumanoidRootPart:SetNetworkOwner(nil)

		-- Add BodyGyro
		local bodyGyro = Instance.new("BodyGyro")
		bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
		bodyGyro.D = 0
		bodyGyro.CFrame = newTower.HumanoidRootPart.CFrame
		bodyGyro.Parent = newTower.HumanoidRootPart

		-- Ensure HumanoidRootPart is anchored
		newTower.HumanoidRootPart.Anchored = true

		player.Cash.Value -= newTower.Config.Price.Value

		if not previous then
			player.PlacedTowers.Value += 1
		end

		-- TODO: Register tower with XPManager when UnitInstances system is integrated
		-- XPManager.Register(player, newTower, instanceId)
		
		coroutine.wrap(Tower.Attack)(newTower, player)
		return newTower
	else
		warn("Requested Tower does not exist:", name)
		return false
	end
end

function Tower.CheckSpawn(player, name, previous)
	local towerExists = ReplicatedStorage.Towers:FindFirstChild(name, true)

	if towerExists then
		if towerExists.Config.Price.Value <= player.Cash.Value then
			if previous or player.PlacedTowers.value < maxTowers then
				return true
			else
				warn("Player has reached max limit")
			end
		else
			warn("Player cannot afford")
		end
	else 
		warn("Tower does not exist")
	end

	return false
end

-- Get pre-created upgrade functions
local upgradeTowerFunction = functions:WaitForChild("UpgradeTower")
local getUpgradeCostFunction = functions:WaitForChild("GetUpgradeCost")
local upgradeToParagonFunction = functions:WaitForChild("UpgradeToParagon")
local getUpgradeStatsFunction = functions:WaitForChild("GetUpgradeStats")
local getParagonDataFunction = functions:WaitForChild("GetParagonData")
local getPathColorFunction = functions:WaitForChild("GetPathColor")

-- Connect all functions
changeTowerPriorityFunction.OnServerInvoke = Tower.ChangeMode
sellTowerFunction.OnServerInvoke = Tower.Sell
spawnTowerFunction.OnServerInvoke = Tower.Spawn
requestTowerFunction.OnServerInvoke = Tower.CheckSpawn
upgradeTowerFunction.OnServerInvoke = Tower.Upgrade
getUpgradeCostFunction.OnServerInvoke = Tower.GetUpgradeCost
upgradeToParagonFunction.OnServerInvoke = Tower.UpgradeToParagon
getUpgradeStatsFunction.OnServerInvoke = Tower.GetUpgradeStats
getParagonDataFunction.OnServerInvoke = Tower.GetParagonData
getPathColorFunction.OnServerInvoke = Tower.GetPathColor

return Tower
