local Pose = require("../src/shared/Util/MovesetPose")
local Combat = require("../src/shared/CombatConfig")
local names = {"Idle", "Guard", "Slash", "Thrust", "Heavy", "Parry", "Stagger", "Feint"}
local entries = {}
for _, name in ipairs(names) do
    local move = Combat.Attacks[name]
    local windup = move and move.windup or 0
    local duration = move and windup + move.recovery
        or name == "Idle" and 2 or name == "Guard" and 1
        or name == "Parry" and 0.22 or name == "Feint" and Combat.FeintRecovery or Combat.HitStun
    local times = {0, duration}
    for i = 1, math.floor(duration * 30) do table.insert(times, i / 30) end
    if move then
        table.insert(times, windup)
        table.insert(times, windup - math.min(0.1, windup * 0.4))
    end
    table.sort(times)
    local frames, last = {}, -1
    for _, time in ipairs(times) do
        if time - last < 0.000001 then continue end
        last = time
        local sample = Pose.sample(name, time, windup, duration)
        local angles = {}
        for _, role in ipairs({"right", "left", "torso"}) do
            local v = sample[role]
            table.insert(angles, string.format('"%s":[%.9f,%.9f,%.9f]', role, v[1], v[2], v[3]))
        end
        table.insert(frames, string.format('{"time":%.9f,"angles":{%s}}', time, table.concat(angles, ",")))
    end
    table.insert(entries, string.format('{"name":"%s","windup":%.9f,"duration":%.9f,"loop":%s,"frames":[%s]}',
        name, windup, duration, tostring(name == "Idle" or name == "Guard"), table.concat(frames, ",")))
end
print("[" .. table.concat(entries, ",") .. "]")
