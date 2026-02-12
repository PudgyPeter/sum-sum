local BossData = {

	-- Wave 15 Final Boss
	Boss3 = {
		Name = "Evil Clown",
		BaseHealth = 4000,  -- Reduced from 20000 for debugging
		BaseDamage = 50,
		BaseSpeed = 5,
		SizeMultiplier = 3.0,
		Color = Color3.fromRGB(255, 215, 0),
		RewardMultiplier = 20,
		Abilities = {
			{

			}
		}
	}
}

function BossData.GetBossData(waveNumber)
	if waveNumber == 15 then
		return BossData.Boss3
	end
	return nil
end

function BossData.IsBossWave(waveNumber)
	return waveNumber == 15
end

function BossData.GetBossHealth(waveNumber)
	local bossData = BossData.GetBossData(waveNumber)
	if not bossData then return nil end

	-- Apply wave scaling to boss health
	local waveMultiplier = 1 + ((waveNumber - 1) * 0.3)
	return math.floor(bossData.BaseHealth * waveMultiplier)
end

function BossData.GetBossReward(waveNumber)
	local bossData = BossData.GetBossData(waveNumber)
	if not bossData then return 0 end

	return 100 * waveNumber * bossData.RewardMultiplier
end

return BossData
