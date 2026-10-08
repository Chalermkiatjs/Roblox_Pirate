local BoatMotion = {}

function BoatMotion.acceleration(vx, vz, targetX, targetZ, responseTime, maxAcceleration)
    local ax = (targetX - vx) / responseTime
    local az = (targetZ - vz) / responseTime
    local magnitude = math.sqrt(ax * ax + az * az)
    if magnitude > maxAcceleration then
        local scale = maxAcceleration / magnitude
        ax, az = ax * scale, az * scale
    end
    return ax, az
end

function BoatMotion.rudder(current, steer, dt, responseTime)
    return current + (math.clamp(steer, -1, 1) - current)
        * (1 - math.exp(-math.max(0, dt) / responseTime))
end

function BoatMotion.turning(forwardSpeed, yawRate, rudder, width, length, lever, settings)
    -- Large imported art should not compound both the turn-radius and response penalties.
    local scale = math.sqrt(math.clamp(length / 24, 1, 2.25))
    local response = settings.TurnResponse * scale
    local rateLimit = settings.MaxTurnRate / scale
    local desiredRate = math.clamp(-forwardSpeed * math.tan(rudder * settings.RudderAngle)
        * settings.TurnGain / math.clamp(length, 8, 48), -rateLimit, rateLimit)
    local inertiaPerMass = (length * length + width * width) / 12
    local accelerationLimit = settings.MaxTurnAcceleration / scale
    -- Rudder torque acts at the stern; passive water resistance damps yaw separately.
    local drive = math.clamp(desiredRate / response, -accelerationLimit, accelerationLimit)
    local damping = math.clamp(-yawRate / response, -accelerationLimit, accelerationLimit)
    return inertiaPerMass * drive / math.max(1, lever), inertiaPerMass * damping
end

return BoatMotion
