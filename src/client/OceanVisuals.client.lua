local RunService = game:GetService("RunService")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("PirateOcean")
local Config = require(shared.WorldConfig)
local boats = workspace:WaitForChild("PirateOceanWorld"):WaitForChild("Boats")
local effects = {}

local function build(model)
    local hull = model:FindFirstChild("Hull")
    if not hull then return nil end
    local fx = {hull = hull, attachments = {}, trails = {}, joints = {}, time = 0}
    for _, name in ipairs({"LeftOarJoint", "RightOarJoint"}) do
        local joint = hull:FindFirstChild(name)
        if joint then table.insert(fx.joints, joint) end
    end
    for _, side in ipairs({-1, 1}) do
        local pair = {}
        for _, offset in ipairs({-1.5, 1.5}) do
            local attachment = Instance.new("Attachment")
            attachment.Name = "WakeAttachment"
            attachment.Position = Vector3.new(side * hull.Size.X * 0.46 + offset, -hull.Position.Y + Config.Water.SurfaceY + 0.12, hull.Size.Z * 0.45)
            attachment.Parent = hull
            table.insert(pair, attachment)
            table.insert(fx.attachments, attachment)
        end
        local trail = Instance.new("Trail")
        trail.Name, trail.Attachment0, trail.Attachment1 = "FoamWake", pair[1], pair[2]
        trail.Color = ColorSequence.new(Color3.fromRGB(223, 240, 236))
        trail.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1)})
        trail.WidthScale = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1)})
        trail.Texture = "rbxasset://textures/particles/smoke_main.dds"
        trail.Lifetime, trail.MinLength, trail.FaceCamera = 1.6, 0.2, false
        trail.Enabled, trail.Parent = false, hull
        table.insert(fx.trails, trail)
    end
    local spray = Instance.new("ParticleEmitter")
    spray.Name, spray.Texture = "WakeSpray", "rbxasset://textures/particles/smoke_main.dds"
    spray.Color = ColorSequence.new(Color3.fromRGB(235, 248, 245))
    spray.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 2.5)})
    spray.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.65), NumberSequenceKeypoint.new(1, 1)})
    spray.Lifetime, spray.Speed = NumberRange.new(0.5, 1.1), NumberRange.new(0.3, 1)
    spray.SpreadAngle, spray.Rate, spray.LightInfluence = Vector2.new(50, 50), 0, 0.4
    spray.Parent = fx.attachments[1]
    fx.spray = spray
    return fx
end

RunService.PreSimulation:Connect(function(dt)
    for model, fx in pairs(effects) do
        if not model.Parent then
            for _, attachment in ipairs(fx.attachments) do attachment:Destroy() end
            for _, trail in ipairs(fx.trails) do trail:Destroy() end
            effects[model] = nil
        end
    end
    for _, model in ipairs(boats:GetChildren()) do
        local fx = effects[model]
        if not fx then fx = build(model) effects[model] = fx end
        if not fx then continue end
        if #fx.joints < 2 then
            fx.joints = {}
            for _, name in ipairs({"LeftOarJoint", "RightOarJoint"}) do
                local joint = fx.hull:FindFirstChild(name)
                if joint then table.insert(fx.joints, joint) end
            end
        end
        local camera = workspace.CurrentCamera
        local visible = camera and (camera.CFrame.Position - fx.hull.Position).Magnitude < 300
        local velocity = fx.hull.AssemblyLinearVelocity
        local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
        local active = visible and model:GetAttribute("InVoyage") and speed > 2 and fx.hull.Position.Y < 3
        for _, attachment in ipairs(fx.attachments) do
            local pos = attachment.Position
            attachment.Position = Vector3.new(pos.X, Config.Water.SurfaceY - fx.hull.Position.Y + 0.12, pos.Z)
        end
        for _, trail in ipairs(fx.trails) do trail.Enabled = active == true end
        fx.spray.Rate = active and math.min(35, speed * 1.2) or 0
        fx.time += dt
        for _, joint in ipairs(fx.joints) do
            local side = joint.Name == "LeftOarJoint" and -1 or 1
            local angle = visible and model:GetAttribute("Paddling") and math.sin(fx.time * 5) * 0.4 or 0
            joint.Transform = CFrame.Angles(0, side * angle, side * math.abs(angle) * 0.3)
        end
    end
end)
