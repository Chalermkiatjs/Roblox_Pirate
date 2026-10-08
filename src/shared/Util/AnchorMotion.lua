local Motion = {}

function Motion.step(previous, x, z, dt, maxSpeed)
    if not previous then return 0 end
    local distance = math.sqrt((x - previous.x)^2 + (z - previous.z)^2)
    if dt <= 0 or distance > maxSpeed * dt + 0.25 then return 0 end
    local angle = math.atan2(z, x) - math.atan2(previous.z, previous.x)
    return math.atan2(math.sin(angle), math.cos(angle))
end

return Motion
