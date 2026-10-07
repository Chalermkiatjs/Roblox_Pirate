local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedRoot = ReplicatedStorage:WaitForChild("PirateOcean")
local IslandConfig = require(sharedRoot.IslandConfig)
local ShipService = require(script.Parent.ShipService)
local TreasureService = require(script.Parent.TreasureService)
local DataService = require(script.Parent.DataService)

local IslandService = {}

function IslandService.explore(player, islandId)
    local island = IslandConfig.getIsland(islandId)
    local profile = DataService.getProfile(player)

    if not island or not profile then
        return { ok = false, error = "InvalidIsland" }
    end

    if not ShipService.canTravelDepth(player, island.depth) then
        return { ok = false, error = "ShipTierTooLow", requiredDepth = island.depth }
    end

    profile.discoveredIslands[islandId] = true
    profile.stats.deepestDepth = math.max(profile.stats.deepestDepth, island.depth)

    local rewards = TreasureService.grantLoot(player, island.depth, island.lootBudget)

    return {
        ok = true,
        island = islandId,
        rewards = rewards,
    }
end

return IslandService

