local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedRoot = ReplicatedStorage:WaitForChild("PirateOcean")
local TreasureConfig = require(sharedRoot.TreasureConfig)
local WeightedRandom = require(sharedRoot.Util.WeightedRandom)
local DataService = require(script.Parent.DataService)
local ShipService = require(script.Parent.ShipService)

local TreasureService = {}

function TreasureService.remainingSlots(player)
    local profile = DataService.getProfile(player)
    local stats = ShipService.getStats(player)
    if not profile or not stats then return 0 end
    local used = 0
    for _, amount in pairs(profile.cargo) do used += amount end
    return math.max(0, stats.cargoSlots - used)
end

function TreasureService.rollRarity(depth)
    local depthBonus = math.max(0, depth - 1)

    local _, rarity = WeightedRandom.choose(TreasureConfig.RarityWeights, function(weight, rarity)
        if rarity == "Rare" then
            return weight + depthBonus * 2
        elseif rarity == "Epic" then
            return weight + depthBonus
        elseif rarity == "Legendary" then
            return weight + math.floor(depthBonus / 2)
        end

        return weight
    end)

    return rarity
end

function TreasureService.rollItem(depth)
    local rarity = TreasureService.rollRarity(depth)
    local candidates = {}

    for itemId, item in pairs(TreasureConfig.Items) do
        if item.rarity == rarity then
            candidates[itemId] = {
                id = itemId,
                weight = 1,
                rarity = rarity,
                kind = item.kind,
            }
        end
    end

    return WeightedRandom.choose(candidates)
end

function TreasureService.grantLoot(player, depth, rolls)
    local rewards = {}

    for _ = 1, math.min(rolls, TreasureService.remainingSlots(player)) do
        local item = TreasureService.rollItem(depth)
        if item then
            rewards[item.id] = (rewards[item.id] or 0) + 1
            DataService.addCargo(player, item.id, 1)
            DataService.addCollection(player, item.id, 1)
        end
    end

    return rewards
end

function TreasureService.sellCargo(player)
    local profile = DataService.getProfile(player)
    if not profile then
        return { ok = false, error = "ProfileUnavailable" }
    end

    local total = 0
    for itemId, amount in pairs(profile.cargo) do
        local item = TreasureConfig.getItem(itemId)
        if item then
            total += (TreasureConfig.SellValues[item.rarity] or 0) * amount
        end
    end

    profile.cargo = {}
    DataService.addGold(player, total)

    return { ok = true, gold = total }
end

return TreasureService
