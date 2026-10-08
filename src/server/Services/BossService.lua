local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedRoot = ReplicatedStorage:WaitForChild("PirateOcean")
local BossConfig = require(sharedRoot.BossConfig)
local CombatConfig = require(sharedRoot.CombatConfig)
local DataService = require(script.Parent.DataService)
local ShipService = require(script.Parent.ShipService)
local TreasureService = require(script.Parent.TreasureService)

local BossService = {}
local activeKrakenHealth = {}

function BossService.reset(player)
    activeKrakenHealth[player] = nil
end

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
        DataService.addBounty(player, CombatConfig.KrakenBounty)

        for itemId, amount in pairs(boss.rewardItems) do
            local cargoAmount = math.min(amount, TreasureService.remainingSlots(player))
            if cargoAmount > 0 then DataService.addCargo(player, itemId, cargoAmount) end
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
