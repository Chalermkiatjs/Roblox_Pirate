local Pose = require("../src/shared/Util/MovesetPose")
local Config = require("../src/shared/MovesetConfig")
local Combat = require("../src/shared/CombatConfig")
local Orientation = require("../src/shared/Util/MovesetOrientation")

local function near(a, b)
    for _, role in ipairs({"right", "left", "torso"}) do
        for i = 1, 3 do assert(math.abs(a[role][i] - b[role][i]) < 0.001) end
    end
end
local idle = Pose.sample("Idle", 0, 0, 0)
for name, move in pairs(Combat.Attacks) do
    for _, speed in ipairs({1, 0.65}) do
        local windup = move.windup * speed
        local duration = windup + move.recovery
        near(Pose.sample(name, 0, windup, duration), idle)
        near(Pose.sample(name, duration, windup, duration), idle)
        local contact = Pose.sample(name, windup, windup, duration)
        assert(math.abs(contact.right[1] - idle.right[1]) > 1)
        -- Rxyz maps the downward arm into -Z for a forward strike.
        local x, y, z = math.rad(contact.right[1]), math.rad(contact.right[2]), math.rad(contact.right[3])
        local forward = math.sin(x) * math.cos(z) + math.cos(x) * math.sin(y) * math.sin(z)
        assert(forward > 0, name .. " points the arm backward at contact")
        near(Pose.sample(name, windup - 0.000001, windup, duration), contact)
        for _, hz in ipairs({30, 60, 120}) do
            for frame = 0, math.ceil(duration * hz) do
                local sample = Pose.sample(name, frame / hz, windup, duration)
                for _, angles in pairs(sample) do
                    for _, angle in ipairs(angles) do assert(angle == angle and math.abs(angle) <= 180) end
                end
            end
        end
    end
end
local original = {1, 2, 3, 0.8, -0.1, 0.2, 0.3, 0.9, -0.4, -0.5, 0.6, 0.7}
local mirrored = Orientation.mirrorForward(original)
local restored = Orientation.mirrorForward(mirrored)
for i = 1, 12 do assert(restored[i] == original[i]) end
assert(mirrored[1] == 1 and mirrored[2] == 2 and mirrored[3] == -3)
near(Pose.sample("Slash", -1, 0.24, 0.72), idle)
for _, name in ipairs({"Parry", "Stagger", "Feint"}) do
    assert(Pose.sample(name, 0, 0, 0.3).right[1] ~= idle.right[1])
    near(Pose.sample(name, 0.3, 0, 0.3), idle)
end
for _, rig in ipairs({"R6", "R15"}) do
    for _, name in ipairs({"Idle", "Guard", "Slash", "Thrust", "Heavy", "Parry", "Stagger", "Feint"}) do
        assert(Config[rig][name] and type(Config[rig][name].Id) == "number")
    end
end
print("moveset.spec: passed (contact timing, riposte, recovery, rigs, frame rates)")
