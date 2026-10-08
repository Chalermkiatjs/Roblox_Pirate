local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local shared = ReplicatedStorage:WaitForChild("PirateOcean")
local services = script.Parent.Services
local Data = require(services.DataService)
local Ship = require(services.ShipService)
local Islands = require(services.IslandService)
local Events = require(services.OceanEventService)
local Crew = require(services.CrewService)
local Boss = require(services.BossService)
local Treasure = require(services.TreasureService)
local World = require(services.WorldService)
local Combat = require(services.CombatService)
local Config = require(shared.WorldConfig)
local CrewConfig = require(shared.CrewConfig)
local folder = Instance.new("Folder")
folder.Name, folder.Parent = "Remotes", shared
local notice = Instance.new("RemoteEvent")
notice.Name, notice.Parent = "Notice", folder
local control = Instance.new("RemoteEvent")
control.Name, control.Parent = "ShipControl", folder
control.OnServerEvent:Connect(World.control)
local stepStage = Instance.new("RemoteEvent")
stepStage.Name, stepStage.Parent = "StepSailStage", folder
stepStage.OnServerEvent:Connect(World.stepSailStage)
local combatAction = Instance.new("RemoteEvent")
combatAction.Name, combatAction.Parent = "CombatAction", folder
combatAction.OnServerEvent:Connect(Combat.request)
local combatFeedback = Instance.new("RemoteEvent")
combatFeedback.Name, combatFeedback.Parent = "CombatFeedback", folder
local lastAction, lootTimes = {}, {}

local function notify(player, text)
    if player.Parent then notice:FireClient(player, text) end
end

local function snapshot(player)
    local profile = Data.getProfile(player)
    if not profile then return nil end
    return {profile = profile, player = Combat.getSnapshot(player), ship = Ship.getShipSnapshot(player), atPort = World.atPort(player), nearestIsland = World.nearestIsland(player), sailing = World.sailing(player)}
end

local function handle(player, action, argument)
    if not Data.getProfile(player) then return {ok = false, error = "ProfileUnavailable"} end
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return {ok = false, error = "CharacterUnavailable"} end
    local now = os.clock()
    if action ~= "DockingAction" then
        if now - (lastAction[player] or -10) < 0.5 then return {ok = false, error = "SlowDown"} end
        lastAction[player] = now
    end
    local atPort, state = World.atPort(player), Ship.getState(player)
    local result
    if action == "SetSailStage" then
        result = World.setSailStage(player, argument)
    elseif action == "DockingAction" then
        result = World.dockingAction(player, argument)
    elseif action == "PrepareVoyage" then
        if not atPort then return {ok = false, error = "ReturnToPort"} end
        result = Ship.prepareVoyage(player)
        if result.ok then World.board(player) end
    elseif action == "ReturnPort" then
        if not atPort then return {ok = false, error = "SailBackToPort"} end
        World.returnPort(player, false)
        result = {ok = true}
    elseif action == "SellCargo" or action == "UpgradeShip" or action == "AssignCrew" then
        if not atPort then return {ok = false, error = "ReturnToPort"} end
        if action == "SellCargo" then result = Treasure.sellCargo(player)
        elseif action == "UpgradeShip" then
            result = Ship.upgradeShip(player)
            if result.ok then World.spawnBoat(player) end
        else
            if type(argument) ~= "string" or not CrewConfig.Recruits[argument] then return {ok = false, error = "InvalidRecruit"} end
            result = Crew.assignRecruit(player, argument)
        end
    elseif action == "ExploreIsland" then
        local island = World.nearestIsland(player)
        if not state.inVoyage or not island or (argument and argument ~= island) then return {ok = false, error = "SailNearIsland"} end
        lootTimes[player] = lootTimes[player] or {}
        if now - (lootTimes[player][island] or -100) < Config.LootCooldown then return {ok = false, error = "TreasureRecovering"} end
        if Treasure.remainingSlots(player) <= 0 then return {ok = false, error = "CargoFull"} end
        result = Islands.explore(player, island)
        if result.ok then lootTimes[player][island] = now end
    elseif action == "AttackKraken" then
        local pos = World.position(player)
        if not state.inVoyage or not pos or (pos - Config.Kraken).Magnitude > 110 then return {ok = false, error = "SailNearKraken"} end
        result = Boss.attackKraken(player)
    else return {ok = false, error = "UnknownAction"} end
    if Ship.getState(player).health <= 0 then World.returnPort(player, true) Boss.reset(player) end
    if result.ok then
        local message = action
        if action == "ExploreIsland" then
            local count = 0
            for _, amount in pairs(result.rewards) do count += amount end
            message = "Treasure collected: " .. count
        elseif action == "SellCargo" then message = "Sold cargo for " .. result.gold .. " gold"
        elseif action == "UpgradeShip" then message = "New ship: " .. result.tier
        elseif action == "PrepareVoyage" then message = "Voyage started"
        elseif action == "AttackKraken" then message = result.defeatedBoss and "Kraken defeated!" or ("Kraken HP: " .. result.bossHealth)
        elseif action == "AssignCrew" then message = argument .. " joined the crew"
        elseif action == "ReturnPort" then message = "Docked at harbor" end
        if action == "DockingAction" then
            if result.mode == "Dropped" then message = "Anchor dropped"
            elseif result.mode == "Raised" then message = "Anchor raised"
            else message = "Walk around the bow capstan to raise anchor" end
        end
        if action == "SetSailStage" then message = require(shared.SailingConfig).Stages[argument].name end
        notify(player, message)
    end
    return result
end

local function remote(name, callback)
    local instance = Instance.new("RemoteFunction")
    instance.Name, instance.Parent = name, folder
    instance.OnServerInvoke = callback
end
remote("RequestSnapshot", snapshot)
for _, name in ipairs({"PrepareVoyage", "ReturnPort", "ExploreIsland", "AttackKraken", "UpgradeShip", "AssignCrew", "SellCargo", "SetSailStage", "DockingAction"}) do
    remote(name, function(player, argument) return handle(player, name, argument) end)
end
World.init(function(player, action, argument)
    local result = handle(player, action, argument)
    if not result.ok then notify(player, result.error) end
end, function(player, depth)
    local result = Events.trigger(player, depth)
    if result.ok then
        notify(player, result.displayName .. " | Damage: " .. result.damage)
        if result.defeated then World.returnPort(player, true) Boss.reset(player) end
    end
end, notify)
Combat.init(combatFeedback)
local function join(player)
    Data.loadProfile(player)
    if not player.Parent then Data.releaseProfile(player) return end
    Ship.spawnShipState(player)
    World.addPlayer(player)
    Combat.addPlayer(player)
end
Players.PlayerAdded:Connect(join)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(join, player) end
Players.PlayerRemoving:Connect(function(player)
    Combat.removePlayer(player)
    Data.saveProfile(player)
    World.removePlayer(player)
    Ship.releaseShipState(player)
    Boss.reset(player)
    Data.releaseProfile(player)
    lastAction[player], lootTimes[player] = nil, nil
end)
game:BindToClose(function()
    for _, player in ipairs(Players:GetPlayers()) do Data.saveProfile(player) end
end)
