local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local sharedRoot = ReplicatedStorage:WaitForChild("PirateOcean")
local DataService = require(script.Services.DataService)
local ShipService = require(script.Services.ShipService)
local IslandService = require(script.Services.IslandService)
local OceanEventService = require(script.Services.OceanEventService)
local CrewService = require(script.Services.CrewService)
local BossService = require(script.Services.BossService)

local remotesFolder = sharedRoot:FindFirstChild("Remotes") or Instance.new("Folder")
remotesFolder.Name = "Remotes"
remotesFolder.Parent = sharedRoot

local function getRemote(name)
    local remote = remotesFolder:FindFirstChild(name)
    if remote then
        return remote
    end

    remote = Instance.new("RemoteFunction")
    remote.Name = name
    remote.Parent = remotesFolder
    return remote
end

local requestSnapshot = getRemote("RequestSnapshot")
local prepareVoyage = getRemote("PrepareVoyage")
local exploreIsland = getRemote("ExploreIsland")
local triggerOceanEvent = getRemote("TriggerOceanEvent")
local attackKraken = getRemote("AttackKraken")
local upgradeShip = getRemote("UpgradeShip")
local assignCrew = getRemote("AssignCrew")
local sellCargo = getRemote("SellCargo")

local function snapshot(player)
    local profile = DataService.getProfile(player)
    if not profile then
        return nil
    end

    return {
        profile = profile,
        ship = ShipService.getShipSnapshot(player),
    }
end

Players.PlayerAdded:Connect(function(player)
    DataService.loadProfile(player)
    ShipService.spawnShipState(player)
end)

Players.PlayerRemoving:Connect(function(player)
    DataService.saveProfile(player)
    DataService.releaseProfile(player)
    ShipService.releaseShipState(player)
end)

requestSnapshot.OnServerInvoke = function(player)
    return snapshot(player)
end

prepareVoyage.OnServerInvoke = function(player)
    return ShipService.prepareVoyage(player)
end

exploreIsland.OnServerInvoke = function(player, islandId)
    return IslandService.explore(player, islandId)
end

triggerOceanEvent.OnServerInvoke = function(player, depth)
    return OceanEventService.trigger(player, depth)
end

attackKraken.OnServerInvoke = function(player)
    return BossService.attackKraken(player)
end

upgradeShip.OnServerInvoke = function(player)
    return ShipService.upgradeShip(player)
end

assignCrew.OnServerInvoke = function(player, recruitId)
    return CrewService.assignRecruit(player, recruitId)
end

sellCargo.OnServerInvoke = function(player)
    return require(script.Services.TreasureService).sellCargo(player)
end

game:BindToClose(function()
    for _, player in ipairs(Players:GetPlayers()) do
        DataService.saveProfile(player)
    end
end)
