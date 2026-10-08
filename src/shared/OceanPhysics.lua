local OceanPhysics = {}

OceanPhysics.SeaLevel = 0
OceanPhysics.Gravity = 196.2
OceanPhysics.WaterDensity = 1

OceanPhysics.Waves = {
    {amplitude = 1.9, wavelength = 86, speed = 8.5, direction = Vector2.new(1, 0.18).Unit, steepness = 0.42},
    {amplitude = 0.95, wavelength = 38, speed = 12.4, direction = Vector2.new(0.32, 1).Unit, steepness = 0.28},
    {amplitude = 0.34, wavelength = 12, speed = 18.0, direction = Vector2.new(-0.55, 1).Unit, steepness = 0.16},
}

OceanPhysics.ProbeLayout = {
    Vector3.new(-0.45, 0, -0.42),
    Vector3.new(0.45, 0, -0.42),
    Vector3.new(-0.45, 0, 0.42),
    Vector3.new(0.45, 0, 0.42),
    Vector3.new(0, 0, -0.5),
    Vector3.new(0, 0, 0.5),
}

OceanPhysics.Depth = {
    ShallowStart = 7,
    GroundingDepth = 2.5,
    ShallowDrag = 1.85,
}

local TAU = math.pi * 2

local function sanitizeTime(time)
    if type(time) ~= "number" or time ~= time then return 0 end
    return time
end

local function sampleWave(wave, x, z, time)
    local direction = wave.direction
    local k = TAU / wave.wavelength
    local phase = k * (direction.X * x + direction.Y * z) + wave.speed * k * time
    local s, c = math.sin(phase), math.cos(phase)
    local height = wave.amplitude * s
    local slopeX = wave.amplitude * k * direction.X * c
    local slopeZ = wave.amplitude * k * direction.Y * c
    local chop = wave.steepness * wave.amplitude * c
    return height, slopeX, slopeZ, Vector3.new(direction.X * chop, 0, direction.Y * chop)
end

function OceanPhysics.heightAt(position, time, windStrength)
    time = sanitizeTime(time)
    windStrength = math.clamp(windStrength or 1, 0.25, 2.25)
    local x = position.X
    local z = position.Z
    local height = OceanPhysics.SeaLevel
    local slopeX, slopeZ = 0, 0
    local displacement = Vector3.zero

    for _, wave in ipairs(OceanPhysics.Waves) do
        local h, sx, sz, chop = sampleWave(wave, x, z, time)
        height += h * windStrength
        slopeX += sx * windStrength
        slopeZ += sz * windStrength
        displacement += chop * windStrength
    end

    return height, Vector3.new(-slopeX, 1, -slopeZ).Unit, displacement
end

function OceanPhysics.depthMultiplier(depth)
    if type(depth) ~= "number" then return 1 end
    if depth <= OceanPhysics.Depth.GroundingDepth then return 0.25 end
    if depth >= OceanPhysics.Depth.ShallowStart then return 1 end
    return math.clamp((depth - OceanPhysics.Depth.GroundingDepth)
        / (OceanPhysics.Depth.ShallowStart - OceanPhysics.Depth.GroundingDepth), 0.25, 1)
end

function OceanPhysics.dragMultiplier(depth)
    local depthFactor = OceanPhysics.depthMultiplier(depth)
    return 1 + (1 - depthFactor) * OceanPhysics.Depth.ShallowDrag
end

function OceanPhysics.probePoints(size)
    local half = Vector3.new(size.X * 0.5, size.Y * 0.5, size.Z * 0.5)
    local points = {}
    for _, unit in ipairs(OceanPhysics.ProbeLayout) do
        table.insert(points, Vector3.new(unit.X * half.X, -half.Y, unit.Z * half.Z))
    end
    return points
end

function OceanPhysics.buoyancyAt(cframe, size, time, options)
    options = options or {}
    local probes = options.probes or OceanPhysics.probePoints(size)
    local depth = options.depth
    local windStrength = options.windStrength or 1
    local mass = math.max(options.mass or 1, 1)
    local spring = options.spring or 24
    local damping = options.damping or 5.5
    local velocity = options.velocity or Vector3.zero
    local submerged = 0
    local totalForce = Vector3.zero
    local totalTorque = Vector3.zero
    local normal = Vector3.zero

    for _, localPoint in ipairs(probes) do
        local worldPoint = cframe:PointToWorldSpace(localPoint)
        local waterHeight, waterNormal = OceanPhysics.heightAt(worldPoint, time, windStrength)
        local immersion = waterHeight - worldPoint.Y
        if immersion > 0 then
            local clamped = math.clamp(immersion / math.max(size.Y * 0.45, 1), 0, 1)
            submerged += clamped
            normal += waterNormal
            local upward = waterNormal * (mass * OceanPhysics.Gravity * spring * clamped / #probes)
            local dampingForce = -velocity * damping * clamped * OceanPhysics.dragMultiplier(depth)
            local force = upward + dampingForce
            totalForce += force
            totalTorque += (worldPoint - cframe.Position):Cross(force)
        end
    end

    local ratio = math.clamp(submerged / #probes, 0, 1)
    if normal.Magnitude < 0.001 then normal = Vector3.yAxis else normal = normal.Unit end
    return {
        force = totalForce,
        torque = totalTorque,
        normal = normal,
        submerged = ratio,
        dragMultiplier = OceanPhysics.dragMultiplier(depth),
        depthMultiplier = OceanPhysics.depthMultiplier(depth),
    }
end

function OceanPhysics.wakeIntensity(speed, submerged, throttle)
    speed = math.max(speed or 0, 0)
    submerged = math.clamp(submerged or 0, 0, 1)
    throttle = math.abs(math.clamp(throttle or 0, -1, 1))
    return math.clamp((speed / 38) * 0.65 + throttle * 0.25 + submerged * 0.1, 0, 1)
end

return OceanPhysics
