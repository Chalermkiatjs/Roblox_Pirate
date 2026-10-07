local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedRoot = ReplicatedStorage:WaitForChild("PirateOcean")
local BossConfig = require(sharedRoot.BossConfig)
local DataService = require(script.Parent.DataService)
local ShipService = require(script.Parent.ShipService)

local BossService = {}
local activeKrakenHealth = {}

function BossService.attackKraken(player)
    local profile = DataService.getProfile(player)
    local stats = ShipService.getStats(player)
    local boss = BossConfig.Kraken

    if not profile or not stats then
        return { ok = false, error = "ProfileUnavailable" }
    end

    if profile.currentShipTier ~= boss.requiredShipTier then
        return { ok = false, error = "ShipTierTooLow", requiredTier = boss.requiredShipTier }
    end

    local health = activeKrakenHealth[player] or boss.maxHealth
    health = math.max(0, health - stats.cannonPower)

    local damageResult = { defeated = false, health = ShipService.getState(player).health }
    if health > 0 then
        damageResult = ShipService.damage(player, boss.damagePerTurn)
    end

    if health <= 0 then
        activeKrakenHealth[player] = nil
        profile.stats.krakenDefeats += 1
        DataService.addGold(player, boss.rewardGold)

        for itemId, amount in pairs(boss.rewardItems) do
            DataService.addCargo(player, itemId, amount)
            DataService.addCollection(player, itemId, amount)
        end

        return {
            ok = true,
            defeatedBoss = true,
            rewardGold = boss.rewardGold,
            rewardItems = boss.rewardItems,
        }
    end

    activeKrakenHealth[player] = health

    return {
        ok = true,
        defeatedBoss = false,
        bossHealth = health,
        shipHealth = damageResult.health,
        shipDefeated = damageResult.defeated,
    }
end

return BossService

