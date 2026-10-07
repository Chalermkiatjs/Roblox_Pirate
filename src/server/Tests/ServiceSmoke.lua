local services = script.Parent.Parent.Services
local Data = require(services.DataService)
local Ship = require(services.ShipService)
local Treasure = require(services.TreasureService)
local Crew = require(services.CrewService)
local Boss = require(services.BossService)

return function()
    assert(game:GetService("RunService"):IsStudio(), "Smoke test must use temporary Studio data")
    local player = {UserId = -999999}
    local ok, err = pcall(function()
        local profile = Data.loadProfile(player)
        Ship.spawnShipState(player)
        assert(Ship.getStats(player).tierId == "Raft")
        assert(not Ship.canTravelDepth(player, 2))
        Treasure.grantLoot(player, 1, 100)
        assert(Treasure.remainingSlots(player) == 0, "Cargo overflow")
        assert(next(Treasure.grantLoot(player, 1, 1)) == nil)
        local collection = profile.collection
        local sale = Treasure.sellCargo(player)
        assert(sale.ok and sale.gold > 0)
        assert(profile.collection == collection and next(profile.cargo) == nil)
        Data.addGold(player, 4000)
        assert(Ship.upgradeShip(player).tier == "Sloop")
        assert(Ship.upgradeShip(player).tier == "Brigantine")
        assert(not Ship.upgradeShip(player).ok)
        assert(Crew.assignRecruit(player, "Bo").ok)
        assert(Ship.getStats(player).cannonPower > 28)
        assert(Ship.prepareVoyage(player).ok)
        local defeated = false
        for _ = 1, 12 do
            local attack = Boss.attackKraken(player)
            assert(not attack.shipDefeated, "Kraken is not survivable")
            if attack.defeatedBoss then defeated = true break end
        end
        assert(defeated and profile.stats.krakenDefeats == 1)
        assert(profile.collection.KrakenHeart == 1)
    end)
    Boss.reset(player)
    Ship.releaseShipState(player)
    Data.releaseProfile(player)
    assert(ok, err)
    print("PirateOcean service smoke tests passed")
end
