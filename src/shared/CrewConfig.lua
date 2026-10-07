local CrewConfig = {
    Roles = {
        navigator = {
            displayName = "Navigator",
            bonus = {
                speedMultiplier = 1.08,
                eventRiskMultiplier = 0.92,
            },
        },
        gunner = {
            displayName = "Gunner",
            bonus = {
                cannonMultiplier = 1.15,
            },
        },
        quartermaster = {
            displayName = "Quartermaster",
            bonus = {
                cargoMultiplier = 1.15,
                sellMultiplier = 1.05,
            },
        },
    },
    Recruits = {
        Lina = { role = "navigator", cost = 120 },
        Bo = { role = "gunner", cost = 160 },
        Mara = { role = "quartermaster", cost = 180 },
    },
}

return CrewConfig

