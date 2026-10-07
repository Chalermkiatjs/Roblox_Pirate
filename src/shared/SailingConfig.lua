local Sailing = {
    Stages = {
        [0] = {name = "Paddles", deployment = 0},
        [1] = {name = "Sail I", deployment = 0.5},
        [2] = {name = "Sail II", deployment = 1},
    },
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

return Sailing
