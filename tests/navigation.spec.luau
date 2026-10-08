local Navigation = require("../src/shared/Util/WorldNavigation")
local bounds = Navigation.bounds(0, -700, 2200, 2400, 100)
local function speed(x, z, fx, fz, target)
    return Navigation.limitSpeed(x, z, fx, fz, target, bounds, 14, 1.2)
end

assert(Navigation.contains(0, -800, bounds), "Deep sea must not act as an invisible tier wall")
assert(speed(0, -380, 0, -1, 18) == 18, "Starter ship must cross the old depth boundary")
assert(speed(0, -1500, 0, -1, 32) == 32, "Old fixed map edge must not stop the ship")
assert(speed(400, -72, 0, 1, 18) == 18, "Open water beside the harbor must remain navigable")
assert(not Navigation.contains(0, -1900, bounds), "Recovery must still protect the water edge")

assert(speed(bounds.maxX, -700, 1, 0, 32) == 0, "Outward propulsion must stop at the edge")
assert(speed(bounds.maxX, -700, -1, 0, 32) == 32, "Ship must be able to sail back inward")
assert(speed(bounds.maxX, -700, 1, 0, -9) == -9, "Reverse must work at an outward-facing boundary")
assert(speed(bounds.maxX, -700, 0, -1, 32) == 32, "Tangential travel must remain available")
assert(speed(0, bounds.minZ, 0, -1, 32) == 0)
assert(speed(0, bounds.minZ, 0, 1, 32) == 32)
local slow = speed(0, bounds.minZ + 10, 0, -1, 32)
assert(slow > 0 and slow < speed(0, bounds.minZ + 30, 0, -1, 32), "Edge braking must be gradual")
assert(slow * 1.2 + slow * slow / (2 * 14) <= 10.00001, "Braking envelope exceeds remaining water")
assert(speed(0, -700, 0, 0, 0) == 0)

for _, fps in ipairs({30, 60, 120}) do
    local z, velocity = bounds.minZ + 150, -32
    for _ = 1, fps * 25 do
        local target = -speed(0, z, 0, -1, 32)
        local acceleration = math.clamp((target - velocity) / 1.2, -14, 14)
        velocity += acceleration / fps
        z += velocity / fps
        assert(z >= bounds.minZ - 0.01, "Ship crossed the water boundary during braking")
    end
    assert(math.abs(velocity) < 0.1, "Ship must settle near the water edge")
end
print("PASS: unrestricted depth traversal, water bounds, directional escape and gradual edge braking")
