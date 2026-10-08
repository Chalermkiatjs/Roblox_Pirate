local Motion = require("../src/shared/Util/ShipCameraMotion")
local Config = require("../src/shared/ShipCameraConfig")

local desktop = Motion.distance(167, 45, 100, 16 / 9, Config.FieldOfView)
local portrait = Motion.distance(167, 45, 100, 9 / 16, Config.FieldOfView)
assert(portrait > desktop, "Portrait camera must pull back to fit the ship")
assert(desktop > Motion.distance(24, 12, 24, 16 / 9, Config.FieldOfView), "Frigate needs a longer follow distance")
assert(Motion.distance(0, 0, 0, 0, Config.FieldOfView) >= 24, "Camera distance must remain safe during loading")

local wrapped = Motion.followAngle(math.rad(179), math.rad(-179), 5, 0.1)
assert(wrapped > math.rad(179) and wrapped < math.rad(181), "Heading must cross the wrap by the short path")
local reference
for _, fps in ipairs({30, 60, 120}) do
    local yaw = 0
    for _ = 1, fps do yaw = Motion.followAngle(yaw, math.pi / 2, Config.HeadingResponse, 1 / fps) end
    if reference then assert(math.abs(yaw - reference) < 0.000001, "Camera follow depends on frame rate") end
    reference = yaw
end
assert(Motion.alpha(6, 0) == 0 and Motion.alpha(6, -1) == 0)
print("PASS: ship camera framing, portrait aspect, heading wrap and frame-rate independent follow")
