local Ships = require("../src/shared/ShipConfig")
local Islands = require("../src/shared/IslandConfig")
local Boss = require("../src/shared/BossConfig").Kraken
local Treasure = require("../src/shared/TreasureConfig")

local function count(t)
    local n = 0
    for _ in pairs(t) do n += 1 end
    return n
end

assert(count(Islands.Islands) == 5, "Expected five islands")
assert(#Ships.UpgradeOrder == 3, "Expected three ship tiers")
for _, island in pairs(Islands.Islands) do
    assert(Ships.Tiers[island.recommendedTier].maxDepth >= island.depth, "Recommended ship cannot reach island")
end
local previousCost, previousDepth = -1, 0
for _, tierId in ipairs(Ships.UpgradeOrder) do
    local tier = Ships.Tiers[tierId]
    assert(tier.cost > previousCost and tier.maxDepth >= previousDepth, "Invalid ship progression")
    assert(tier.cargoSlots > 0 and tier.speed > 0, "Ship is not usable")
    previousCost, previousDepth = tier.cost, tier.maxDepth
end
assert(Ships.getNextTier("Raft") == "Sloop")
assert(Ships.getNextTier("Sloop") == "Brigantine")
assert(Ships.getNextTier("Brigantine") == nil)
for rarity, weight in pairs(Treasure.RarityWeights) do
    assert(weight > 0 and Treasure.SellValues[rarity] > 0)
    local available = false
    for _, item in pairs(Treasure.Items) do
        if item.rarity == rarity then available = true end
    end
    assert(available, "Loot rarity has no item")
end
local bossShip = Ships.Tiers[Boss.requiredShipTier]
local retaliationCount = math.ceil(Boss.maxHealth / bossShip.cannonPower) - 1
assert(retaliationCount * Boss.damagePerTurn < bossShip.maxHealth, "Solo Kraken cannot be defeated with a full ship")
for id in pairs(Boss.rewardItems) do assert(Treasure.Items[id], "Unknown boss reward") end
print("PASS: island access, ship progression, rarity coverage, solo Kraken and rewards")
