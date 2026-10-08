local Sailing = require("../src/shared/SailingConfig")
for stage = Sailing.MinStage, Sailing.MaxStage do assert(Sailing.validStage(stage)) end
for _, value in ipairs({-2, 4, 0.5, "2", math.huge, 0 / 0}) do
    assert(not Sailing.validStage(value), "Invalid stage accepted")
end
local paddle = Sailing.speedMultiplier(0, 1, 1)
local half = Sailing.speedMultiplier(0.5, 0, 1)
local full = Sailing.speedMultiplier(1, 0, 1)
assert(paddle > 0 and paddle < half and half < full, "Stages do not increase cruising speed")
assert(Sailing.speedMultiplier(0, 0, 1) == 0, "Paddles move without input")
assert(Sailing.speedMultiplier(0, -1, 1) < 0, "Paddles cannot reverse")
assert(Sailing.speedMultiplier(1, -1, 1) == 0, "Full sails cannot brake")
assert(Sailing.speedMultiplier(1, 0, -1) > 0, "Return trip against wind is impossible")
assert(Sailing.speedMultiplier(1, 0, -1) < full, "Wind direction has no effect")
assert(math.abs(Sailing.transitionDuration(0, 3) - Sailing.DeployTime) < 0.0001, "Full deploy duration is wrong")
assert(math.abs(Sailing.transitionDuration(0, 2) - Sailing.DeployTime * 0.5) < 0.0001, "Half deploy duration is not proportional")
assert(math.abs(Sailing.transitionDuration(0.5, 3) - Sailing.DeployTime * 0.5) < 0.0001, "Sail I to Sail II duration is not proportional")
assert(math.abs(Sailing.transitionDuration(1, 0) - Sailing.DeployTime) < 0.0001, "Full stow duration is wrong")
for _, fps in ipairs({30, 60, 120}) do
    local deployed = 0
    for _, stage in ipairs({2, 3, 0}) do
        local desired = Sailing.Stages[stage].deployment
        for _ = 1, fps * 2 do
            local step = 1 / fps / Sailing.DeployTime
            deployed += math.clamp(desired - deployed, -step, step)
            assert(deployed >= 0 and deployed <= 1, "Sail transition overshoots")
        end
        assert(math.abs(deployed - desired) < 0.0001, "Sail does not finish transition")
    end
end
local stage = 0
for _, expected in ipairs({1, 2, 3, 3}) do
    stage = Sailing.stepStage(stage, 1)
    assert(stage == expected, "Each increase must advance exactly one stage and clamp at full sails")
end
for _, expected in ipairs({2, 1, 0, -1, -1}) do
    stage = Sailing.stepStage(stage, -1)
    assert(stage == expected, "Each decrease must reduce exactly one stage and clamp at reverse")
end
for _, invalid in ipairs({0, 2, -2, "1", false, 0 / 0, math.huge}) do
    assert(Sailing.stepStage(0, invalid) == nil, "Invalid stage-step direction accepted")
end
assert(Sailing.stepStage(99, 1) == nil)
assert(Sailing.stageSpeedMultiplier(0, 1, 1) == 0, "Stop must brake even while sails are stowing")
assert(Sailing.stageSpeedMultiplier(-1, 1, 1) < 0, "Reverse stage must target backward motion")
assert(Sailing.stageSpeedMultiplier(1, 1, 1) == paddle, "Downshifting to paddles must lower speed before sails finish stowing")
assert(Sailing.stageSpeedMultiplier(2, 1, 1) == half, "Half-sail speed must clamp while downshifting")
assert(Sailing.stageSpeedMultiplier(3, 1, 1) == full)
assert(Sailing.stageSpeedMultiplier(1, 0, 1) == paddle, "Paddles must cruise without a held throttle key")
for _, wind in ipairs({-1, 0, 1}) do
    for _, deployment in ipairs({0, 0.01, 0.5, 1}) do
        local previous = 0
        for selected = 1, 3 do
            local multiplier = Sailing.stageSpeedMultiplier(selected, deployment, wind)
            assert(multiplier >= previous, "Increasing a speed stage must not slow the ship while sails deploy")
            previous = multiplier
        end
    end
end
print("PASS: tap-based speed stages, clamping, stop/reverse, wind and deployment transitions")
