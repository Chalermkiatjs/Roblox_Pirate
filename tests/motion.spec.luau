local Motion = require("../src/shared/Util/BoatMotion")
local Ships = require("../src/shared/ShipConfig")

local function simulate(initialX, initialZ, targetX, targetZ, fps, seconds)
    local vx, vz = initialX, initialZ
    for _ = 1, fps * seconds do
        local ax, az = Motion.acceleration(vx, vz, targetX, targetZ, 1.2, 14)
        assert(math.sqrt(ax * ax + az * az) <= 14.00001, "Unbounded propulsion force")
        vx, vz = vx + ax / fps, vz + az / fps
    end
    return vx, vz
end

for _, fps in ipairs({30, 60, 120}) do
    for _, tier in ipairs(Ships.UpgradeOrder) do
        local speed = Ships.Tiers[tier].speed
        local x, z = simulate(0, 0, 0, -speed, fps, 12)
        assert(math.abs(x) < 0.001 and math.abs(z + speed) < 0.02, "Cannot reach configured ship speed")
        assert(z >= -speed, "Acceleration overshoots target speed")
        x, z = simulate(10, -speed, 0, 0, fps, 12)
        assert(math.abs(x) < 0.02 and math.abs(z) < 0.02, "Ship drifts without input")
        x, z = simulate(0, -speed, 0, speed, fps, 16)
        assert(math.abs(z - speed) < 0.02, "Reverse does not brake and change direction")
    end
end
local handling = {
    RudderAngle = math.rad(32), TurnResponse = 0.8, TurnGain = 2,
    MaxTurnRate = math.rad(18), MaxTurnAcceleration = math.rad(12),
}
local function turning(speed, length, steer)
    return Motion.turning(speed, 0, steer, length / 3, length, length * 0.432, handling)
end
assert(turning(0, 24, 1) == 0, "Stationary rudder must not rotate the ship")
assert(turning(18, 24, 1) < 0 and turning(-18, 24, 1) > 0, "Reverse must reverse rudder authority")
assert(math.abs(turning(1, 24, 1)) < math.abs(turning(18, 24, 1)), "Slow ships turn less strongly")
local function angularDrive(speed, length)
    return turning(speed, length, 1) * length * 0.432 / ((length * length + (length / 3)^2) / 12)
end
assert(math.abs(angularDrive(18, 96)) < math.abs(angularDrive(18, 24)), "Long hulls need more time to turn")

local reference
for _, fps in ipairs({30, 60, 120}) do
    local rudder, yawRate, yaw, sideSpeed = 0, 0, 0, 0
    local length, width, lever, dragOffset = 48, 16, 48 * 0.432, -48 * 0.03
    local inertia = (length * length + width * width) / 12
    for step = 1, fps * 20 do
        local steer = step <= fps * 8 and 1 or 0
        rudder = Motion.rudder(rudder, steer, 1 / fps, 0.25)
        local sideForce, damping = Motion.turning(26, yawRate, rudder, width, length, lever, handling)
        local drag = -(sideSpeed + yawRate * dragOffset) / 2.4
        -- Body-frame lateral velocity includes the hull rotating through forward motion.
        sideSpeed += (sideForce + drag - yawRate * 26) / fps
        yawRate += (sideForce * lever + damping + drag * dragOffset) / inertia / fps
        yaw += yawRate / fps
        assert(math.abs(yawRate) < handling.MaxTurnRate, "Turn rate must remain bounded")
        if step == 1 then assert(math.abs(yawRate) < 0.005, "Steering must not snap to full turn rate") end
    end
    assert(yaw < -0.1, "Rudder must produce a right turn")
    assert(math.abs(yawRate) < 0.01, "Turn must decay after centering the rudder")
    if reference then assert(math.abs(yaw - reference) < 0.02, "Turning depends too much on frame rate") end
    reference = yaw
    local immediate = Motion.rudder(1, -1, 1 / fps, 0.25)
    assert(immediate > 0, "Reversing helm must not instantly flip rudder")
end

-- The 3x frigate has a 90-stud physics hull and paddles at roughly 5 studs/s.
for _, fps in ipairs({30, 60, 120}) do
    local rudder, yawRate, yaw, sideSpeed = 0, 0, 0, 0
    local length, width, speed = 90, 21.6, 5
    local inertia = (length * length + width * width) / 12
    local lever, dragOffset = length * 0.432, -length * 0.03
    for step = 1, fps * 8 do
        rudder = Motion.rudder(rudder, 1, 1 / fps, 0.25)
        local force, damping = Motion.turning(speed, yawRate, rudder, width, length, lever, handling)
        local drag = -(sideSpeed + yawRate * dragOffset) / 2.4
        sideSpeed += (force + drag - yawRate * speed) / fps
        yawRate += (force * lever + damping + drag * dragOffset) / inertia / fps
        yaw += yawRate / fps
        if step == fps * 3 then
            assert(yaw < -math.rad(8), "Large frigate must begin turning promptly at paddle speed")
        end
    end
    assert(yaw < -math.rad(35), "Large frigate must remain maneuverable at paddle speed")
end
print("PASS: propulsion, speed-dependent stern steering, reverse, inertia and 30/60/120 Hz stability")
