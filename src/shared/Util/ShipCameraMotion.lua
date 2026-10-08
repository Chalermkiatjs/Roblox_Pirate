local CameraMotion = {}

function CameraMotion.alpha(response, dt)
    return 1 - math.exp(-response * math.max(0, dt))
end

function CameraMotion.followAngle(current, target, response, dt)
    local difference = math.atan2(math.sin(target - current), math.cos(target - current))
    return current + difference * CameraMotion.alpha(response, dt)
end

function CameraMotion.distance(length, width, height, aspect, fieldOfView)
    local halfVertical = math.rad(fieldOfView) / 2
    local halfHorizontal = math.atan(math.tan(halfVertical) * math.max(0.25, aspect))
    local framingAngle = math.min(halfVertical, halfHorizontal)
    local radius = math.sqrt(length * length + width * width + (height * 0.65)^2) / 2
    return math.max(24, length * 0.85, radius / math.sin(framingAngle))
end

return CameraMotion
