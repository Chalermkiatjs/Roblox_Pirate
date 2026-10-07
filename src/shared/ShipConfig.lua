local ShipConfig = {
    Tiers = {
        Raft = {
            displayName = "Drift Raft",
            order = 1,
            cost = 0,
            maxHealth = 100,
            cargoSlots = 10,
            speed = 18,
            cannonPower = 4,
            maxDepth = 1,
            crewSlots = 1,
        },
        Sloop = {
            displayName = "Island Sloop",
            order = 2,
            cost = 650,
            maxHealth = 220,
            cargoSlots = 28,
            speed = 26,
            cannonPower = 12,
            maxDepth = 2,
            crewSlots = 2,
        },
        Brigantine = {
            displayName = "Storm Brigantine",
            order = 3,
            cost = 2400,
            maxHealth = 480,
            cargoSlots = 60,
            speed = 32,
            cannonPower = 28,
            maxDepth = 4,
            crewSlots = 3,
        },
    },
    UpgradeOrder = { "Raft", "Sloop", "Brigantine" },
}

function ShipConfig.getTier(tierId)
    return ShipConfig.Tiers[tierId]
end

function ShipConfig.getNextTier(tierId)
    for index, id in ipairs(ShipConfig.UpgradeOrder) do
        if id == tierId then
            return ShipConfig.UpgradeOrder[index + 1]
        end
    end

    return nil
end

return ShipConfig

