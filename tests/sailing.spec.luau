local Sailing = require("../src/shared/SailingConfig")
assert(Sailing.validStage(0) and Sailing.validStage(1) and Sailing.validStage(2))
for _, value in ipairs({-1, 3, 0.5, "2", math.huge, 0 / 0}) do
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
for _, fps in ipairs({30, 60, 120}) do
    local deployed = 0
    for _, stage in ipairs({1, 2, 0}) do
        local desired = Sailing.Stages[stage].deployment
        for _ = 1, fps * 2 do
            local step = 1 / fps / Sailing.DeployTime
            deployed += math.clamp(desired - deployed, -step, step)
            assert(deployed >= 0 and deployed <= 1, "Sail transition overshoots")
        end
        assert(math.abs(deployed - desired) < 0.0001, "Sail does not finish transition")
    end
end
print("PASS: stage validation, speed progression, braking, wind and deployment transitions")
