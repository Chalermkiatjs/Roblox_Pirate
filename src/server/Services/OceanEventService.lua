local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedRoot = ReplicatedStorage:WaitForChild("PirateOcean")
local OceanEventConfig = require(sharedRoot.OceanEventConfig)
local WeightedRandom = require(sharedRoot.Util.WeightedRandom)
local ShipService = require(script.Parent.ShipService)
local TreasureService = require(script.Parent.TreasureService)
local DataService = require(script.Parent.DataService)

local OceanEventService = {}

local function eligibleEvents(depth)
    local events = {}

    for eventId, event in pairs(OceanEventConfig.Events) do
        if depth >= event.minDepth then
            events[eventId] = event
        end
    end

    return events
end

function OceanEventService.trigger(player, depth)
    depth = math.clamp(tonumber(depth) or 1, 1, 4)

    if not ShipService.canTravelDepth(player, depth) then
        return { ok = false, error = "ShipTierTooLow", depth = depth }
    end

    local profile = DataService.getProfile(player)
    if not profile then
        return { ok = false, error = "ProfileUnavailable" }
    end

    profile.stats.deepestDepth = math.max(profile.stats.deepestDepth, depth)

    local event, eventId = WeightedRandom.choose(eligibleEvents(depth))
    if not event then
        return { ok = false, error = "NoEvent" }
    end

    local damageResult = ShipService.damage(player, event.damage or 0)
    local rewards = {}

    if not damageResult.defeated and event.lootRolls then
        rewards = TreasureService.grantLoot(player, depth, event.lootRolls)
    end

    if not damageResult.defeated and event.goldReward then
        DataService.addGold(player, event.goldReward)
    end

    return {
        ok = true,
        eventId = eventId,
        displayName = event.displayName,
        damage = event.damage or 0,
        defeated = damageResult.defeated,
        health = damageResult.health,
        rewards = rewards,
        gold = event.goldReward or 0,
    }
end

return OceanEventService

