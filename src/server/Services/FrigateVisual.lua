local ServerStorage = game:GetService("ServerStorage")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("PirateOcean")
local Config = require(shared.FrigateConfig)
local Collision = require(shared.FrigateCollision)
local Imports = require(shared.FrigateImports)
local Visual = {}
local template

local function vector(values)
    return Vector3.new(values[1], values[2], values[3])
end

local function validTemplate(model)
    if not model or not model:IsA("Model") then return false end
    for _, name in ipairs({"Frigate_Main_Deck_Planks", "Frigate_Mainmast_Sail_1", "Frigate_Rudder_Blade"}) do
        local p = model:FindFirstChild(name, true)
        if not p or not p:IsA("MeshPart") then return false end
    end
    local owner = model:FindFirstChild("Frigate_Main_Deck_Planks", true).Parent
    while owner and owner ~= model do
        if owner:IsA("Model") and owner:FindFirstChild("Frigate_Mainmast_Sail_1", true)
            and owner:FindFirstChild("Frigate_Rudder_Blade", true) then return false end
        owner = owner.Parent
    end
    return true
end

local function hasInterior(model)
    for _, name in ipairs({"Frigate_Gun_Deck_Floor", "Frigate_Companionway_Stairs", "Frigate_Ship_Wheel"}) do
        local part = model:FindFirstChild(name, true)
        if not part or not part:IsA("MeshPart") then return false end
    end
    return true
end

function Visual.prepareTemplate()
    template = nil
    if not Config.Enabled then return end
    local assets = ServerStorage:FindFirstChild("PirateOceanAssets")
    local candidate = assets and assets:FindFirstChild(Config.TemplateName)
    local worldImports = Imports.collect(workspace, validTemplate, Config)
    local storedImports = Imports.collect(ServerStorage, validTemplate, Config)
    local previous = candidate
    local function revision(item)
        if item:FindFirstChild("Frigate_Stern_Transom_Planking", true) then return 3 end
        return hasInterior(item) and 2 or 1
    end
    -- A newly imported editor asset must supersede the cached runtime template.
    for index, items in ipairs({storedImports, worldImports}) do
        for _, item in ipairs(items) do
            if validTemplate(item)
                and (not validTemplate(candidate) or revision(item) > revision(candidate)
                    or (index == 2 and revision(item) == revision(candidate))) then
                candidate = item
            end
        end
    end
    if not assets then
        assets = Instance.new("Folder")
        assets.Name, assets.Parent = "PirateOceanAssets", ServerStorage
    end
    local backups = assets:FindFirstChild("ImportBackups")
    if not backups then
        backups = Instance.new("Folder")
        backups.Name, backups.Parent = "ImportBackups", assets
    end
    local function freeze(item)
        local function freezePart(p)
            if not p:IsA("BasePart") then return end
            p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
            p.EnableFluidForces = false
            p.AssemblyLinearVelocity, p.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
        end
        freezePart(item)
        for _, p in ipairs(item:GetDescendants()) do freezePart(p) end
    end
    -- Remove the chosen source first, before archiving any named wrapper around it.
    if validTemplate(candidate) then
        freeze(candidate)
        candidate.Name, candidate.Parent = Config.TemplateName, assets
        template = candidate
    end
    for _, item in ipairs(worldImports) do
        if item ~= candidate and item.Parent and item:IsDescendantOf(workspace) then
            freeze(item)
            item.Parent = backups
        end
    end
    if previous ~= candidate and validTemplate(previous) then
        freeze(previous)
        previous.Name, previous.Parent = Config.TemplateName .. "_Legacy", backups
    end
    if not template then
        warn("ReferenceFrigate is missing or incomplete. Import assets/roblox/reference_frigate_roblox.fbx without Merge Meshes; unusable named imports are preserved in PirateOceanAssets.ImportBackups. Using blockout boats.")
    end
end

local function collisionPart(model, name, size, cf, kind)
    local p = Instance.new(kind == "Wedge" and "WedgePart" or "Part")
    if kind == "Cylinder" then p.Shape = Enum.PartType.Cylinder end
    p.Name, p.Size, p.CFrame = name, size, cf
    p.Transparency, p.Anchored, p.CanCollide = 1, true, true
    p.CanQuery, p.CanTouch, p.EnableFluidForces = true, false, false
    p:SetAttribute("ShipCollision", true)
    p.Parent = model
    return p
end

local function sourcePoint(position)
    return (position + vector(Config.VisualOffset)) * Config.ArtScale
end

local function authoredCollision(model, imported, frame)
    for _, spec in ipairs(Collision.Parts) do
        if not spec.requires or imported:FindFirstChild(spec.requires, true) then
            local axes = spec.axes
            local cf = CFrame.fromMatrix(sourcePoint(vector(spec.position)),
                vector(axes[1]), vector(axes[2]), vector(axes[3]))
            local part = collisionPart(model, spec.name, vector(spec.size) * Config.ArtScale,
                frame * cf, spec.kind)
            part:SetAttribute("CollisionCategory", spec.category)
            if spec.follow then part:SetAttribute("CollisionFollow", spec.follow) end
        end
    end
    model:SetAttribute("CollisionRevision", Collision.Revision)
end

function Visual.setCollisionDebug(model, enabled)
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") and part:GetAttribute("ShipCollision") then
            part.Transparency = enabled and 0.65 or 1
            part.Color = part:GetAttribute("CollisionFollow") and Color3.fromRGB(255, 110, 75)
                or Color3.fromRGB(65, 205, 160)
            part.CastShadow = false
        end
    end
end

local function bounds(model)
    local low = Vector3.new(math.huge, math.huge, math.huge)
    local high = -low
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") then
            for _, x in ipairs({-0.5, 0.5}) do
                for _, y in ipairs({-0.5, 0.5}) do
                    for _, z in ipairs({-0.5, 0.5}) do
                        local point = p.CFrame * Vector3.new(p.Size.X * x, p.Size.Y * y, p.Size.Z * z)
                        low = low:Min(point)
                        high = high:Max(point)
                    end
                end
            end
        end
    end
    return (low + high) / 2, high - low
end

function Visual.berth(base, index, tier)
    if template and Config.Tiers[tier] then
        return base + Vector3.new((index - 1) * Config.BerthSpacing, 0, 0) + vector(Config.BerthOffset)
    end
    return base + Vector3.new((index - 1) * 35, 0, 0)
end

local function deckPanel(model, frame, spec)
    local a = sourcePoint(Vector3.new(spec.x, spec.y0, spec.z0))
    local b = sourcePoint(Vector3.new(spec.x, spec.y1, spec.z1))
    local offset = Vector3.new(0, Config.ColliderThickness / 2, 0)
    collisionPart(model, spec.name, Vector3.new(spec.width * Config.ArtScale,
        Config.ColliderThickness, (b - a).Magnitude + (spec.overlap or 0.15)),
        frame * CFrame.lookAt((a + b) / 2 - offset, b - offset))
    if spec.rails then
        for _, side in ipairs({-1, 1}) do
            if spec.outerRailSide and side ~= spec.outerRailSide then continue end
            local center = (a + b) / 2 + Vector3.new(side * spec.width * Config.ArtScale / 2, 0.4 * Config.ArtScale, 0)
            collisionPart(model, "DeckRail", Vector3.new(0.12 * Config.ArtScale, 0.8 * Config.ArtScale,
                (spec.z1 - spec.z0) * Config.ArtScale + 0.15), frame * CFrame.new(center))
        end
    elseif spec.aftRail then
        collisionPart(model, "AftRail", Vector3.new(spec.width * Config.ArtScale, 0.8 * Config.ArtScale, 0.3),
            frame * CFrame.new(b + Vector3.new(0, 0.4 * Config.ArtScale, 0)))
    end
end

function Visual.create(model, berth, tier)
    if not template or not template.Parent or not Config.Tiers[tier] then return nil end
    local imported = template:Clone()
    imported.Name, imported.PrimaryPart = "FrigateVisual", nil
    for _, item in ipairs(imported:GetDescendants()) do
        if item:IsA("JointInstance") or item:IsA("WeldConstraint")
            or item:IsA("Constraint") or item:IsA("LuaSourceContainer") or item:IsA("PackageLink") then
            item:Destroy()
        elseif item:IsA("BasePart") then
            item.Anchored, item.CanCollide, item.CanTouch, item.CanQuery = true, false, false, false
            item.EnableFluidForces = false
            item:SetAttribute("SailingRole", Config.movingRole(item.Name))
        end
    end
    local bow = imported:FindFirstChild("Frigate_Bow_Stem", true)
    local stock = imported:FindFirstChild("Frigate_Rudder_Stock", true)
    if not bow or not stock or not bow:IsA("BasePart") or not stock:IsA("BasePart") then
        imported:Destroy()
        warn("Frigate import is missing its bow stem or rudder stock")
        return nil
    end
    -- Importers may flip the forward axis. Align the actual bow, not the group pivot.
    local direction = bow.Position - stock.Position
    if Vector3.new(direction.X, 0, direction.Z).Magnitude < 0.1 then
        imported:Destroy()
        warn("Frigate import has invalid bow/stern positions")
        return nil
    end
    local yaw = Config.importYaw(bow.Position.X, bow.Position.Z, stock.Position.X, stock.Position.Z)
    imported.WorldPivot = CFrame.new(imported:GetPivot().Position) * CFrame.Angles(0, yaw, 0)
    imported:PivotTo(CFrame.identity)
    local _, size = bounds(imported)
    if size.Z < 0.01 then imported:Destroy() return nil end
    imported:ScaleTo(imported:GetScale() * Config.Length * Config.ArtScale / size.Z)
    local center = bounds(imported)
    imported.WorldPivot = CFrame.new(center - vector(Config.BoundsCenter) * Config.ArtScale)
    imported:PivotTo(CFrame.new(berth + vector(Config.VisualOffset) * Config.ArtScale))
    imported.Parent = model

    local interior = hasInterior(imported)
    local sealedStern = imported:FindFirstChild("Frigate_Stern_Transom_Planking", true) ~= nil
    if interior and not sealedStern then
        warn("Frigate hitboxes updated, but old stern art is still imported. Reimport the revision-3 FBX to remove missing transom bands.")
    end
    if not interior then
        warn("ReferenceFrigate uses the old closed deck. Reimport the revised FBX for the wheel and accessible interior; keeping its floor closed for safety.")
    end

    local frame = CFrame.new(berth)
    local hull = collisionPart(model, "Hull", vector(Config.HullSize) * Config.ArtScale, frame)
    hull.EnableFluidForces = true
    model.PrimaryPart = hull
    if interior then
        authoredCollision(model, imported, frame)
    else
        for _, spec in ipairs(Config.deckPanels(false)) do deckPanel(model, frame, spec) end
        for _, spec in ipairs(Config.Ramps) do deckPanel(model, frame, spec) end
    end
    if interior then
        -- Smooth walk surfaces cover the risers, while authored treads match the art.
        local panels = Config.interiorPanels()
        deckPanel(model, frame, panels[#panels])
        for _, spec in ipairs(Config.Ramps) do deckPanel(model, frame, spec) end
        for index, position in ipairs(Config.interiorLights()) do
            local attachment = Instance.new("Attachment")
            attachment.Name, attachment.Position, attachment.Parent = "InteriorLantern" .. index,
                sourcePoint(vector(position)), hull
            local light = Instance.new("PointLight")
            light.Color, light.Brightness, light.Range = Color3.fromRGB(255, 210, 145), 1.2, 15
            light.Shadows, light.Parent = false, attachment
        end
    end
    local wheel = sourcePoint(vector(interior and Config.WheelPosition or Config.LegacyWheelPosition))
    local wheelAnchor = Instance.new("Attachment")
    wheelAnchor.Name, wheelAnchor.Position, wheelAnchor.Parent = "WheelAnchor", wheel, hull
    local floorY = interior and Config.HelmFloorY or Config.LegacyHelmFloorY
    local helm = Vector3.new(wheel.X, (floorY + Config.VisualOffset[2]) * Config.ArtScale + 0.25,
        wheel.Z + Config.HelmBehindWheel)
    local seat = Instance.new("VehicleSeat")
    seat.Name, seat.Size, seat.Anchored = "Helm", Vector3.new(2.2, 0.5, 2.2), true
    seat.CFrame, seat.Transparency = frame * CFrame.lookAt(helm, Vector3.new(wheel.X, helm.Y, wheel.Z)), 1
    seat.HeadsUpDisplay = false
    seat.MaxSpeed, seat.Torque, seat.TurnSpeed = 0, 0, 0
    seat.Parent = model
    model:SetAttribute("ShipVisual", Config.TemplateName)
    model:SetAttribute("VisualScale", Config.ArtScale)
    model:SetAttribute("InteriorAccessible", interior)
    model:SetAttribute("InteriorRevision", interior and Config.InteriorRevision or 0)
    model:SetAttribute("AssetRevision", sealedStern and 3 or (interior and 2 or 1))
    return hull, seat
end

function Visual.bind(rig)
    local sails, rudders = {}, {}
    for p, joint in pairs(rig.movingJoints) do
        local role = p:GetAttribute("SailingRole")
        local entry = {part = p, joint = joint, size = p.Size, c0 = joint.C0}
        if role == "SailMesh" then
            local axes = {joint.C0.RightVector, joint.C0.UpVector, joint.C0.ZVector}
            local best, alignment = 1, 0
            for index, axis in ipairs(axes) do
                if math.abs(axis.Y) > alignment then best, alignment = index, math.abs(axis.Y) end
            end
            entry.axis = best
            entry.height = ({p.Size.X, p.Size.Y, p.Size.Z})[best]
            entry.verticalAlignment = alignment
            table.insert(sails, entry)
        elseif role == "Rudder" then
            table.insert(rudders, entry)
        end
    end
    local stock = rig.hull.Parent:FindFirstChild("Frigate_Rudder_Stock", true)
    assert(stock and stock:IsA("BasePart"), "Frigate rudder stock missing")
    local axis = Vector3.new(0, 1, 0.115).Unit
    local hinge = CFrame.fromMatrix(rig.hull.CFrame:PointToObjectSpace(stock.Position), Vector3.xAxis,
        axis, Vector3.xAxis:Cross(axis))
    for _, entry in ipairs(rudders) do
        local c1 = entry.part.CFrame:ToObjectSpace(rig.hull.CFrame * hinge)
        entry.joint.Part1 = nil
        entry.joint.C0 = hinge
        entry.joint.C1 = c1
        entry.joint.Part1 = entry.part
        entry.c0 = hinge
    end
    rig.frigate = {sails = sails, rudders = rudders, rudderHinge = hinge}
    Visual.update(rig, 0, 0)
end

function Visual.update(rig, deployment, steer)
    local visual = rig.frigate
    if not visual then return end
    if visual.deployment ~= deployment then
        for _, entry in ipairs(visual.sails) do
            local height, lift = Config.sailPose(entry.height, deployment)
            local values = {entry.size.X, entry.size.Y, entry.size.Z}
            values[entry.axis] = height
            entry.part.Size = vector(values)
            entry.joint.C0 = CFrame.new(0, lift * entry.verticalAlignment, 0) * entry.c0
        end
        visual.deployment = deployment
    end
    if visual.steer ~= steer then
        local turn = visual.rudderHinge * CFrame.Angles(0, Config.rudderAngle(steer), 0)
        for _, entry in ipairs(visual.rudders) do entry.joint.C0 = turn end
        visual.steer = steer
    end
end

return Visual
