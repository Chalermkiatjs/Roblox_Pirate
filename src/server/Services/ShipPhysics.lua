local shared = game:GetService("ReplicatedStorage"):WaitForChild("PirateOcean")
local Config = require(shared.WorldConfig)
local Motion = require(shared.Util.BoatMotion)
local Sailing = require(shared.SailingConfig)
local Physics = {}

function Physics.attach(model, hull)
    hull.RootPriority = 127
    hull.CustomPhysicalProperties = PhysicalProperties.new(Config.Sailing.HullDensity, 0.4, 0, 1, 1)
    -- One rigid assembly: only the hull contributes significant mass.
    local sailJoint, sailPart
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") and p ~= hull then
            p.Massless = true
            p.CustomPhysicalProperties = PhysicalProperties.new(0.01, 0.4, 0, 1, 1)
            if p.Name ~= "Deck" and p.Name ~= "Helm" then p.CanCollide = false end
            local moving = p.Name == "Sail" or p.Name == "LeftOar" or p.Name == "RightOar"
            local weld = Instance.new(moving and "Motor6D" or "WeldConstraint")
            if moving then
                weld.Name = p.Name .. "Joint"
                weld.C0 = hull.CFrame:ToObjectSpace(p.CFrame)
                if p.Name == "Sail" then sailJoint, sailPart = weld, p end
            end
            weld.Part0, weld.Part1, weld.Parent = hull, p, hull
            p.Anchored = false
        end
    end
    local attachment = Instance.new("Attachment")
    attachment.Name, attachment.Parent = "SailingAttachment", hull
    local thrust = Instance.new("VectorForce")
    thrust.Name, thrust.Attachment0 = "SailingForce", attachment
    thrust.RelativeTo, thrust.ApplyAtCenterOfMass = Enum.ActuatorRelativeTo.World, true
    thrust.Force, thrust.Parent = Vector3.zero, hull
    local stabilizer = Instance.new("AlignOrientation")
    stabilizer.Name, stabilizer.Attachment0 = "SailingOrientation", attachment
    stabilizer.Mode = Enum.OrientationAlignmentMode.OneAttachment
    stabilizer.RigidityEnabled = false
    stabilizer.Responsiveness = 6
    stabilizer.MaxAngularVelocity = 1.5
    stabilizer.CFrame, stabilizer.Parent = CFrame.identity, hull
    return {hull = hull, thrust = thrust, stabilizer = stabilizer, active = false, yaw = 0,
        stage = 0, deployment = 0, sailJoint = sailJoint, sailPart = sailPart}
end

function Physics.setActive(rig, active)
    if rig.active == active then return end
    rig.active = active
    rig.hull.Anchored = not active
    if active then rig.hull:SetNetworkOwner(nil) end
    rig.thrust.Force = Vector3.zero
    rig.hull.AssemblyLinearVelocity = Vector3.zero
    rig.hull.AssemblyAngularVelocity = Vector3.zero
end

function Physics.reset(rig)
    rig.yaw = 0
    rig.thrust.Force = Vector3.zero
    rig.stabilizer.CFrame = CFrame.identity
    rig.hull.AssemblyLinearVelocity = Vector3.zero
    rig.hull.AssemblyAngularVelocity = Vector3.zero
    rig.stage, rig.deployment = 0, 0
end

function Physics.update(rig, dt, throttle, steer, speed)
    local hull = rig.hull
    -- Terrain water supplies buoyancy; propulsion never applies vertical lift.
    if hull.Position.Y > Config.Water.SurfaceY + hull.Size.Y then
        rig.thrust.Force = Vector3.zero
        return
    end
    rig.yaw -= steer * dt * Config.Sailing.TurnSpeed
    local heading = CFrame.Angles(0, rig.yaw, 0)
    local desired = Sailing.Stages[rig.stage].deployment
    local step = dt / Sailing.DeployTime
    rig.deployment += math.clamp(desired - rig.deployment, -step, step)
    local windAlignment = heading.LookVector.X * Sailing.WindX + heading.LookVector.Z * Sailing.WindZ
    local target = heading.LookVector * speed * Sailing.speedMultiplier(rig.deployment, throttle, windAlignment)
    local velocity = hull.AssemblyLinearVelocity
    local ax, az = Motion.acceleration(velocity.X, velocity.Z, target.X, target.Z,
        Config.Sailing.ResponseTime, Config.Sailing.Acceleration)
    rig.thrust.Force = Vector3.new(ax, 0, az) * hull.AssemblyMass
    rig.stabilizer.MaxTorque = hull.AssemblyMass * workspace.Gravity * hull.Size.X * 3
    rig.stabilizer.CFrame = heading
end

return Physics
