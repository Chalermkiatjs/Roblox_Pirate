local Wave = require("../src/shared/Util/WaveMotion")
local Ocean = require("../src/shared/OceanConfig")
local amplitude = 0
for _, swell in ipairs(Ocean.Swells) do
    assert(math.abs(swell.x^2 + swell.z^2 - 1) < 0.00001)
    assert(swell.period > 0 and swell.wavelength > 0 and swell.amplitude > 0)
    amplitude += swell.amplitude
end
local observedPitch, observedRoll = 0, 0
local observedResponsivePitch, observedResponsiveRoll = 0, 0
local responsiveState = {pitch = 0, roll = 0, pitchVelocity = 0, rollVelocity = 0}
for step = 0, 600 do
    local time = step / 10
    local height, velocity = Wave.sample(130, -270, time, Ocean.Swells)
    assert(math.abs(height) <= amplitude + 0.00001 and velocity == velocity)
    local h1 = Wave.sample(130, -270, time + 0.0001, Ocean.Swells)
    local h0 = Wave.sample(130, -270, time - 0.0001, Ocean.Swells)
    assert(math.abs((h1 - h0) / 0.0002 - velocity) < 0.00001, "Wave velocity is not the height derivative")
    for _, yaw in ipairs({0, math.pi / 2, math.pi, -math.pi / 2}) do
        local pitch, roll = Wave.tilt(130, -270, time, yaw, 21.6, 90, 1, 30, Ocean.Swells, Ocean.Rocking)
        assert(math.abs(pitch) <= Ocean.Rocking.maxPitch and math.abs(roll) <= Ocean.Rocking.maxRoll, "Rocking can capsize a boat")
        observedPitch, observedRoll = math.max(observedPitch, math.abs(pitch)), math.max(observedRoll, math.abs(roll))
    end
    local responsivePitch, responsiveRoll = Wave.rocking(responsiveState, 0.1, 130, -270, time, 0,
        21.6, 90, 1, 30, Ocean.Swells, Ocean.Rocking)
    assert(math.abs(responsivePitch) <= Ocean.Rocking.maxPitch
        and math.abs(responsiveRoll) <= Ocean.Rocking.maxRoll, "Responsive rocking can capsize a boat")
    observedResponsivePitch = math.max(observedResponsivePitch, math.abs(responsivePitch))
    observedResponsiveRoll = math.max(observedResponsiveRoll, math.abs(responsiveRoll))
end
assert(observedPitch > 0.001 and observedRoll > 0.001, "Rocking is static")
assert(observedResponsivePitch > 0.001 and observedResponsiveRoll > 0.001, "Responsive rocking is static")
local impulseState = {pitch = 0, roll = 0, pitchVelocity = 0, rollVelocity = 0}
local instantPitch = Wave.surfaceTilt(130, -270, 2, 0, 21.6, 90, 0, 0, Ocean.Swells, Ocean.Rocking)
local responsivePitch = Wave.rocking(impulseState, 1 / 60, 130, -270, 2, 0,
    21.6, 90, 0, 0, Ocean.Swells, Ocean.Rocking)
assert(math.abs(responsivePitch) < math.abs(instantPitch) * 0.5,
    "Boat should lag the water impact instead of snapping to the wave slope")
local huge = {{amplitude = 100, wavelength = 10, period = 1, x = 1, z = 0}}
local pitch, roll = Wave.tilt(1, 0, 0, 0, 2, 2, -1, 100, huge, Ocean.Rocking)
assert(math.abs(pitch) <= Ocean.Rocking.maxPitch and math.abs(roll) <= Ocean.Rocking.maxRoll)
assert(Wave.impact(-1, 0, 0, 20) == 0, "Falling waves trigger impact bursts")
assert(Wave.impact(1, 0, 0, 20) > 0)
assert(Wave.impact(100, -100, 100, 20) == 3, "Particle impact strength is unbounded")
for _, up in ipairs({1, 0.99, 0.9}) do
    local y = Wave.waterLocalY(0.12, 1.8, 0.1, up, -0.05, 10, -40)
    assert(math.abs(1.8 + 0.1 * 10 + up * y - 0.05 * -40 - 0.12) < 0.00001,
        "Splash attachment leaves the water plane when the boat rocks")
end
assert(Wave.waterLocalY(0, 0, 0, 0, 0, 0, 0) == 0, "Tilt guard divides by zero")
print("PASS: bounded swells, rocking, impact strength and tilted water contact positioning")
