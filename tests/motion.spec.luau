local Motion = require("../src/shared/Util/BoatMotion")

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
    for _, speed in ipairs({18, 26, 32}) do
        local x, z = simulate(0, 0, 0, -speed, fps, 12)
        assert(math.abs(x) < 0.001 and math.abs(z + speed) < 0.02, "Cannot reach configured ship speed")
        assert(z >= -speed, "Acceleration overshoots target speed")
        x, z = simulate(10, -speed, 0, 0, fps, 12)
        assert(math.abs(x) < 0.02 and math.abs(z) < 0.02, "Ship drifts without input")
        x, z = simulate(0, -speed, 0, speed, fps, 16)
        assert(math.abs(z - speed) < 0.02, "Reverse does not brake and change direction")
    end
end
print("PASS: propulsion cap, forward/reverse, idle drag and 30/60/120 Hz stability")
