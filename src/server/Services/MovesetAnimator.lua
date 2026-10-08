local CollectionService = game:GetService("CollectionService")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("PirateOcean")
local Config = require(shared.MovesetConfig)
local Moveset = {}

function Moveset.attach(actor)
    local animator = actor.humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = actor.humanoid
    end
    actor.animator, actor.moveTracks = animator, {}
    CollectionService:AddTag(actor.model, Config.Tag)
end

function Moveset.play(actor, name, duration, windup)
    if actor.moveTrack then actor.moveTrack:Stop(Config.FadeTime) end
    actor.moveTrack = nil
    local model = actor.model
    model:SetAttribute("MovesetStarted", workspace:GetServerTimeNow())
    model:SetAttribute("MovesetDuration", duration or 0)
    model:SetAttribute("MovesetWindup", windup or 0)
    model:SetAttribute("MovesetName", name)
    local rig = actor.humanoid.RigType == Enum.HumanoidRigType.R15 and "R15" or "R6"
    local clip = Config[rig][name]
    model:SetAttribute("MovesetAsset", clip and clip.Id or 0)
    model:SetAttribute("MovesetMirrorForward", clip and clip.MirrorForward == true or false)
    if not clip or clip.Id == 0 then return end
    local track = actor.moveTracks[name]
    if track == false then return end
    if not track then
        local animation = Instance.new("Animation")
        animation.AnimationId = "rbxassetid://" .. clip.Id
        local ok, loaded = pcall(function() return actor.animator:LoadAnimation(animation) end)
        animation:Destroy()
        if not ok then
            actor.moveTracks[name] = false
            warn("Moveset clip failed: " .. name .. " / " .. tostring(loaded))
            return
        end
        track, actor.moveTracks[name] = loaded, loaded
    end
    track.Priority = name == "Idle" and Enum.AnimationPriority.Action or Enum.AnimationPriority.Action2
    track.Looped = name == "Idle" or name == "Guard"
    track:Play(Config.FadeTime, 1, clip.HitTime and windup and clip.HitTime / math.max(windup, 0.01) or 1)
    actor.moveTrack = track
end

function Moveset.update(actor)
    if (actor.model:GetAttribute("MovesetDuration") or 0) > 0 then
        local elapsed = workspace:GetServerTimeNow() - (actor.model:GetAttribute("MovesetStarted") or 0)
        if elapsed >= (actor.model:GetAttribute("MovesetDuration") or 0) then
            Moveset.play(actor, actor.state.blocking and "Guard" or "Idle")
        end
    end
end

function Moveset.destroy(actor)
    if actor.moveTrack then actor.moveTrack:Stop(0) end
    for _, track in pairs(actor.moveTracks or {}) do
        if track then track:Destroy() end
    end
    actor.moveTracks = {}
    CollectionService:RemoveTag(actor.model, Config.Tag)
end

return Moveset
