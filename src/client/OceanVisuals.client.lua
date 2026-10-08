local RunService = game:GetService("RunService")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("PirateOcean")
local Config = require(shared.WorldConfig)
local Ocean = require(shared.OceanConfig)
local Wave = require(shared.Util.WaveMotion)
local boats = workspace:WaitForChild("PirateOceanWorld"):WaitForChild("Boats")
local effects = {}
local TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local function splash(attachment, name, foam)
    local p = Instance.new("ParticleEmitter")
    p.Name, p.Texture, p.Rate = name, TEXTURE, 0
    p.Color = ColorSequence.new(Color3.fromRGB(218, 240, 242), Color3.fromRGB(250, 255, 255))
    p.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)})
    p.Size = foam and NumberSequence.new({NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.8)})
        or NumberSequence.new({NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(0.3, 0.22), NumberSequenceKeypoint.new(1, 0)})
    p.Lifetime = foam and NumberRange.new(0.8, 1.5) or NumberRange.new(0.4, 0.9)
    p.Speed = foam and NumberRange.new(0.2, 1.2) or NumberRange.new(3, 8)
    p.Acceleration = foam and Vector3.zero or Vector3.new(0, -15, 0)
    p.Drag, p.SpreadAngle, p.LightInfluence = foam and 2 or 0.5, Vector2.new(60, 60), 0.35
    p.Parent = attachment
    return p
end

local function build(model)
    local hull = model:FindFirstChild("Hull")
    if not hull or not model:GetAttribute("SailingRigReady") then return nil end
    local fx = {hull = hull, attachments = {}, trails = {}, joints = {}, contacts = {}, time = 0, checkTime = 0}
    fx.raycast = RaycastParams.new()
    fx.raycast.FilterType, fx.raycast.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, {model}
    fx.raycast.IgnoreWater = false
    for _, name in ipairs({"LeftOarJoint", "RightOarJoint"}) do
        local joint = hull:FindFirstChild(name)
        if joint then table.insert(fx.joints, joint) end
    end
    for _, side in ipairs({-1, 1}) do
        local pair = {}
        for _, offset in ipairs({-0.1, 0.1}) do
            local attachment = Instance.new("Attachment")
            attachment.Name = "WakeAttachment"
            attachment.Position = Vector3.new((side * 0.46 + offset) * hull.Size.X, 0, hull.Size.Z * 0.45)
            attachment.Parent = hull
            table.insert(pair, attachment)
            table.insert(fx.attachments, attachment)
        end
        local trail = Instance.new("Trail")
        trail.Name, trail.Attachment0, trail.Attachment1 = "FoamWake", pair[1], pair[2]
        trail.Color = ColorSequence.new(Color3.fromRGB(223, 240, 236))
        trail.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1)})
        trail.WidthScale = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1)})
        trail.Texture, trail.Lifetime, trail.MinLength, trail.FaceCamera = TEXTURE, 2.4, 0.2, false
        trail.Enabled, trail.Parent = false, hull
        table.insert(fx.trails, trail)
        for _, position in ipairs({{side * 0.4, -0.44, true}, {side * 0.5, -0.1, false}}) do
            local attachment = Instance.new("Attachment")
            attachment.Name, attachment.Parent = position[3] and "BowContact" or "SideContact", hull
            local contact = {attachment = attachment, x = position[1] * hull.Size.X,
                z = position[2] * hull.Size.Z, bow = position[3], cooldown = 0, wet = false}
            contact.spray = splash(attachment, "HullSplash", false)
            contact.foam = splash(attachment, "HullFoam", true)
            table.insert(fx.contacts, contact)
            table.insert(fx.attachments, attachment)
        end
    end
    return fx
end

local function waterPoint(hull, x, z)
    local cf = hull.CFrame
    local y = Wave.waterLocalY(Config.Water.SurfaceY + 0.12, cf.Position.Y,
        cf.RightVector.Y, cf.UpVector.Y, cf.ZVector.Y, x, z)
    return cf * Vector3.new(x, y, z)
end

RunService.PreSimulation:Connect(function(dt)
    for model, fx in pairs(effects) do
        if not model.Parent then
            for _, attachment in ipairs(fx.attachments) do attachment:Destroy() end
            for _, trail in ipairs(fx.trails) do trail:Destroy() end
            effects[model] = nil
        end
    end
    local now = workspace:GetServerTimeNow()
    for _, model in ipairs(boats:GetChildren()) do
        local fx = effects[model]
        if not fx then fx = build(model) effects[model] = fx end
        if not fx then continue end
        local hull = fx.hull
        local camera = workspace.CurrentCamera
        local visible = camera and (camera.CFrame.Position - hull.Position).Magnitude < Ocean.Effects.distance
        local velocity = hull.AssemblyLinearVelocity
        local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
        local nearWater = hull.Position.Y - hull.Size.Y / 2 < Config.Water.SurfaceY + 1 and hull.Position.Y > -20
        local active = visible and nearWater
        local cruising = active and model:GetAttribute("InVoyage") and speed > 2
        for _, trail in ipairs(fx.trails) do trail.Enabled = cruising == true end
        fx.checkTime += dt
        local checkWater = fx.checkTime >= Ocean.Effects.contactInterval
        if checkWater then fx.checkTime = 0 end
        if checkWater and not model:GetAttribute("ShipVisual") and #fx.joints < 2 then
            fx.joints = {}
            for _, name in ipairs({"LeftOarJoint", "RightOarJoint"}) do
                local joint = hull:FindFirstChild(name)
                if joint then table.insert(fx.joints, joint) end
            end
        end
        if active then
            for _, attachment in ipairs(fx.attachments) do
                if attachment.Name == "WakeAttachment" then
                    local pos = attachment.Position
                    attachment.Position = hull.CFrame:PointToObjectSpace(waterPoint(hull, pos.X, pos.Z))
                end
            end
        end
        for _, contact in ipairs(fx.contacts) do
            contact.cooldown = math.max(0, contact.cooldown - dt)
            local impact = 0
            if active then
                local point = waterPoint(hull, contact.x, contact.z)
                contact.attachment.CFrame = hull.CFrame:ToObjectSpace(CFrame.new(point))
                if checkWater then
                    local hit = workspace:Raycast(point + Vector3.new(0, 2, 0), Vector3.new(0, -4, 0), fx.raycast)
                    contact.wet = hit ~= nil and hit.Material == Enum.Material.Water
                end
                local _, waveVelocity = Wave.sample(point.X, point.Z, now, Ocean.Swells)
                local rollVelocity = hull.CFrame:VectorToObjectSpace(hull.AssemblyAngularVelocity).Z
                impact = Wave.impact(waveVelocity, velocity.Y, rollVelocity, hull.Size.X)
            end
            local wet = active and contact.wet
            local motion = wet and math.min(speed, 30) or 0
            contact.spray.Rate = wet and math.min(Ocean.Effects.maxSprayRate, impact * 14 + (contact.bow and motion * 1.5 or motion * 0.35)) or 0
            contact.foam.Rate = wet and math.min(25, impact * 8 + motion * 0.45) or 0
            if wet and impact > 0.45 and contact.cooldown == 0 then
                contact.spray:Emit(math.floor(math.min(14, 4 + impact * 8)))
                contact.foam:Emit(4)
                contact.cooldown = Ocean.Effects.burstCooldown
            end
        end
        fx.time += dt
        for _, joint in ipairs(fx.joints) do
            local side = joint.Name == "LeftOarJoint" and -1 or 1
            local angle = visible and model:GetAttribute("Paddling") and math.sin(fx.time * 5) * 0.4 or 0
            joint.Transform = CFrame.Angles(0, side * angle, side * math.abs(angle) * 0.3)
        end
    end
end)
