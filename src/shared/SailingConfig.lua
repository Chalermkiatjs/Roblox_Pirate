local Sailing = {
    Stages = {
        [-1] = {name = "Reverse", deployment = 0, throttle = -1},
        [0] = {name = "Stopped", deployment = 0, throttle = 0},
        [1] = {name = "Paddles", deployment = 0, throttle = 1},
        [2] = {name = "Sail I", deployment = 0.5, throttle = 1},
        [3] = {name = "Sail II", deployment = 1, throttle = 1},
    },
    MinStage = -1,
    MaxStage = 3,
    StageInputInterval = 0.08,
    DeployTime = 1.4,
    PaddleSpeed = 0.28,
    WindX = 0,
    WindZ = -1,
}

function Sailing.validStage(stage)
    return type(stage) == "number" and stage == stage and Sailing.Stages[stage] ~= nil
end

function Sailing.speedMultiplier(deployment, throttle, windAlignment)
    if deployment < 0.001 then return throttle * Sailing.PaddleSpeed end
    if throttle < -0.1 then return 0 end
    local wind = 0.55 + 0.45 * math.clamp(windAlignment, -1, 1)
    wind = math.max(0.35, wind)
    return (0.2 + deployment * 0.8) * wind
end

function Sailing.stepStage(stage, direction)
    if not Sailing.validStage(stage) or (direction ~= 1 and direction ~= -1) then return nil end
    return math.clamp(stage + direction, Sailing.MinStage, Sailing.MaxStage)
end

function Sailing.stageSpeedMultiplier(stage, deployment, windAlignment)
    local settings = Sailing.Stages[stage]
    local multiplier = Sailing.speedMultiplier(math.min(deployment, settings.deployment), settings.throttle, windAlignment)
    if stage >= 2 then return math.max(Sailing.PaddleSpeed, multiplier) end
    return multiplier
end

function Sailing.transitionDuration(currentDeployment, stage)
    local target = Sailing.Stages[stage].deployment
    if type(currentDeployment) ~= "number" or currentDeployment ~= currentDeployment then currentDeployment = 0 end
    currentDeployment = math.clamp(currentDeployment, 0, 1)
    return math.abs(target - currentDeployment) * Sailing.DeployTime
end

return Sailing
