local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedRoot = ReplicatedStorage:WaitForChild("PirateOcean")
local ShipConfig = require(sharedRoot.ShipConfig)
local CrewConfig = require(sharedRoot.CrewConfig)
local DataService = require(script.Parent.DataService)

local ShipService = {}
local shipState = {}

local function getCrewMultiplier(profile, statName)
    local multiplier = 1

    for role, recruitId in pairs(profile.crew) do
        if recruitId then
            local roleConfig = CrewConfig.Roles[role]
            if roleConfig and roleConfig.bonus[statName] then
                multiplier *= roleConfig.bonus[statName]
            end
        end
    end

    return multiplier
end

function ShipService.spawnShipState(player)
    local profile = DataService.getProfile(player)
    if not profile then
        return nil
    end

    local tier = ShipConfig.getTier(profile.currentShipTier)
    shipState[player] = {
        health = tier.maxHealth,
        inVoyage = false,
        currentDepth = 1,
    }

    return shipState[player]
end

function ShipService.releaseShipState(player)
    shipState[player] = nil
end

function ShipService.getState(player)
    return shipState[player]
end

function ShipService.getStats(player)
    local profile = DataService.getProfile(player)
    if not profile then
        return nil
    end

    local tier = ShipConfig.getTier(profile.currentShipTier)
    local cargoMultiplier = getCrewMultiplier(profile, "cargoMultiplier")

    return {
        tierId = profile.currentShipTier,
        maxHealth = tier.maxHealth,
        cargoSlots = math.floor(tier.cargoSlots * cargoMultiplier),
        speed = tier.speed * getCrewMultiplier(profile, "speedMultiplier"),
        cannonPower = tier.cannonPower * getCrewMultiplier(profile, "cannonMultiplier"),
        maxDepth = tier.maxDepth,
        crewSlots = tier.crewSlots,
    }
end

function ShipService.getShipSnapshot(player)
    local state = ShipService.getState(player)
    local stats = ShipService.getStats(player)

    return {
        state = state,
        stats = stats,
    }
end

function ShipService.prepareVoyage(player)
    local profile = DataService.getProfile(player)
    local state = ShipService.getState(player) or ShipService.spawnShipState(player)
    local stats = ShipService.getStats(player)

    if not profile or not state or not stats then
        return { ok = false, error = "ProfileUnavailable" }
    end

    state.inVoyage = true
    state.health = stats.maxHealth
    state.currentDepth = 1
    profile.stats.voyages += 1

    return { ok = true, ship = ShipService.getShipSnapshot(player) }
end

function ShipService.damage(player, amount)
    local state = ShipService.getState(player)
    if not state then
        return { defeated = false, health = 0 }
    end

    state.health = math.max(0, state.health - amount)
    local defeated = state.health <= 0

    if defeated then
        state.inVoyage = false
    end

    return { defeated = defeated, health = state.health }
end

function ShipService.canTravelDepth(player, depth)
    local stats = ShipService.getStats(player)
    return stats and depth <= stats.maxDepth
end

function ShipService.upgradeShip(player)
    local profile = DataService.getProfile(player)
    if not profile then
        return { ok = false, error = "ProfileUnavailable" }
    end

    local nextTierId = ShipConfig.getNextTier(profile.currentShipTier)
    if not nextTierId then
        return { ok = false, error = "MaxTier" }
    end

    local nextTier = ShipConfig.getTier(nextTierId)
    if not DataService.spendGold(player, nextTier.cost) then
        return { ok = false, error = "NotEnoughGold", required = nextTier.cost }
    end

    profile.currentShipTier = nextTierId
    ShipService.spawnShipState(player)

    return { ok = true, tier = nextTierId, ship = ShipService.getShipSnapshot(player) }
end

return ShipService

