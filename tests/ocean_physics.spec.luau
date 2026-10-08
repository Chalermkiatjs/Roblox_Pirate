local OceanPhysics = require("../src/shared/OceanPhysics")

local function near(a, b, epsilon)
    return math.abs(a - b) <= (epsilon or 0.0001)
end

local h0, n0 = OceanPhysics.heightAt(Vector3.new(0, 0, 0), 0, 1)
local h1 = OceanPhysics.heightAt(Vector3.new(35, 0, 18), 3.5, 1)
assert(type(h0) == "number", "heightAt must return a number")
assert(n0.Magnitude > 0.99 and n0.Magnitude < 1.01, "water normal must be normalized")
assert(not near(h0, h1, 0.001), "wave field must vary across position and time")

assert(near(OceanPhysics.depthMultiplier(99), 1), "deep water should keep full handling")
assert(OceanPhysics.depthMultiplier(1) < OceanPhysics.depthMultiplier(5), "shallow water should reduce handling")
assert(OceanPhysics.dragMultiplier(1) > OceanPhysics.dragMultiplier(99), "shallow water should add drag")

local probes = OceanPhysics.probePoints(Vector3.new(12, 4, 28))
assert(#probes >= 6, "boats need multiple buoyancy probes")
assert(probes[1].Y < 0, "probes should sit under the hull")

local floating = OceanPhysics.buoyancyAt(CFrame.new(0, -1, 0), Vector3.new(12, 4, 28), 0, {
    depth = 20,
    mass = 100,
    velocity = Vector3.zero,
})
assert(floating.submerged > 0, "lowered hull should become submerged")
assert(floating.force.Y > 0, "submerged hull needs upward buoyancy")
assert(floating.dragMultiplier == OceanPhysics.dragMultiplier(20), "drag multiplier should be reported")

local dry = OceanPhysics.buoyancyAt(CFrame.new(0, 30, 0), Vector3.new(12, 4, 28), 0, {
    depth = 20,
    mass = 100,
})
assert(dry.submerged == 0, "high hull should not be submerged")
assert(dry.force.Magnitude == 0, "dry hull should not receive water force")

assert(OceanPhysics.wakeIntensity(0, 0, 0) == 0, "stationary dry hull should have no wake")
assert(OceanPhysics.wakeIntensity(60, 1, 1) == 1, "fast boat wake should clamp at full intensity")

print("ocean_physics.spec passed")
