local IslandConfig = {
    Islands = {
        StarterCove = {
            displayName = "Starter Cove",
            depth = 1,
            recommendedTier = "Raft",
            lootBudget = 1,
        },
        PalmhookAtoll = {
            displayName = "Palmhook Atoll",
            depth = 1,
            recommendedTier = "Raft",
            lootBudget = 2,
        },
        IronreefIsland = {
            displayName = "Ironreef Island",
            depth = 2,
            recommendedTier = "Sloop",
            lootBudget = 3,
        },
        StormglassKey = {
            displayName = "Stormglass Key",
            depth = 3,
            recommendedTier = "Brigantine",
            lootBudget = 4,
        },
        SkullmoonIsle = {
            displayName = "Skullmoon Isle",
            depth = 4,
            recommendedTier = "Brigantine",
            lootBudget = 5,
        },
    },
}

function IslandConfig.getIsland(islandId)
    return IslandConfig.Islands[islandId]
end

return IslandConfig
