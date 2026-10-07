local OceanEventConfig = {
    Events = {
        FloatingWreckage = {
            displayName = "Floating Wreckage",
            minDepth = 1,
            weight = 32,
            damage = 0,
            lootRolls = 2,
        },
        MerchantRescue = {
            displayName = "Merchant Rescue",
            minDepth = 1,
            weight = 20,
            damage = 0,
            goldReward = 80,
        },
        ReefAmbush = {
            displayName = "Reef Ambush",
            minDepth = 2,
            weight = 22,
            damage = 35,
            lootRolls = 3,
        },
        StormSurge = {
            displayName = "Storm Surge",
            minDepth = 3,
            weight = 18,
            damage = 65,
            lootRolls = 2,
        },
        GhostShipRaid = {
            displayName = "Ghost Ship Raid",
            minDepth = 4,
            weight = 8,
            damage = 110,
            lootRolls = 5,
            goldReward = 220,
        },
    },
}

return OceanEventConfig

