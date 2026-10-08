local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("PirateOcean")
local Config = require(shared.MovesetConfig)
local Pose = require(shared.Util.MovesetPose)
local Orientation = require(shared.Util.MovesetOrientation)
local actors = {}
local names = {
    ["Right Shoulder"] = "right", RightShoulder = "right",
    ["Left Shoulder"] = "left", LeftShoulder = "left",
    RootJoint = "torso", Waist = "torso",
}

local function restore(actor)
    for motor, base in pairs(actor.applied) do
        if motor.Parent then motor.Transform = base end
    end
    table.clear(actor.applied)
end

local function add(model)
    if actors[model] then return end
    local actor = {joints = {}, applied = {}, weights = {}}
    actors[model] = actor
    local function joint(item)
        if (item:IsA("Motor6D") or item:IsA("AnimationConstraint")) and names[item.Name] then
            actor.joints[item] = names[item.Name]
        end
    end
    for _, item in ipairs(model:GetDescendants()) do joint(item) end
    actor.connection = model.DescendantAdded:Connect(joint)
end

local function remove(model)
    local actor = actors[model]
    if not actor then return end
    restore(actor)
    actor.connection:Disconnect()
    actors[model] = nil
end

CollectionService:GetInstanceAddedSignal(Config.Tag):Connect(add)
CollectionService:GetInstanceRemovedSignal(Config.Tag):Connect(remove)
for _, model in ipairs(CollectionService:GetTagged(Config.Tag)) do add(model) end

-- Remove last frame's additive pose before Roblox evaluates native animations.
local preAnimation = RunService.PreAnimation:Connect(function()
    for _, actor in pairs(actors) do restore(actor) end
end)

local preSimulation = RunService.PreSimulation:Connect(function(dt)
    local now = workspace:GetServerTimeNow()
    for model, actor in pairs(actors) do
        if not model:IsDescendantOf(workspace) then
            remove(model)
            continue
        end
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        local tool = model:FindFirstChild("Cutlass")
        local name = model:GetAttribute("MovesetName") or "None"
        local enabled = humanoid and humanoid.Health > 0 and not humanoid.Sit
            and tool and tool:GetAttribute("PirateOceanWeapon") and name ~= "None"
        local asset = model:GetAttribute("MovesetAsset") or 0
        local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
        local mirrorNative = false
        if enabled and asset > 0 and animator then
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                if track.Animation and track.Animation.AnimationId == "rbxassetid://" .. asset and track.Length > 0 then
                    enabled = false
                    mirrorNative = model:GetAttribute("MovesetMirrorForward") == true
                    break
                end
            end
        end
        local sample = Pose.sample(name, now - (model:GetAttribute("MovesetStarted") or now),
            model:GetAttribute("MovesetWindup") or 0, model:GetAttribute("MovesetDuration") or 0)
        local alpha = 1 - math.exp(-dt / Config.FadeTime)
        for motor, role in pairs(actor.joints) do
            if not motor.Parent then
                actor.joints[motor], actor.weights[motor] = nil, nil
                continue
            end
            local attachment = motor:IsA("AnimationConstraint") and motor.Attachment0
            if motor:IsA("AnimationConstraint") and not attachment then continue end
            local bind = motor:IsA("Motor6D") and motor.C0.Rotation or attachment.CFrame.Rotation
            if mirrorNative then
                local original = motor.Transform
                local anatomical = bind * original * bind:Inverse()
                local mirrored = CFrame.new(table.unpack(Orientation.mirrorForward({anatomical:GetComponents()})))
                actor.applied[motor] = original
                motor.Transform = bind:Inverse() * mirrored * bind
                actor.weights[motor] = 0
                continue
            end
            local angles = enabled and sample[role] or {0, 0, 0}
            local target = CFrame.Angles(math.rad(angles[1]), math.rad(angles[2]), math.rad(angles[3]))
            local weight = actor.weights[motor] or 0
            weight += ((enabled and 1 or 0) - weight) * alpha
            actor.weights[motor] = weight
            if not enabled and weight < 0.001 then
                actor.weights[motor] = 0
                continue
            end
            -- R6 shoulders/root have different bind axes from R15 and our NPC rig.
            local offset = bind:Inverse() * CFrame.new():Lerp(target, weight) * bind
            actor.applied[motor] = motor.Transform
            motor.Transform *= offset
        end
    end
end)

script.Destroying:Connect(function()
    preAnimation:Disconnect()
    preSimulation:Disconnect()
    for model in pairs(actors) do remove(model) end
end)
