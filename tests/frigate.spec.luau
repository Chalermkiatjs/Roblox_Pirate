local Config = require("../src/shared/FrigateConfig")

assert(Config.Enabled and Config.Tiers.Raft and Config.Tiers.Sloop and Config.Tiers.Brigantine)
for _, name in ipairs({
    "Frigate_Foremast_Sail_1", "Frigate_Mainmast_Sail_3_Boltropes_And_Seams",
    "Frigate_Mizzenmast_Sail_2", "Frigate_Flying_Jib", "Frigate_Inner_Jib",
    "Frigate_Mizzen_Gaff_Sail_Boltropes_And_Seams",
}) do
    assert(Config.movingRole(name) == "SailMesh", name)
end
for _, name in ipairs({"Frigate_Rudder_Blade", "Frigate_Rudder_Stock", "Frigate_Rudder_Gudgeons_And_Straps"}) do
    assert(Config.movingRole(name) == "Rudder", name)
end
for _, name in ipairs({"Frigate_Mainmast_Pennant", "Frigate_Mainmast_Spars_And_Tops",
    "Frigate_Foremast_Shrouds_Ratlines_And_Running_Rig", "Frigate_Sternpost_And_Deadwood", "Sail"}) do
    assert(Config.movingRole(name) == nil, "Static component animated: " .. name)
end
for _, height in ipairs({0.8, 4, 12.8, 20}) do
    local previous = 0
    for step = 0, 100 do
        local current, lift = Config.sailPose(height, step / 100)
        assert(current >= previous and current > 0 and current <= height)
        assert(math.abs(lift + current / 2 - height / 2) < 0.00001, "Sail top moves away from yard")
        previous = current
    end
    local full, lift = Config.sailPose(height, 1)
    assert(full == height and lift == 0, "Full sail shape changed")
    local furled = Config.sailPose(height, 0)
    assert(math.abs(furled - height * Config.FurledScale) < 0.00001)
    assert(Config.sailPose(height, -5) == furled and Config.sailPose(height, 5) == full)
end
assert(Config.rudderAngle(0) == 0)
assert(Config.rudderAngle(1) == -Config.rudderAngle(-1))
assert(Config.rudderAngle(5) == Config.RudderMaxAngle)
assert(Config.rudderAngle(-5) == -Config.RudderMaxAngle)
assert(Config.ArtScale == 3 and Config.Length * Config.ArtScale > 150, "Frigate is still character-sized")
assert(Config.BerthSpacing > 14.11 * Config.ArtScale, "Neighbouring yards overlap at berth")
assert(-85 + Config.BerthOffset[3] + 22.795 * Config.ArtScale < -80, "Stern overlaps the dock")
for _, direction in ipairs({{0, -1}, {0, 1}, {1, 0}, {-1, 0}, {1, 1}, {-2, 3}}) do
    local x, z = direction[1], direction[2]
    local yaw = Config.importYaw(x, z, 0, 0)
    local rotatedX = math.cos(yaw) * x - math.sin(yaw) * z
    local rotatedZ = math.sin(yaw) * x + math.cos(yaw) * z
    assert(math.abs(rotatedX) < 0.00001 and rotatedZ < 0, "Imported bow was not aligned to -Z")
end
local panels = Config.deckPanels()
local covered = -19
local quarterdeck, poopdeck
for _, p in ipairs(panels) do
    assert(p.width > 0 and p.z1 > p.z0 and p.y1 >= p.y0 - 1, "Invalid deck collider")
    if p.name == "Quarterdeck" then quarterdeck = p
    elseif p.name == "PoopDeck" then poopdeck = p
    else
        assert(p.z0 <= covered + 0.00001, "Gap in main/stern floor")
        covered = p.z1
    end
end
assert(covered >= 21.3 and quarterdeck.z1 >= 20.9 and poopdeck.z1 >= 21.55, "Stern still has missing floors")
local seatSourceZ = Config.WheelPosition[3] + Config.HelmBehindWheel / Config.ArtScale
assert(seatSourceZ > Config.WheelPosition[3] and seatSourceZ < poopdeck.z0, "Helm is not behind wheel on the quarterdeck")
assert(seatSourceZ > quarterdeck.z0 and seatSourceZ < quarterdeck.z1)
assert(seatSourceZ + 1.1 / Config.ArtScale < 15.8, "Helm intersects the upper cabin front")
local floor = 8.93 + 0.22 * (seatSourceZ - 13.15) / (20.9 - 13.15)
assert(math.abs(floor - Config.HelmFloorY) * Config.ArtScale < 0.1, "Helm is floating above its deck")
assert(#Config.Ramps == 2, "Missing access to a stern deck")
local function mainFloorAt(x, z, specs)
    for _, p in ipairs(specs) do
        if p.name ~= "Quarterdeck" and p.name ~= "PoopDeck" and z >= p.z0 and z <= p.z1
            and math.abs(x - p.x) <= p.width / 2 then return p end
    end
    return nil
end
for z = -18.5, 20.5, 0.25 do
    local hatch = z > Config.Hatch.z0 and z < Config.Hatch.z1
    assert((mainFloorAt(0, z, panels) == nil) == hatch, "Unintended hole or blocked hatch at " .. z)
    if hatch then
        for _, x in ipairs({-2, 2}) do
            assert(mainFloorAt(x, z, panels), "Missing walkway beside hatch")
        end
    end
    assert(mainFloorAt(0, z, Config.deckPanels(false)), "Old import acquired an invisible hole")
end
for _, p in ipairs(panels) do
    if p.outerRailSide then
        assert(p.outerRailSide * p.x > 0, "Outer rail placed on the wrong side")
        assert(math.abs(p.x) - p.width / 2 >= Config.Hatch.width / 2 - 0.00001, "Floor fills hatch")
    end
end
local interior = Config.interiorPanels()
local ramp = interior[#interior]
assert(ramp.name == "CompanionwayAccess" and ramp.width * Config.ArtScale >= 5)
assert(ramp.z0 > Config.Hatch.z0 and ramp.z1 == Config.Hatch.z1)
assert((ramp.y1 - ramp.y0) / (ramp.z1 - ramp.z0) < 0.5, "Stairs too steep")
local lowerEnd = Config.GunDeck.z0
for i = 1, #interior - 1 do
    local p = interior[i]
    assert(p.z0 <= lowerEnd and p.y0 > Config.HullSize[2] / 2 - Config.VisualOffset[2], "Interior collides with buoyancy hull")
    assert(p.width > 6 and p.z1 > p.z0)
    lowerEnd = p.z1
end
assert(lowerEnd == Config.GunDeck.z1, "Gun-deck floor ends early")
assert((Config.GunDeck.ceilingY - 0.12 - Config.GunDeck.floorY) * Config.ArtScale >= 5.6,
    "Insufficient avatar headroom below beams")
local steps, previousTop = 0, ramp.y0
for _, box in ipairs(Config.interiorBoxes()) do
    if box.name:match("^CompanionwayStep") then
        local top = box.position[2] + box.size[2] / 2
        assert(top > previousTop and (top - previousTop) * Config.ArtScale <= 0.6, "Unwalkable stair rise")
        previousTop, steps = top, steps + 1
    end
    assert(box.size[1] > 0 and box.size[2] > 0 and box.size[3] > 0)
end
assert(steps == 14 and math.abs(previousTop - ramp.y1) < 0.00001, "Stairs do not reach main deck")
assert(#Config.interiorLights() == 6, "Missing interior lighting")
local accessSteps = Config.accessStepBoxes()
assert(#accessSteps == 23, "Missing visible stern-deck step collision")
for _, box in ipairs(accessSteps) do
    assert(box.size[1] >= 2.1 and box.size[2] > 0 and box.size[3] > 0)
end
print("PASS: frigate helm, sealed-floor layout, open companionway, headroom, interior collision, sails and rudder")
