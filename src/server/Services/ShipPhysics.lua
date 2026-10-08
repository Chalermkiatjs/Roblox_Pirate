local shared = game:GetService("ReplicatedStorage"):WaitForChild("PirateOcean")
local Config = require(shared.WorldConfig)
local Motion = require(shared.Util.BoatMotion)
local Navigation = require(shared.Util.WorldNavigation)
local Sailing = require(shared.SailingConfig)
local Ocean = require(shared.OceanConfig)
local Wave = require(shared.Util.WaveMotion)
local Physics = {}

function Physics.attach(model, hull)
    hull.RootPriority = 127
    hull.CustomPhysicalProperties = PhysicalProperties.new(Config.Sailing.HullDensity, 0.4, 0, 1, 1)
    -- Redistribute existing hull mass to low, slightly aft ballast without adding weight.
    local sailJoint, sailPart
    local movingJoints = {}
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") and p ~= hull then
            p.Massless = true
            p.CustomPhysicalProperties = PhysicalProperties.new(0.01, 0.4, 0, 1, 1)
            if p.Name ~= "Deck" and p.Name ~= "Helm" and not p:GetAttribute("ShipCollision") then p.CanCollide = false end
            p.EnableFluidForces = false
            local role = p:GetAttribute("SailingRole")
            local moving = p.Name == "Sail" or p.Name == "LeftOar" or p.Name == "RightOar"
                or role == "SailMesh" or role == "Rudder"
            local weld = Instance.new(moving and "Motor6D" or "WeldConstraint")
            if moving then
                weld.Name = p.Name .. "Joint"
                weld.C0 = hull.CFrame:ToObjectSpace(p.CFrame)
                movingJoints[p] = weld
                if p.Name == "Sail" then sailJoint, sailPart = weld, p end
            end
            local follow = p:GetAttribute("CollisionFollow")
            local anchor = hull
            if follow then anchor = model:FindFirstChild(follow, true) end
            assert(anchor and anchor:IsA("BasePart"), "Collision follow target missing: " .. tostring(follow))
            weld.Part0, weld.Part1, weld.Parent = anchor, p, hull
            p.Anchored = false
        end
    end
    local mass = hull:GetMass()
    local ballast = Instance.new("Part")
    ballast.Name = "SailingBallast"
    ballast.Size = Vector3.new(hull.Size.X * 0.65, hull.Size.Y * 0.35, hull.Size.Z * 0.45)
    ballast.CFrame = hull.CFrame * CFrame.new(0, -hull.Size.Y * Config.Sailing.BallastDepth,
        hull.Size.Z * Config.Sailing.BallastAft)
    ballast.Transparency, ballast.CanCollide, ballast.CanTouch, ballast.CanQuery = 1, false, false, false
    ballast.EnableFluidForces = false
    local volume = ballast.Size.X * ballast.Size.Y * ballast.Size.Z
    ballast.CustomPhysicalProperties = PhysicalProperties.new(mass * Config.Sailing.BallastFraction / volume, 0.4, 0, 1, 1)
    hull.CustomPhysicalProperties = PhysicalProperties.new(Config.Sailing.HullDensity
        * (1 - Config.Sailing.BallastFraction), 0.4, 0, 1, 1)
    ballast.Parent = model
    local ballastWeld = Instance.new("WeldConstraint")
    ballastWeld.Part0, ballastWeld.Part1, ballastWeld.Parent = hull, ballast, ballast
    local attachment = Instance.new("Attachment")
    attachment.Name, attachment.Parent = "SailingAttachment", hull
    local thrust = Instance.new("VectorForce")
    thrust.Name, thrust.Attachment0 = "SailingForce", attachment
    thrust.RelativeTo, thrust.ApplyAtCenterOfMass = Enum.ActuatorRelativeTo.World, true
    thrust.Force, thrust.Parent = Vector3.zero, hull
    local function lateralForce(name, z)
        local point = Instance.new("Attachment")
        point.Name, point.Position, point.Parent = name .. "Attachment", Vector3.new(0, 0, z), hull
        local force = Instance.new("VectorForce")
        force.Name, force.Attachment0 = name, point
        force.RelativeTo, force.ApplyAtCenterOfMass = Enum.ActuatorRelativeTo.World, false
        force.Force, force.Parent = Vector3.zero, hull
        return force, point
    end
    local rudderForce, rudderPoint = lateralForce("RudderForce", hull.Size.Z * 0.46)
    local lateralDrag, dragPoint = lateralForce("KeelDrag", -hull.Size.Z * Config.Sailing.KeelForwardOffset)
    local yawDrag = Instance.new("Torque")
    yawDrag.Name, yawDrag.Attachment0 = "YawDrag", attachment
    yawDrag.RelativeTo, yawDrag.Torque, yawDrag.Parent = Enum.ActuatorRelativeTo.World, Vector3.zero, hull
    local tiltAttachment = Instance.new("Attachment")
    tiltAttachment.Name, tiltAttachment.CFrame, tiltAttachment.Parent = "TiltAttachment",
        CFrame.Angles(0, 0, math.pi / 2), hull
    local stabilizer = Instance.new("AlignOrientation")
    stabilizer.Name, stabilizer.Attachment0 = "SailingOrientation", tiltAttachment
    stabilizer.Mode = Enum.OrientationAlignmentMode.OneAttachment
    stabilizer.AlignType = Enum.AlignType.PrimaryAxisParallel
    stabilizer.RigidityEnabled = false
    stabilizer.Responsiveness = 6
    stabilizer.MaxAngularVelocity = 1.5
    stabilizer.CFrame, stabilizer.Parent = tiltAttachment.CFrame, hull
    model:SetAttribute("SailingRigReady", true)
    return {hull = hull, thrust = thrust, stabilizer = stabilizer, active = false, yaw = 0,
        rudder = 0, rudderForce = rudderForce, rudderPoint = rudderPoint,
        lateralDrag = lateralDrag, dragPoint = dragPoint, yawDrag = yawDrag, tiltAttachment = tiltAttachment,
        rocking = {pitch = 0, roll = 0, pitchVelocity = 0, rollVelocity = 0},
        stage = 0, deployment = 0, sailJoint = sailJoint, sailPart = sailPart, movingJoints = movingJoints}
end

local function clearForces(rig)
    rig.thrust.Force, rig.rudderForce.Force, rig.lateralDrag.Force = Vector3.zero, Vector3.zero, Vector3.zero
    rig.yawDrag.Torque = Vector3.zero
end

function Physics.setActive(rig, active)
    if rig.active == active then return end
    rig.active = active
    rig.hull.Anchored = not active
    if active then rig.hull:SetNetworkOwner(nil) end
    clearForces(rig)
    rig.rudder = 0
    rig.rocking.pitch, rig.rocking.roll = 0, 0
    rig.rocking.pitchVelocity, rig.rocking.rollVelocity = 0, 0
    rig.hull.AssemblyLinearVelocity = Vector3.zero
    rig.hull.AssemblyAngularVelocity = Vector3.zero
end

function Physics.reset(rig)
    rig.yaw = 0
    clearForces(rig)
    rig.rudder = 0
    rig.rocking.pitch, rig.rocking.roll = 0, 0
    rig.rocking.pitchVelocity, rig.rocking.rollVelocity = 0, 0
    rig.stabilizer.CFrame = rig.tiltAttachment.CFrame
    rig.hull.AssemblyLinearVelocity = Vector3.zero
    rig.hull.AssemblyAngularVelocity = Vector3.zero
    rig.stage, rig.deployment = 0, 0
end

function Physics.update(rig, dt, throttle, steer, speed, navigationBounds)
    local hull = rig.hull
    -- Terrain water supplies buoyancy; propulsion never applies vertical lift.
    if hull.Position.Y > Config.Water.SurfaceY + hull.Size.Y then
        clearForces(rig)
        return
    end
    local look = hull.CFrame.LookVector
    rig.yaw = math.atan2(-look.X, -look.Z)
    local heading = CFrame.Angles(0, rig.yaw, 0)
    rig.rudder = Motion.rudder(rig.rudder, steer, dt, Config.Sailing.RudderResponse)
    local desired = Sailing.Stages[rig.stage].deployment
    local step = dt / Sailing.DeployTime
    rig.deployment += math.clamp(desired - rig.deployment, -step, step)
    local windAlignment = heading.LookVector.X * Sailing.WindX + heading.LookVector.Z * Sailing.WindZ
    local velocity = hull.AssemblyLinearVelocity
    local forwardSpeed = velocity:Dot(heading.LookVector)
    local targetSpeed = speed * Sailing.stageSpeedMultiplier(rig.stage, rig.deployment, windAlignment)
    if navigationBounds then
        targetSpeed = Navigation.limitSpeed(hull.Position.X, hull.Position.Z, heading.LookVector.X,
            heading.LookVector.Z, targetSpeed, navigationBounds, Config.Sailing.Acceleration,
            Config.Sailing.ResponseTime)
    end
    local acceleration = Motion.acceleration(forwardSpeed, 0, targetSpeed, 0,
        Config.Sailing.ResponseTime, Config.Sailing.Acceleration)
    local massNow = hull.AssemblyMass
    rig.thrust.Force = heading.LookVector * acceleration * massNow
    local center = hull.CFrame:PointToObjectSpace(hull.AssemblyCenterOfMass)
    rig.rudderPoint.Position = Vector3.new(0, center.Y, hull.Size.Z * 0.46)
    rig.dragPoint.Position = Vector3.new(center.X, center.Y,
        center.Z - hull.Size.Z * Config.Sailing.KeelForwardOffset)
    local sideAcceleration, damping = Motion.turning(forwardSpeed, hull.AssemblyAngularVelocity.Y,
        rig.rudder, hull.Size.X, hull.Size.Z, rig.rudderPoint.Position.Z - center.Z, Config.Sailing)
    rig.rudderForce.Force = heading.RightVector * sideAcceleration * massNow
    rig.yawDrag.Torque = Vector3.new(0, damping * massNow, 0)
    local lateralSpeed = hull:GetVelocityAtPosition(rig.dragPoint.WorldPosition):Dot(heading.RightVector)
    rig.lateralDrag.Force = -heading.RightVector * math.clamp(lateralSpeed / Config.Sailing.LateralResponse,
        -Config.Sailing.Acceleration, Config.Sailing.Acceleration) * massNow
    rig.stabilizer.MaxTorque = hull.AssemblyMass * workspace.Gravity * hull.Size.X * 3
    local speedNow = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
    local pitch, roll = Wave.rocking(rig.rocking, dt, hull.Position.X, hull.Position.Z, workspace:GetServerTimeNow(),
        rig.yaw, hull.Size.X, hull.Size.Z, rig.rudder, speedNow, Ocean.Swells, Ocean.Rocking)
    rig.stabilizer.CFrame = heading * CFrame.Angles(pitch, 0, roll) * rig.tiltAttachment.CFrame
end

return Physics
