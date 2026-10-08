local Navigation = {}

function Navigation.bounds(centerX, centerZ, sizeX, sizeZ, margin)
    return {
        minX = centerX - sizeX / 2 + margin, maxX = centerX + sizeX / 2 - margin,
        minZ = centerZ - sizeZ / 2 + margin, maxZ = centerZ + sizeZ / 2 - margin,
    }
end

function Navigation.contains(x, z, bounds)
    return x >= bounds.minX and x <= bounds.maxX and z >= bounds.minZ and z <= bounds.maxZ
end

function Navigation.limitSpeed(x, z, forwardX, forwardZ, targetSpeed, bounds, acceleration, responseTime)
    if targetSpeed == 0 then return 0 end
    local sign = targetSpeed < 0 and -1 or 1
    local limit = math.abs(targetSpeed)
    local function constrain(position, direction, low, high)
        if math.abs(direction) < 0.000001 then return end
        local remaining = math.max(0, direction > 0 and high - position or position - low)
        -- Include the propulsion response delay as well as the capped braking distance.
        local lag = acceleration * responseTime
        local componentLimit = math.sqrt(lag * lag + 2 * acceleration * remaining) - lag
        -- A critically damped approach avoids coasting past the edge as the target falls.
        componentLimit = math.min(componentLimit, remaining / (4 * responseTime))
        limit = math.min(limit, componentLimit / math.abs(direction))
    end
    constrain(x, forwardX * sign, bounds.minX, bounds.maxX)
    constrain(z, forwardZ * sign, bounds.minZ, bounds.maxZ)
    return limit * sign
end

return Navigation
