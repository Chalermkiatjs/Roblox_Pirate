local Frigate = {
    Enabled = true,
    TemplateName = "ReferenceFrigate",
    ImportName = "reference_frigate_roblox",
    -- Reuse the reference art without changing any tier's gameplay stats.
    Tiers = {Raft = true, Sloop = true, Brigantine = true},
    ArtScale = 3,
    Length = 55.817974,
    BoundsCenter = {0, 18.451827, -5.114405},
    VisualOffset = {0, -2, 0},
    HullSize = {7.2, 4, 30},
    WheelPosition = {0, 9.65, 14.2},
    HelmFloorY = 8.97873,
    LegacyWheelPosition = {0, 9.65, 14.95},
    LegacyHelmFloorY = 9.05,
    HelmBehindWheel = 2,
    BerthSpacing = 70,
    BerthOffset = {0, 0, -70},
    ColliderThickness = 0.3,
    RudderMaxAngle = math.rad(30),
    FurledScale = 0.08,
    SignHeight = 38,
    InteriorRevision = 2,
    Hatch = {x = 0, z0 = 2.4, z1 = 8.6, width = 2.8},
    GunDeck = {z0 = -16, z1 = 12, floorY = 4.18, ceilingY = 6.2},
}

local stations = {{-21, 0.13}, {-20, 0.85}, {-18, 2.65}, {-16, 3.9}, {-12, 5},
    {-6, 5.55}, {0, 5.65}, {6, 5.55}, {12, 5.15}, {16, 4.7}, {20, 4}}

local function halfWidth(z)
    for i = 1, #stations - 1 do
        local a, b = stations[i], stations[i + 1]
        if z <= b[1] then
            local alpha = math.clamp((z - a[1]) / (b[1] - a[1]), 0, 1)
            return a[2] + (b[2] - a[2]) * alpha
        end
    end
    return stations[#stations][2]
end

local function deckY(z)
    return 6.35 + 0.55 * (math.abs(z) / 21)^4 + math.max(0, z - 12) * 0.035
end

function Frigate.deckPanels(interior)
    if interior == nil then interior = true end
    local panels = {}
    local z = -19
    while z < 21.3 do
        local finish = math.min(z + 2, 21.3)
        local hatch = Frigate.Hatch
        if interior and z < hatch.z0 and finish > hatch.z0 then finish = hatch.z0 end
        if interior and z < hatch.z1 and finish > hatch.z1 then finish = hatch.z1 end
        local width = 2 * math.min(halfWidth(z), halfWidth(finish)) * 0.98 - 0.2
        local function append(x, breadth, side)
            table.insert(panels, {name = #panels == 0 and "Deck" or "DeckSegment" .. #panels,
                z0 = z, z1 = finish, y0 = deckY(z), y1 = deckY(finish), x = x,
                width = breadth, rails = finish <= 13, outerRailSide = side,
                -- Do not extend a ceiling collider into the companionway opening.
                overlap = interior and (z == hatch.z0 or finish == hatch.z0
                    or z == hatch.z1 or finish == hatch.z1) and 0 or 0.15})
        end
        if interior and z >= hatch.z0 and finish <= hatch.z1 then
            local sideWidth = (width - hatch.width) / 2
            for _, side in ipairs({-1, 1}) do
                append(hatch.x + side * (hatch.width / 2 + sideWidth / 2), sideWidth, side)
            end
        else
            append(0, width, nil)
        end
        z = finish
    end
    table.insert(panels, {name = "Quarterdeck", x = 0, z0 = 12.95, z1 = 20.95,
        y0 = 8.97, y1 = 9.19, width = 7.6, aftRail = true})
    table.insert(panels, {name = "PoopDeck", x = 0, z0 = 15.9, z1 = 21.55,
        y0 = 10.5, y1 = 10.72, width = 6.8, aftRail = true})
    return panels
end

function Frigate.interiorPanels()
    local panels = {}
    local gun = Frigate.GunDeck
    for z = gun.z0, gun.z1 - 2, 2 do
        local finish = math.min(z + 2, gun.z1)
        table.insert(panels, {name = #panels == 0 and "GunDeckFloor" or "GunDeckFloor" .. #panels,
            x = 0, z0 = z, z1 = finish, y0 = gun.floorY + deckY(z) - 6.35,
            y1 = gun.floorY + deckY(finish) - 6.35,
            width = 2 * math.min(halfWidth(z), halfWidth(finish)) * 0.98 - 0.4})
    end
    table.insert(panels, {name = "CompanionwayAccess", x = Frigate.Hatch.x,
        z0 = 3, z1 = Frigate.Hatch.z1, y0 = gun.floorY + deckY(3) - 6.35,
        y1 = deckY(Frigate.Hatch.z1), width = 1.8})
    return panels
end

function Frigate.interiorBoxes()
    local boxes = {}
    local function add(name, x, y, z, sx, sy, sz)
        table.insert(boxes, {name = name, position = {x, y, z}, size = {sx, sy, sz}})
    end
    local gun, hatch = Frigate.GunDeck, Frigate.Hatch
    for z = gun.z0, gun.z1 - 2, 2 do
        local mid = z + 1
        local half = math.min(halfWidth(z), halfWidth(z + 2)) * 0.98 - 0.14
        for _, side in ipairs({-1, 1}) do
            add("GunDeckSideWall", side * half, 5.22 + deckY(mid) - 6.35, mid, 0.16, 2.08, 2.08)
        end
    end
    for _, z in ipairs({gun.z0, gun.z1}) do
        add("GunDeckBulkhead", 0, 5.22 + deckY(z) - 6.35, z, halfWidth(z) * 1.96 - 0.32, 2.08, 0.12)
    end
    for _, side in ipairs({-1, 1}) do
        add("HatchGuard", hatch.x + side * (hatch.width / 2 + 0.055), 6.76,
            (hatch.z0 + hatch.z1) / 2, 0.11, 0.8, hatch.z1 - hatch.z0)
        for _, z in ipairs({-5, 9}) do
            add("CargoCollision", side * 3.1, gun.floorY + deckY(z) - 6.35 + 0.43, z, 0.99, 0.86, 1.44)
        end
        add("BerthCollision", side * 2.4, 4.68, -12.1, 0.9, 0.66, 2.1)
    end
    add("HatchForwardGuard", hatch.x, 6.76, hatch.z0 - 0.05, hatch.width + 0.22, 0.8, 0.1)
    local stairY0 = gun.floorY + deckY(3) - 6.35
    local rise = deckY(hatch.z1) - stairY0
    for i = 1, 14 do
        local run = (hatch.z1 - 3) / 14
        add("CompanionwayStep" .. i, hatch.x, stairY0 + rise * i / 14 - 0.055,
            3 + run * (i - 0.5), 1.8, 0.11, run + 0.002)
    end
    for _, z in ipairs({-10.3, 1, 11.3}) do
        add("MastFootCollision", 0, 5.27 + deckY(z) - 6.35, z, 0.56, 2.18, 0.56)
    end
    return boxes
end

function Frigate.interiorLights()
    local positions = {}
    for _, z in ipairs({-12, -4, 10}) do
        for _, side in ipairs({-1, 1}) do
            table.insert(positions, {side * 2.9, 5.8 + deckY(z) - 6.35, z})
        end
    end
    return positions
end

Frigate.Ramps = {
    {name = "QuarterdeckAccess", x = 0, z0 = 10, z1 = 13.1, y0 = 6.45, y1 = 8.97, width = 3.6},
    {name = "PoopDeckAccess", x = -1.8, z0 = 14, z1 = 16.1, y0 = 9, y1 = 10.53, width = 2.1},
}

function Frigate.accessStepBoxes()
    local boxes = {}
    for index, ramp in ipairs(Frigate.Ramps) do
        local count = index == 1 and 14 or 9
        for i = 1, count do
            local run = (ramp.z1 - ramp.z0) / count
            table.insert(boxes, {name = ramp.name .. "Step" .. i,
                position = {ramp.x, ramp.y0 + (ramp.y1 - ramp.y0) * i / count - 0.055,
                    ramp.z0 + run * (i - 0.5)}, size = {ramp.width, 0.11, run + 0.002}})
        end
    end
    return boxes
end

function Frigate.importYaw(bowX, bowZ, sternX, sternZ)
    return math.atan2(sternX - bowX, sternZ - bowZ)
end

function Frigate.movingRole(name)
    if name:match("^Frigate_%a+mast_Sail_%d")
        or name:match("^Frigate_Flying_Jib")
        or name:match("^Frigate_Inner_Jib")
        or name:match("^Frigate_Mizzen_Gaff_Sail") then
        return "SailMesh"
    end
    if name == "Frigate_Rudder_Blade" or name == "Frigate_Rudder_Stock"
        or name == "Frigate_Rudder_Gudgeons_And_Straps" then
        return "Rudder"
    end
    return nil
end

function Frigate.sailPose(fullHeight, deployment)
    local fraction = Frigate.FurledScale + (1 - Frigate.FurledScale) * math.clamp(deployment, 0, 1)
    local height = fullHeight * fraction
    return height, (fullHeight - height) / 2
end

function Frigate.rudderAngle(steer)
    return math.clamp(steer, -1, 1) * Frigate.RudderMaxAngle
end

return Frigate
