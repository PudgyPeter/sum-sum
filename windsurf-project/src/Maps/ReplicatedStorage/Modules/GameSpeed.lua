local GameSpeed = {}

GameSpeed.CurrentSpeed = 1
GameSpeed.DEBUG_MODE = false
GameSpeed.AvailableSpeeds = {1, 2, 5, 10}

function GameSpeed.SetSpeed(speed)
	GameSpeed.CurrentSpeed = speed
end

function GameSpeed.GetSpeed()
	return GameSpeed.CurrentSpeed
end

function GameSpeed.GetWaitTime(baseTime)
	return baseTime / GameSpeed.CurrentSpeed
end

function GameSpeed.GetAvailableSpeeds()
	return GameSpeed.AvailableSpeeds
end

return GameSpeed
