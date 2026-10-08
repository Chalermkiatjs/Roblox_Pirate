return {
    Swells = {
        {amplitude = 0.45, wavelength = 85, period = 8, x = 0.6, z = -0.8},
        {amplitude = 0.22, wavelength = 43, period = 5.5, x = -0.8, z = -0.6},
        {amplitude = 0.1, wavelength = 19, period = 3.8, x = 1, z = 0},
    },
    Rocking = {
        maxPitch = math.rad(4),
        maxRoll = math.rad(6),
        steeringBank = math.rad(1.5),
        spring = 14,
        damping = 5.2,
        impactResponse = 0.65,
    },
    Effects = {distance = 400, contactInterval = 0.1, burstCooldown = 0.65, maxSprayRate = 60},
}
