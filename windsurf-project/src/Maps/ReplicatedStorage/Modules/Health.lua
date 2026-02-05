local Players = game:GetService("Players")
local health = {}

function health.Setup(model, screenGui)
	local humanoid = model:WaitForChild("Humanoid", 5)
	if not humanoid then
		warn("Humanoid not found in:", model.Name)
		return
	end

	local newHealthBar = script.HealthGui:Clone()
	local head = model:WaitForChild("Head", 5)
	if not head then
		warn("Head not found in:", model.Name)
		return
	end

	newHealthBar.Adornee = head
	newHealthBar.Parent = model

	-- Check if this is a boss
	local bossType = model:FindFirstChild("BossType")
	if bossType then
		-- Boss health bar styling
		newHealthBar.Size = UDim2.new(4,0,1.5,0)
		newHealthBar.MaxHealth.Size = UDim2.new(1, 0, 0.5, 0)
		newHealthBar.MaxHealth.BackgroundColor3 = Color3.fromRGB(139, 0, 0)
		
		-- Set CurrentHealth size - check if it's child of MaxHealth or sibling
		local currentHealth = newHealthBar.MaxHealth:FindFirstChild("CurrentHealth")
		if not currentHealth then
			currentHealth = newHealthBar:FindFirstChild("CurrentHealth")
		end
		
		if currentHealth then
			if currentHealth.Parent == newHealthBar.MaxHealth then
				-- Child of MaxHealth - fill parent
				currentHealth.Size = UDim2.new(1, 0, 1, 0)
				currentHealth.Position = UDim2.new(0, 0, 0, 0)
				currentHealth.AnchorPoint = Vector2.new(0, 0)
			else
				-- Sibling of MaxHealth - match MaxHealth size
				currentHealth.Size = UDim2.new(1, 0, 0.5, 0)
			end
		end
		
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(255, 215, 0)
		stroke.Thickness = 4
		stroke.Parent = newHealthBar.MaxHealth
		
		local glow = Instance.new("ImageLabel")
		glow.Name = "Glow"
		glow.Size = UDim2.new(1.2, 0, 1.2, 0)
		glow.Position = UDim2.new(-0.1, 0, -0.1, 0)
		glow.BackgroundTransparency = 1
		glow.Image = "rbxassetid://5028857080"
		glow.ImageColor3 = Color3.fromRGB(255, 215, 0)
		glow.ImageTransparency = 0.7
		glow.ZIndex = -1
		glow.Parent = newHealthBar
		
		-- Add boss name label
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "BossName"
		nameLabel.Size = UDim2.new(1, 0, 0.3, 0)
		nameLabel.Position = UDim2.new(0, 0, -0.3, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = bossType.Value
		nameLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
		nameLabel.TextScaled = true
		nameLabel.Font = Enum.Font.FredokaOne
		nameLabel.Parent = newHealthBar
	elseif model.Name == "Base" then
		newHealthBar.Size = UDim2.new(0,0,0,0)
		newHealthBar.MaxHealth.Size = UDim2.new(1, 0, 0.5, 0)
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Thickness = 3
		stroke.Parent = newHealthBar.MaxHealth
	else
		newHealthBar.Size = UDim2.new(2.5,0,1,0)
	end

	health.UpdateHealth(newHealthBar, model)
	if screenGui then
		health.UpdateHealth(screenGui, model)
	end

	humanoid.HealthChanged:Connect(function()
		-- Check if model still exists before updating
		if model and model.Parent then
			-- Hide GUI immediately when health reaches 0 (client-side)
			if humanoid.Health <= 0 and newHealthBar and newHealthBar.Parent then
				newHealthBar:Destroy()
			elseif newHealthBar and newHealthBar.Parent then
				-- Only update if GUI still exists
				health.UpdateHealth(newHealthBar, model)
				if screenGui then
					health.UpdateHealth(screenGui, model)
				end
			end
		end
	end)

	if screenGui then
		health.UpdateHealth(screenGui, model)
	end
end

function health.UpdateHealth(gui, model, newHealthBar)
	-- Add timeout and check if model exists
	if not model or not model.Parent then return end

	local humanoid = model:FindFirstChild("Humanoid") -- Use FindFirstChild instead of WaitForChild
	if humanoid and gui then
		local percent = humanoid.Health / humanoid.MaxHealth
		
		-- Update health bar size
		local maxHealth = gui:FindFirstChild("MaxHealth")
		-- Try to find CurrentHealth as child of MaxHealth first, then as sibling
		local currentHealth = maxHealth and maxHealth:FindFirstChild("CurrentHealth")
		if not currentHealth then
			currentHealth = gui:FindFirstChild("CurrentHealth")
		end
		
		if currentHealth then
			-- For boss/base health bars
			if model:FindFirstChild("BossType") or model.Name == "Base" then
				-- Check if CurrentHealth is a child of MaxHealth or a sibling
				if currentHealth.Parent == maxHealth then
					-- Child of MaxHealth - fill parent height
					currentHealth.Size = UDim2.new(math.max(percent, 0), 0, 1, 0)
				else
					-- Sibling of MaxHealth - match MaxHealth height
					local heightScale = (maxHealth and maxHealth.Size.Y.Scale) or 0.5
					currentHealth.Size = UDim2.new(math.max(percent, 0), 0, heightScale, 0)
				end
			else
				-- Regular mobs
				local heightScale = (maxHealth and maxHealth.Size.Y.Scale) or 0.5
				currentHealth.Size = UDim2.new(math.max(percent, 0), 0, heightScale, 0)
			end
		end
		
		-- Update text labels
		if humanoid.Health <= 0 then
			local modelLabel = gui:FindFirstChild("Model")
			if modelLabel then
				modelLabel.Text = model.Name
			end
		else
			local healthLabel = gui:FindFirstChild("Health")
			if healthLabel then
				healthLabel.Text = humanoid.Health .. "/" .. humanoid.MaxHealth
			end
			
			local modelLabel = gui:FindFirstChild("Model")
			if modelLabel then
				modelLabel.Text = model.Name
			end
		end
	end
end

return health
