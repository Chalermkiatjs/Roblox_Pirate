local Motion = require("../src/shared/Util/AnchorMotion")
local function near(actual, expected)
    assert(math.abs(actual - expected) < 1e-6, tostring(actual) .. " ~= " .. tostring(expected))
end
local function point(angle)
    return {x = 3 * math.cos(angle), z = 3 * math.sin(angle)}
end
local total, previous = 0, point(0)
for i = 1, 240 do
    local nextPoint = point(i * math.pi / 60)
    total += Motion.step(previous, nextPoint.x, nextPoint.z, 1 / 30, 24)
    previous = nextPoint
end
near(total, 4 * math.pi)
local back = point(4 * math.pi - math.pi / 60)
near(Motion.step(previous, back.x, back.z, 1 / 30, 24), -math.pi / 60)
near(Motion.step(nil, 3, 0, 1 / 30, 24), 0)
near(Motion.step(point(0), -3, 0, 1 / 60, 24), 0)
near(Motion.step(point(0), 3, 0, 0, 24), 0)
local a, b = point(math.pi - 0.02), point(-math.pi + 0.02)
near(Motion.step(a, b.x, b.z, 1 / 30, 24), 0.04)
near(Motion.step(b, a.x, a.z, 1 / 30, 24), -0.04)
print("PASS: anchor turns, wraparound, reverse movement, initialization and teleport rejection")
