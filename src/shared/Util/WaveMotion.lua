local Wave = {}
local TAU = 2 * math.pi

function Wave.sample(x, z, time, swells)
    local height, velocity = 0, 0
    for _, swell in ipairs(swells) do
        local frequency = TAU / swell.period
        local phase = (x * swell.x + z * swell.z) * TAU / swell.wavelength - time * frequency
        height += swell.amplitude * math.sin(phase)
        velocity -= swell.amplitude * frequency * math.cos(phase)
    end
    return height, velocity
end

function Wave.surfaceTilt(x, z, time, yaw, width, length, steer, speed, swells, limits)
    local fx, fz = -math.sin(yaw), -math.cos(yaw)
    local rx, rz = math.cos(yaw), -math.sin(yaw)
    local along, across = math.max(2, length * 0.6), math.max(2, width * 0.9)
    local front = Wave.sample(x + fx * along / 2, z + fz * along / 2, time, swells)
    local rear = Wave.sample(x - fx * along / 2, z - fz * along / 2, time, swells)
    local right = Wave.sample(x + rx * across / 2, z + rz * across / 2, time, swells)
    local left = Wave.sample(x - rx * across / 2, z - rz * across / 2, time, swells)
    local pitch = math.atan2(front - rear, along)
    local roll = math.atan2(right - left, across)
    roll -= math.clamp(steer, -1, 1) * limits.steeringBank * math.clamp(speed / 18, 0, 1)
    return math.clamp(pitch, -limits.maxPitch, limits.maxPitch), math.clamp(roll, -limits.maxRoll, limits.maxRoll)
end

function Wave.rocking(state, dt, x, z, time, yaw, width, length, steer, speed, swells, limits)
    local fx, fz = -math.sin(yaw), -math.cos(yaw)
    local rx, rz = math.cos(yaw), -math.sin(yaw)
    local along, across = math.max(2, length * 0.6), math.max(2, width * 0.9)
    local front, frontVelocity = Wave.sample(x + fx * along / 2, z + fz * along / 2, time, swells)
    local rear, rearVelocity = Wave.sample(x - fx * along / 2, z - fz * along / 2, time, swells)
    local right, rightVelocity = Wave.sample(x + rx * across / 2, z + rz * across / 2, time, swells)
    local left, leftVelocity = Wave.sample(x - rx * across / 2, z - rz * across / 2, time, swells)
    local targetPitch = math.atan2(front - rear, along)
    local targetRoll = math.atan2(right - left, across)
    targetRoll -= math.clamp(steer, -1, 1) * limits.steeringBank * math.clamp(speed / 18, 0, 1)
    local pitchImpulse = math.atan2(frontVelocity - rearVelocity, along)
    local rollImpulse = math.atan2(rightVelocity - leftVelocity, across)
    local spring = limits.spring or 16
    local damping = limits.damping or 5.5
    local impulse = limits.impactResponse or 0.55
    state.pitchVelocity = (state.pitchVelocity or 0)
        + ((targetPitch - (state.pitch or 0)) * spring + pitchImpulse * impulse
            - (state.pitchVelocity or 0) * damping) * dt
    state.rollVelocity = (state.rollVelocity or 0)
        + ((targetRoll - (state.roll or 0)) * spring + rollImpulse * impulse
            - (state.rollVelocity or 0) * damping) * dt
    state.pitch = math.clamp((state.pitch or 0) + state.pitchVelocity * dt, -limits.maxPitch, limits.maxPitch)
    state.roll = math.clamp((state.roll or 0) + state.rollVelocity * dt, -limits.maxRoll, limits.maxRoll)
    if math.abs(state.pitch) >= limits.maxPitch then state.pitchVelocity *= 0.35 end
    if math.abs(state.roll) >= limits.maxRoll then state.rollVelocity *= 0.35 end
    return state.pitch, state.roll
end

function Wave.tilt(x, z, time, yaw, width, length, steer, speed, swells, limits)
    return Wave.surfaceTilt(x, z, time, yaw, width, length, steer, speed, swells, limits)
end

function Wave.impact(waveVelocity, hullVelocity, rollVelocity, beam)
    return math.clamp(math.max(0, waveVelocity - hullVelocity) + math.abs(rollVelocity) * beam * 0.25, 0, 3)
end

-- Intersect a hull-local X/Z point with a horizontal water plane while tilted.
function Wave.waterLocalY(surface, hullY, rightY, upY, backY, x, z)
    return (surface - hullY - rightY * x - backY * z) / math.max(0.1, upY)
end

return Wave
