local RunService = game:GetService("RunService")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("PirateOcean")
local Config = require(shared.WorldConfig)
local Islands = require(shared.IslandConfig)
local Ship = require(script.Parent.ShipService)
local Data = require(script.Parent.DataService)
local Physics = require(script.Parent.ShipPhysics)
local Sailing = require(shared.SailingConfig)
local TweenService = game:GetService("TweenService")
local World = {}
local boats, connections = {}, {}
local root, action, event, notice

local function part(parent, name, size, pos, color, material)
    local p = Instance.new("Part")
    p.Name, p.Size, p.Position = name, size, pos
    p.Color, p.Material = color, material or Enum.Material.WoodPlanks
    p.Anchored = true
    p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

local function sign(parent, pos, text)
    local anchor = part(parent, "Sign", Vector3.one, pos, Color3.new(1, 1, 1))
    anchor.Transparency, anchor.CanCollide = 1, false
    local gui = Instance.new("BillboardGui")
    gui.Size, gui.StudsOffset, gui.MaxDistance = UDim2.fromOffset(220, 60), Vector3.new(0, 4, 0), 300
    gui.Parent = anchor
    local label = Instance.new("TextLabel")
    label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
    label.Text, label.TextColor3, label.TextStrokeTransparency = text, Color3.new(1, 1, 1), 0.25
    label.Font, label.TextSize, label.TextWrapped = Enum.Font.GothamBold, 18, true
    label.Parent = gui
end

local function prompt(p, text, name, callback)
    local ui = Instance.new("ProximityPrompt")
    ui.ActionText, ui.ObjectText = text, name
    ui.MaxActivationDistance, ui.RequiresLineOfSight = 16, false
    ui.Parent = p
    ui.Triggered:Connect(callback)
end

function World.depth(pos)
    local depth = 1
    for _, boundary in ipairs(Config.DepthBoundaries) do
        if -pos.Z > boundary then depth += 1 end
    end
    return depth
end

function World.position(player)
    local boat = boats[player]
    return boat and boat.model.Parent and boat.model:GetPivot().Position or nil
end

function World.atPort(player)
    local pos = World.position(player)
    return pos ~= nil and math.abs(pos.X) < 800 and pos.Z > -150
end

function World.nearestIsland(player)
    local pos = World.position(player)
    if not pos then return nil end
    local nearest, distance = nil, Config.LootRange
    for id, islandPos in pairs(Config.Islands) do
        local d = (pos - islandPos).Magnitude
        if d < distance then nearest, distance = id, d end
    end
    return nearest
end

function World.control(player, throttle, steer)
    local boat = boats[player]
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if not boat or not humanoid or boat.seat.Occupant ~= humanoid then return end
    if type(throttle) ~= "number" or type(steer) ~= "number" then return end
    if throttle ~= throttle or steer ~= steer then return end
    boat.throttle, boat.steer = math.clamp(throttle, -1, 1), math.clamp(steer, -1, 1)
    boat.lastInput = os.clock()
end

local function showSail(boat, stage)
    local rig = boat.rig
    if boat.sailTween then boat.sailTween:Cancel() end
    if boat.sailJointTween then boat.sailJointTween:Cancel() end
    rig.stage = stage
    boat.model:SetAttribute("SailStage", stage)
    if not rig.sailPart or not rig.sailJoint then return end
    local height = 1.2 + Sailing.Stages[stage].deployment * 12.8
    local info = TweenInfo.new(Sailing.DeployTime, Enum.EasingStyle.Linear)
    boat.sailTween = TweenService:Create(rig.sailPart, info, {Size = Vector3.new(rig.hull.Size.X - 2, height, 0.4)})
    boat.sailJointTween = TweenService:Create(rig.sailJoint, info, {C0 = CFrame.new(0, 23 - height / 2, -2)})
    boat.sailTween:Play()
    boat.sailJointTween:Play()
end

function World.setSailStage(player, stage)
    if not Sailing.validStage(stage) then return {ok = false, error = "InvalidSailStage"} end
    local boat, state = boats[player], Ship.getState(player)
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if not boat or not state or not state.inVoyage or not humanoid or boat.seat.Occupant ~= humanoid then
        return {ok = false, error = "TakeTheHelm"}
    end
    showSail(boat, stage)
    return {ok = true, stage = stage}
end

function World.sailing(player)
    local boat = boats[player]
    if not boat then return nil end
    local velocity = boat.rig.hull.AssemblyLinearVelocity
    return {stage = boat.rig.stage, deployment = boat.rig.deployment, speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude}
end

function World.board(player)
    local boat, character = boats[player], player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not boat or not humanoid then return end
    character:PivotTo(boat.seat.CFrame * CFrame.new(0, 3, 0))
    task.delay(0.15, function()
        if boat.seat.Parent and humanoid.Parent then boat.seat:Sit(humanoid) end
    end)
end

function World.returnPort(player, sunk)
    local boat = boats[player]
    if not boat then return end
    boat.throttle, boat.steer, boat.eventTime = 0, 0, 0
    Physics.setActive(boat.rig, false)
    boat.model:PivotTo(CFrame.new(boat.berth))
    Physics.reset(boat.rig)
    showSail(boat, 0)
    boat.model:SetAttribute("Paddling", false)
    boat.model:SetAttribute("InVoyage", false)
    boat.safeCFrame = boat.model:GetPivot()
    local state = Ship.getState(player)
    if state then state.inVoyage, state.currentDepth = false, 1 end
    if sunk then
        local profile = Data.getProfile(player)
        if profile then profile.cargo = {} end
        if state then state.health = Ship.getStats(player).maxHealth end
        notice(player, "Ship lost! Cargo lost; collection kept. Back at port.")
    end
end

function World.spawnBoat(player)
    local old = boats[player]
    local index = old and old.index or 1
    if old then old.model:Destroy() else
        for _, boat in pairs(boats) do index = math.max(index, boat.index + 1) end
    end
    local berth = Config.Berth + Vector3.new((index - 1) * 35, 0, 0)
    local tier = Ship.getStats(player).tierId
    local width = tier == "Raft" and 12 or (tier == "Sloop" and 16 or 22)
    local length = width * 1.7
    local model = Instance.new("Model")
    model.Name, model.Parent = player.Name .. "_" .. tier, root.Boats
    local hull = part(model, "Hull", Vector3.new(width, 3, length), berth, Color3.fromRGB(100, 66, 43))
    model.PrimaryPart = hull
    part(model, "Deck", Vector3.new(width - 1, 1, length - 1), berth + Vector3.new(0, 2, 0), Color3.fromRGB(181, 142, 90))
    local seat = Instance.new("VehicleSeat")
    seat.Name, seat.Size, seat.Anchored = "Helm", Vector3.new(3, 1, 3), true
    seat.CFrame, seat.Color = CFrame.new(berth + Vector3.new(0, 3, length / 4)), Color3.fromRGB(44, 44, 44)
    seat.Parent = model
    part(model, "Mast", Vector3.new(1, 22, 1), berth + Vector3.new(0, 13, -2), Color3.fromRGB(107, 77, 46))
    part(model, "Sail", Vector3.new(width - 2, 1.2, 0.4), berth + Vector3.new(0, 22.4, -2), Color3.fromRGB(233, 239, 239), Enum.Material.Fabric)
    for _, side in ipairs({-1, 1}) do
        part(model, side == -1 and "LeftOar" or "RightOar", Vector3.new(10, 0.6, 1.4),
            berth + Vector3.new(side * (width / 2 + 3), 1.5, 4), Color3.fromRGB(139, 103, 62))
    end
    if tier ~= "Raft" then
        for _, x in ipairs({-width / 2, width / 2}) do
            part(model, "Cannon", Vector3.new(4, 2, 3), berth + Vector3.new(x, 4, -5), Color3.fromRGB(48, 51, 53), Enum.Material.Metal)
        end
    end
    sign(model, berth + Vector3.new(0, 24, 0), player.DisplayName .. " | " .. tier)
    local rig = Physics.attach(model, hull)
    boats[player] = {model = model, seat = seat, berth = berth, index = index, rig = rig,
        throttle = 0, steer = 0, lastInput = 0, eventTime = 0, safeCFrame = model:GetPivot()}
    model:SetAttribute("SailStage", 0)
    model:SetAttribute("Paddling", false)
    model:SetAttribute("InVoyage", false)
    prompt(seat, "Board", player.DisplayName .. "'s ship", function(visitor)
        if visitor ~= player then return end
        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not hrp or (hrp.Position - seat.Position).Magnitude > 22 then return end
        local state = Ship.getState(player)
        if state and state.inVoyage then World.board(player)
        elseif World.atPort(player) then action(player, "PrepareVoyage") end
    end)
end

function World.addPlayer(player)
    World.spawnBoat(player)
    local function spawned(character)
        local humanoid = character:WaitForChild("Humanoid", 10)
        local hrp = character:WaitForChild("HumanoidRootPart", 10)
        if not hrp or not humanoid or not player.Parent then return end
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
        World.returnPort(player, false)
        character:PivotTo(CFrame.new(Config.Port + Vector3.new(0, 8, 0)))
    end
    connections[player] = player.CharacterAdded:Connect(spawned)
    if player.Character then task.spawn(spawned, player.Character) end
end

function World.removePlayer(player)
    if connections[player] then connections[player]:Disconnect() end
    connections[player] = nil
    if boats[player] then boats[player].model:Destroy() end
    boats[player] = nil
end

function World.init(actionCallback, eventCallback, noticeCallback)
    action, event, notice = actionCallback, eventCallback, noticeCallback
    root = Instance.new("Folder")
    root.Name, root.Parent = "PirateOceanWorld", workspace
    local boatFolder = Instance.new("Folder")
    boatFolder.Name, boatFolder.Parent = "Boats", root
    local terrain = workspace.Terrain
    terrain.WaterColor = Color3.fromRGB(20, 93, 112)
    terrain.WaterTransparency, terrain.WaterReflectance = 0.38, 0.4
    terrain.WaterWaveSize, terrain.WaterWaveSpeed = Config.Water.WaveSize, Config.Water.WaveSpeed
    terrain:FillBlock(CFrame.new(Config.Water.Center), Config.Water.Size, Enum.Material.Water)
    part(root, "Seabed", Vector3.new(2200, 2, 2400), Vector3.new(0, -33, -700), Color3.fromRGB(64, 117, 123), Enum.Material.Sand)
    part(root, "Port", Vector3.new(180, 8, 100), Config.Port, Color3.fromRGB(72, 131, 80), Enum.Material.Grass)
    part(root, "Dock", Vector3.new(150, 2, 40), Vector3.new(0, 4, -60), Color3.fromRGB(149, 116, 75))
    local ladder = Instance.new("TrussPart")
    ladder.Name, ladder.Size, ladder.Position = "DockLadder", Vector3.new(2, 16, 2), Vector3.new(64, -2, -81)
    ladder.Anchored, ladder.Color, ladder.Parent = true, Color3.fromRGB(205, 210, 215), root
    local spawn = Instance.new("SpawnLocation")
    spawn.Size, spawn.Position = Vector3.new(8, 1, 8), Vector3.new(0, 9, 12)
    spawn.Anchored, spawn.Neutral, spawn.Transparency = true, true, 1
    spawn.Parent = root
    sign(root, Vector3.new(0, 16, 10), "PIRATE OCEAN\nHarbor")
    local stations = {{"Shipwright", -50, "UpgradeShip"}, {"Merchant", 0, "SellCargo"}, {"Set Sail", 50, "PrepareVoyage"}}
    for i, station in ipairs(stations) do
        local colors = {Color3.fromRGB(55, 85, 124), Color3.fromRGB(196, 69, 63), Color3.fromRGB(48, 133, 118)}
        local counter = part(root, station[1], Vector3.new(16, 5, 12), Vector3.new(station[2], 10, -20), colors[i])
        sign(root, counter.Position + Vector3.new(0, 8, 0), station[1])
        prompt(counter, station[1], "Harbor", function(player) action(player, station[3]) end)
    end
    for i, recruit in ipairs({"Lina", "Bo", "Mara"}) do
        local counter = part(root, recruit, Vector3.new(8, 4, 8), Vector3.new(-40 + i * 20, 10, 30), Color3.fromRGB(98, 88, 150))
        sign(root, counter.Position + Vector3.new(0, 5, 0), recruit .. " | Crew")
        prompt(counter, "Recruit", recruit, function(player) action(player, "AssignCrew", recruit) end)
    end
    for id, pos in pairs(Config.Islands) do
        local config = Islands.Islands[id]
        local model = Instance.new("Model")
        model.Name, model.Parent = id, root
        local land = part(model, "Sand", Vector3.new(8, 88, 88), pos, Color3.fromRGB(224, 207, 129), Enum.Material.Sand)
        land.Shape, land.Orientation = Enum.PartType.Cylinder, Vector3.new(0, 0, 90)
        part(model, "Grass", Vector3.new(48, 2, 48), pos + Vector3.new(0, 5, 0), Color3.fromRGB(65, 150, 83), Enum.Material.Grass)
        for _, offset in ipairs({Vector3.new(-16, 14, 5), Vector3.new(16, 14, 12), Vector3.new(2, 14, -19)}) do
            part(model, "PalmTrunk", Vector3.new(2, 18, 2), pos + offset, Color3.fromRGB(112, 85, 53))
            local crown = part(model, "PalmCrown", Vector3.new(15, 6, 15), pos + offset + Vector3.new(0, 10, 0), Color3.fromRGB(36, 123, 70), Enum.Material.Grass)
            crown.Shape = Enum.PartType.Ball
        end
        local chest = part(model, "TreasureChest", Vector3.new(7, 4, 5), pos + Vector3.new(0, 8, 24), Color3.fromRGB(212, 170, 44), Enum.Material.Metal)
        sign(model, pos + Vector3.new(0, 29, 0), config.displayName .. "\nSea " .. config.depth)
        prompt(chest, "Collect", config.displayName, function(player) action(player, "ExploreIsland", id) end)
        local islandLadder = Instance.new("TrussPart")
        islandLadder.Name, islandLadder.Size = "ShoreLadder", Vector3.new(2, 18, 2)
        islandLadder.Position, islandLadder.Anchored = pos + Vector3.new(0, -4, 44), true
        islandLadder.Parent = model
    end
    local kraken = Instance.new("Model")
    kraken.Name, kraken.Parent = "Kraken", root
    local head = part(kraken, "Head", Vector3.new(25, 24, 25), Config.Kraken + Vector3.new(0, 5, 0), Color3.fromRGB(140, 64, 146), Enum.Material.SmoothPlastic)
    head.Shape = Enum.PartType.Ball
    for i = 1, 8 do
        local angle = i * math.pi / 4
        local arm = part(kraken, "Tentacle", Vector3.new(6, 24, 6), Config.Kraken + Vector3.new(math.cos(angle) * 25, 2, math.sin(angle) * 25), Color3.fromRGB(112, 46, 130), Enum.Material.SmoothPlastic)
        arm.Orientation = Vector3.new(math.cos(angle) * 25, 0, math.sin(angle) * 25)
    end
    sign(kraken, Config.Kraken + Vector3.new(0, 28, 0), "THE FIRST KRAKEN")
    local lighting = game:GetService("Lighting")
    lighting.ClockTime, lighting.Brightness = 15, 2.3
    lighting.EnvironmentSpecularScale, lighting.EnvironmentDiffuseScale = 1, 0.8
    local atmosphere = Instance.new("Atmosphere")
    atmosphere.Name, atmosphere.Density, atmosphere.Offset = "OceanAtmosphere", 0.22, 0.15
    atmosphere.Color, atmosphere.Decay = Color3.fromRGB(202, 225, 239), Color3.fromRGB(124, 158, 174)
    atmosphere.Haze, atmosphere.Glare, atmosphere.Parent = 1.1, 0.12, lighting
    local clouds = Instance.new("Clouds")
    clouds.Name, clouds.Cover, clouds.Density, clouds.Parent = "OceanClouds", 0.35, 0.45, terrain
    RunService.PreSimulation:Connect(function(dt)
        dt = math.min(dt, 0.1)
        for player, boat in pairs(boats) do
            local state, stats = Ship.getState(player), Ship.getStats(player)
            if not state or not stats then continue end
            if state.health <= 0 then World.returnPort(player, true) end
            Physics.setActive(boat.rig, state.inVoyage)
            if boat.model:GetAttribute("InVoyage") ~= state.inVoyage then boat.model:SetAttribute("InVoyage", state.inVoyage) end
            if not state.inVoyage then continue end
            local seated = boat.seat.Occupant and boat.seat.Occupant.Parent == player.Character
            if not seated or os.clock() - boat.lastInput > 0.6 then boat.throttle, boat.steer = 0, 0 end
            if not seated and boat.rig.stage ~= 0 then showSail(boat, 0) end
            local paddling = seated ~= nil and seated ~= false and boat.rig.stage == 0 and math.abs(boat.throttle) > 0.1
            if boat.model:GetAttribute("Paddling") ~= paddling then boat.model:SetAttribute("Paddling", paddling) end
            local pos = boat.rig.hull.Position
            local function allowed(p)
                return World.depth(p) <= stats.maxDepth and p.Z <= -72 and math.abs(p.X) <= 950 and p.Z >= -1500
            end
            if not allowed(pos) or pos.Y < -20 then
                boat.model:PivotTo(boat.safeCFrame)
                boat.rig.hull.AssemblyLinearVelocity = Vector3.zero
                boat.rig.hull.AssemblyAngularVelocity = Vector3.zero
                pos = boat.rig.hull.Position
            else boat.safeCFrame = boat.model:GetPivot() end
            local predicted = pos + boat.rig.hull.AssemblyLinearVelocity * 2
            local throttle = allowed(predicted) and boat.throttle or 0
            Physics.update(boat.rig, dt, throttle, boat.steer, allowed(predicted) and stats.speed or 0)
            state.currentDepth = World.depth(pos)
            if -pos.Z > 160 and seated then
                boat.eventTime += dt
                if boat.eventTime >= Config.EventInterval then boat.eventTime = 0 event(player, state.currentDepth) end
            end
        end
    end)
end

return World
