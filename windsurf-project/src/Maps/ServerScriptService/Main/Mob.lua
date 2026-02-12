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
	local humanoid = mob:FindFirstChild("Humanoid")
	local damage = humanoid and humanoid.Health or 1 -- Default fallback
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
			-- Stop spawning if base is destroyed
			if map.Base.Humanoid.Health <= 0 then break end
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
					
					-- Verbose per-mob log disabled to reduce spam
				-- print(string.format("[MOB] Spawned %s (Wave %d): HP=%d, Speed=%d, Damage=%d, Reward=%d", 
				-- 	name, waveNumber, stats.Health, stats.Speed, stats.Damage, stats.Reward))
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
	
	local boss = baseMob:Clone()
	
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
	
	-- Create MovingTo BEFORE parenting so towers don't error when targeting
	local movingTo = Instance.new("IntValue")
	movingTo.Name = "MovingTo"
	movingTo.Parent = boss
	
	-- Store base speed for dynamic speed updates
	local baseSpeedValue = Instance.new("NumberValue")
	baseSpeedValue.Name = "BaseSpeed"
	baseSpeedValue.Value = bossData.BaseSpeed
	baseSpeedValue.Parent = boss
	
	-- Set collision groups before parenting
	for _, object in ipairs(boss:GetDescendants()) do
		if object:IsA("BasePart") then
			object.CollisionGroup = "Mob"
		end
	end
	
	-- Spawn boss with delay for dramatic effect
	task.wait(GameSpeed.GetWaitTime(1))
	-- Spawn boss 15 studs in front of spawn to avoid getting stuck in cave
	local spawnCFrame = map.Start.CFrame * CFrame.new(0, 0, -15)
	boss.HumanoidRootPart.CFrame = spawnCFrame
	boss.Parent = workspace.Mobs
	boss.HumanoidRootPart:SetNetworkOwner(nil)
	
	-- CRITICAL: Set health AFTER parenting (Roblox resets humanoid properties on parenting)
	task.wait()
	local bossHealth = BossData.GetBossHealth(waveNumber)
	humanoid.MaxHealth = bossHealth
	humanoid.Health = bossHealth
	
	-- Boss death event
	boss.Humanoid.Died:Connect(function()
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
