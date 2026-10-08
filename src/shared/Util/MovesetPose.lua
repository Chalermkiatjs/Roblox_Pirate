local Pose = {}
local function blend(a, b, t)
    local result = {}
    for i = 1, 3 do result[i] = a[i] + (b[i] - a[i]) * t end
    return result
end
local function smooth(t)
    t = math.clamp(t, 0, 1)
    return t * t * (3 - 2 * t)
end
-- Roblox forward is -Z: positive shoulder X lifts the downward arm forward.
local idle = {right = {25, 0, 12}, left = {12, 0, -8}, torso = {0, 8, 0}}
local guard = {right = {75, 25, 30}, left = {55, -25, -25}, torso = {0, 18, 0}}
local moves = {
    Slash = {
        {right = {60, 40, 75}, left = {25, 0, -20}, torso = {0, 35, -5}},
        {right = {45, -40, -50}, left = {20, 0, -10}, torso = {-8, -35, 5}},
    },
    Thrust = {
        {right = {65, 20, 35}, left = {30, 0, -20}, torso = {0, 25, 0}},
        {right = {100, 0, 0}, left = {15, 0, -25}, torso = {-12, -8, 0}},
    },
    Heavy = {
        {right = {155, 0, 15}, left = {100, 0, -20}, torso = {12, 15, 0}},
        {right = {30, 0, -10}, left = {35, 0, -15}, torso = {-22, -15, 0}},
    },
}

function Pose.sample(name, elapsed, windup, duration)
    if name == "Guard" then return guard end
    if name == "Idle" then return idle end
    if elapsed < 0 or elapsed >= duration then return idle end
    local frames = moves[name]
    local from, to, t
    if frames then
        local contact = math.min(0.1, math.max(0.01, windup * 0.4))
        if elapsed < windup - contact then
            from, to, t = idle, frames[1], smooth(elapsed / math.max(0.01, windup - contact))
        elseif elapsed < windup then
            from, to, t = frames[1], frames[2], smooth((elapsed - windup + contact) / contact)
        else
            from, to, t = frames[2], idle, smooth((elapsed - windup) / math.max(0.01, duration - windup))
        end
    else
        from = name == "Parry" and guard or name == "Stagger"
            and {right = {15, 0, 40}, left = {10, 0, -35}, torso = {18, -12, 8}}
            or name == "Feint" and {right = {45, 15, 25}, left = {12, 0, -8}, torso = {0, 15, 0}} or idle
        to, t = idle, smooth(elapsed / math.max(0.01, duration))
    end
    return {right = blend(from.right, to.right, t), left = blend(from.left, to.left, t), torso = blend(from.torso, to.torso, t)}
end

return Pose
