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

return BoatMotion
