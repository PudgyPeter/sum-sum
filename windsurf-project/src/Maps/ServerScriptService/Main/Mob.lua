local serverStorage = game:GetService("ServerStorage")
local PhysicsService = game:GetService("PhysicsService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BossData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("BossData"))
local MobData = require(script.Parent.MobData)
local GameSpeed = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GameSpeed"))
local mob = {}

-- Function to update all existing mob speeds based on current game speed
function mob.UpdateAllMobSpeeds()
	local currentSpeed = GameSpeed.GetSpeed()
	for _, mobInstance in ipairs(workspace.Mobs:GetChildren()) do
		if mobInstance:FindFirstChild("Humanoid") and mobInstance:FindFirstChild("BaseSpeed") then
			local baseSpeed = mobInstance.BaseSpeed.Value
			mobInstance.Humanoid.WalkSpeed = baseSpeed * currentSpeed
		end
	end
end

local function moveTo(humanoid, targetPoint, andThen)
	local targetReached = false
	-- listen for the humanoid reaching its target
	local connection
	connection = humanoid.MoveToFinished:Connect(function(reached)
		targetReached = true
		connection:Disconnect()
		connection = nil
		if andThen then
			andThen(reached)
		end
	end)
	-- start walking
	humanoid:MoveTo(targetPoint)
	-- execute on a new thread so as to not yield function
	task.spawn(function()
		while not targetReached do
			-- does the humanoid still exist?
			if not (humanoid and humanoid.Parent) then
				break
			end
			-- has the target changed?
			if humanoid.WalkToPoint ~= targetPoint then
				break
			end
			-- refresh the timeout
			humanoid:MoveTo(targetPoint)
			task.wait(6)
		end
		-- disconnect the connection if it is still connected
		if connection then
			connection:Disconnect()
			connection = nil
		end
	end)
end

function mob.Move(mob, map)
	local humanoid = mob:WaitForChild("Humanoid")
	local waypoints = map.Waypoints

	for waypoint=1, #waypoints:GetChildren() do
		mob.MovingTo.Value = waypoint

		-- Use a promise-like pattern to wait for movement completion
		local moveCompleted = false

		moveTo(humanoid, waypoints[waypoint].Position, function(reached)
			moveCompleted = true
		end)

		-- Wait for the move to complete
		while not moveCompleted do
			task.wait()
		end
	end

	-- Calculate damage based on mob type
	local damage = mob.Health -- Default fallback
	local bossType = mob:FindFirstChild("BossType")
	
	if bossType then
		-- Boss damage
		local bossWave = mob:FindFirstChild("BossWave")
		if bossWave then
			local bossData = BossData.GetBossData(bossWave.Value)
			if bossData then
				damage = bossData.BaseDamage
			end
		end
	else
		-- Regular mob damage from MobData
		local mobWave = mob:FindFirstChild("Wave")
		if mobWave then
			damage = MobData.GetScaledDamage(mob.Name, mobWave.Value)
		end
	end
	
	mob:Destroy()
	map.Base.Humanoid:TakeDamage(damage)
end

function mob.Spawn(name, quantity, map, waveNumber)
	local mobExists = ServerStorage.Mobs:FindFirstChild(name)
	if mobExists then
		for i=1, quantity do
			task.wait(GameSpeed.GetWaitTime(0.5))
			local newMob = mobExists:Clone()
			
			-- Apply stats from MobData BEFORE parenting (so client sees correct stats immediately)
			if waveNumber then
				local humanoid = newMob:FindFirstChild("Humanoid")
				if humanoid then
					-- Get scaled stats from MobData
					local stats = MobData.GetScaledStats(name, waveNumber)
					humanoid.MaxHealth = stats.Health
					humanoid.Health = stats.Health
					humanoid.WalkSpeed = stats.Speed * GameSpeed.GetSpeed()
					
					-- Store base speed for dynamic speed updates
					local baseSpeedValue = Instance.new("NumberValue")
					baseSpeedValue.Name = "BaseSpeed"
					baseSpeedValue.Value = stats.Speed
					baseSpeedValue.Parent = newMob
					
					print(string.format("[MOB] Spawned %s (Wave %d): HP=%d, Speed=%d, Damage=%d, Reward=%d", 
						name, waveNumber, stats.Health, stats.Speed, stats.Damage, stats.Reward))
				end
			end
			
			newMob.HumanoidRootPart.CFrame = map.Start.CFrame
			newMob.Parent = workspace.Mobs
			newMob.HumanoidRootPart:SetNetworkOwner(nil)
			
			-- Store wave number for damage calculation
			local waveValue = Instance.new("IntValue")
			waveValue.Name = "Wave"
			waveValue.Value = waveNumber or 1
			waveValue.Parent = newMob
			
			local movingTo = Instance.new("IntValue")
			movingTo.Name = "MovingTo"
			movingTo.Parent = newMob
			
			-- Set collision groups for all parts
			for i, object in ipairs(newMob:GetDescendants()) do
				if object:IsA("BasePart") then
					object.CollisionGroup = "Mob"
				end
			end
			
			-- Connect death event ONCE per mob
			newMob.Humanoid.Died:Connect(function()
				-- Mark as dead immediately so towers stop targeting
				local isDead = Instance.new("BoolValue")
				isDead.Name = "IsDead"
				isDead.Value = true
				isDead.Parent = newMob
				
				-- Hide and freeze mob immediately
				for i, object in ipairs(newMob:GetDescendants()) do
					if object:IsA("BillboardGui") then
						-- Set size to 0 to hide GUI
						object.Size = UDim2.new(0, 0, 0, 0)
					elseif object:IsA("BasePart") then
						-- Anchor to prevent ragdoll/falling
						object.Anchored = true
						object.Transparency = 1
						object.CanCollide = false
						object.CanTouch = false
						object.CanQuery = false
					end
				end
				task.wait(GameSpeed.GetWaitTime(0.5))
				newMob:Destroy()
			end)
			
			coroutine.wrap(mob.Move)(newMob, map)
		end
	else
		warn("Requested mob does not exist:", name)
	end
end

function mob.SpawnBoss(waveNumber, map)
	local bossData = BossData.GetBossData(waveNumber)
	if not bossData then
		warn("No boss data for wave:", waveNumber)
		return
	end
	
	-- Get base mob template (use Illxstrate as base for boss)
	local baseMob = ServerStorage.Mobs:FindFirstChild("illxstrate")
	if not baseMob then
		warn("Base mob template not found for boss spawning")
		return
	end
	
	print("=== BOSS SPAWN DEBUG ===")
	print("Template humanoid health:", baseMob:FindFirstChild("Humanoid") and baseMob.Humanoid.Health or "NO HUMANOID")
	
	local boss = baseMob:Clone()
	
	-- IMPORTANT: Check if template already has death events
	print("Boss humanoid health after clone:", boss:FindFirstChild("Humanoid") and boss.Humanoid.Health or "NO HUMANOID")
	
	-- Get humanoid reference
	local humanoid = boss:FindFirstChild("Humanoid")
	if not humanoid then
		warn("Boss has no humanoid!")
		return
	end
	
	-- Set walk speed early (this won't reset)
	humanoid.WalkSpeed = bossData.BaseSpeed * GameSpeed.GetSpeed()
	
	-- Apply boss appearance changes
	-- Use ScaleTo to properly scale the model without breaking joints
	if boss:IsA("Model") then
		boss:ScaleTo(bossData.SizeMultiplier)
	end
	
	-- Apply color and material changes
	for _, part in ipairs(boss:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Color = bossData.Color
			part.Material = Enum.Material.Neon
		end
	end
	
	-- Mark as boss
	local bossTag = Instance.new("StringValue")
	bossTag.Name = "BossType"
	bossTag.Value = bossData.Name
	bossTag.Parent = boss
	
	local bossWave = Instance.new("IntValue")
	bossWave.Name = "BossWave"
	bossWave.Value = waveNumber
	bossWave.Parent = boss
	
	-- Boss spawn notification will be handled by client-side boss detection
	
	-- Spawn boss with delay for dramatic effect
	task.wait(GameSpeed.GetWaitTime(1))
	-- Spawn boss 15 studs in front of spawn to avoid getting stuck in cave
	local spawnCFrame = map.Start.CFrame * CFrame.new(0, 0, -15)
	boss.HumanoidRootPart.CFrame = spawnCFrame
	boss.Parent = workspace.Mobs
	boss.HumanoidRootPart:SetNetworkOwner(nil)
	
	-- CRITICAL: Set health AFTER parenting (Roblox resets humanoid properties on parenting)
	-- Wait for Roblox to process the parenting operation
	task.wait()
	local bossHealth = BossData.GetBossHealth(waveNumber)
	print("Setting boss health after parenting...")
	humanoid.MaxHealth = bossHealth
	humanoid.Health = bossHealth
	print("Boss health set:", humanoid.Health, "/", humanoid.MaxHealth)
	
	-- Monitor health for first 10 seconds
	print("Boss spawned! Starting health monitoring...")
	print("Initial health:", humanoid.Health, "/", humanoid.MaxHealth)
	local startTime = tick()
	local lastHealth = humanoid.Health
	local connection
	connection = humanoid.HealthChanged:Connect(function(newHealth)
		local elapsed = tick() - startTime
		local damageTaken = lastHealth - newHealth
		if damageTaken > 0 then
			print(string.format("[%.2fs] Boss took %d damage! Health: %d/%d", elapsed, damageTaken, newHealth, humanoid.MaxHealth))
		end
		lastHealth = newHealth
		if newHealth <= 0 then
			connection:Disconnect()
		end
	end)
	
	-- Auto-stop monitoring after 10 seconds
	task.delay(10, function()
		if connection then
			connection:Disconnect()
			print("Health monitoring stopped - boss survived 10 seconds")
		end
	end)
	
	local movingTo = Instance.new("IntValue")
	movingTo.Name = "MovingTo"
	movingTo.Parent = boss
	
	-- Store base speed for dynamic speed updates
	local baseSpeedValue = Instance.new("NumberValue")
	baseSpeedValue.Name = "BaseSpeed"
	baseSpeedValue.Value = bossData.BaseSpeed
	baseSpeedValue.Parent = boss
	
	-- Set collision groups
	for _, object in ipairs(boss:GetDescendants()) do
		if object:IsA("BasePart") then
			object.CollisionGroup = "Mob"
		end
	end
	
	-- Enhanced boss death event
	boss.Humanoid.Died:Connect(function()
		print("=== BOSS DEATH INVESTIGATION ===")
		print("Boss:", bossData.Name)
		print("Wave:", waveNumber)
		print("Time since spawn:", tick())
		print("Last damage source:", boss.Humanoid:FindFirstChild("Creator") and boss.Humanoid.Creator.Value or "No creator tag")
		
		-- Check what towers are in range
		local towersInRange = 0
		if boss:FindFirstChild("HumanoidRootPart") then
			for _, tower in ipairs(workspace.Towers:GetChildren()) do
				if tower:FindFirstChild("HumanoidRootPart") then
					local distance = (tower.HumanoidRootPart.Position - boss.HumanoidRootPart.Position).Magnitude
					local towerRange = tower.Config and tower.Config.Range.Value or 0
					if distance <= towerRange then
						towersInRange = towersInRange + 1
						print("Tower in range:", tower.Name, "Distance:", distance, "Range:", towerRange)
					end
				end
			end
			print("Total towers in range:", towersInRange)
		else
			print("Boss HumanoidRootPart missing - cannot check tower ranges")
		end
		
		-- Award bonus reward
		local reward = BossData.GetBossReward(waveNumber)
		for _, player in ipairs(game.Players:GetPlayers()) do
			player.Cash.Value += reward
		end
		
		-- Fire RemoteEvent for boss death notification
		local events = game.ReplicatedStorage:WaitForChild("Events")
		local bossDeathEvent = events:WaitForChild("BossDeath")
		if bossDeathEvent then
			bossDeathEvent:FireAllClients(bossData.Name, reward)
		end
		
		-- Mark as dead
		local isDead = Instance.new("BoolValue")
		isDead.Name = "IsDead"
		isDead.Value = true
		isDead.Parent = boss
		
		-- Hide boss
		for _, object in ipairs(boss:GetDescendants()) do
			if object:IsA("BillboardGui") then
				object.Size = UDim2.new(0, 0, 0, 0)
			elseif object:IsA("BasePart") then
				object.Anchored = true
				object.Transparency = 1
				object.CanCollide = false
				object.CanTouch = false
				object.CanQuery = false
			end
		end
		task.wait(GameSpeed.GetWaitTime(1))
		boss:Destroy()
	end)
	
	-- Start boss movement
	coroutine.wrap(mob.Move)(boss, map)
end

return mob
