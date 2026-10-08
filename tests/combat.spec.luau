local Config = require("../src/shared/CombatConfig")
local Rules = require("../src/shared/Util/CombatRules")

local attacker = Rules.newState(Config)
assert(not Rules.attack(attacker, Config, "RemoteDamage", 1), "Unknown attacks accepted")
assert(not Rules.attack(attacker, Config, {}, 1), "Malformed attack accepted")
local ok, slash = Rules.attack(attacker, Config, "Slash", 1)
assert(ok and attacker.stamina == 88)
assert(not Rules.attack(attacker, Config, "Slash", 1.01), "Attack spam bypassed recovery")
assert(not Rules.block(attacker, Config, true, 1.02), "Attack can immediately become a guard")
local token = slash.token
assert(Rules.feint(attacker, Config, 1.1))
assert(attacker.sequence ~= token and attacker.attack == nil, "Feint leaves delayed attack active")
assert(attacker.stamina == 80)
assert(not Rules.attack(attacker, Config, "Heavy", 1.2), "Feint bypassed recovery")
assert(Rules.attack(attacker, Config, "Heavy", 1.4))
assert(not Rules.feint(attacker, Config, 2.1), "Resolved attack can be feinted")

local defender = Rules.newState(Config)
assert(Rules.block(defender, Config, true, 1))
local outcome, damage = Rules.defend(defender, Config, slash, 1.1, 1)
assert(outcome == "Parry" and damage == 0 and defender.riposteUntil > 1.1)
Rules.block(defender, Config, false, 1.11)
local counterOK, counter = Rules.attack(defender, Config, "Thrust", 1.12)
assert(counterOK and counter.damage == Config.Attacks.Thrust.damage + Config.RiposteBonus)
assert(counter.resolvesAt < 1.12 + Config.Attacks.Thrust.windup)
assert(defender.riposteUntil == 0, "Riposte bonus reusable")

defender = Rules.newState(Config)
Rules.block(defender, Config, true, 1)
Rules.block(defender, Config, true, 1.4)
outcome, damage = Rules.defend(defender, Config, slash, 1.5, 1)
assert(outcome == "Block" and damage == 0 and defender.stamina == 82, "Held block resets parry window")
outcome, damage = Rules.defend(defender, Config, slash, 1.55, -1)
assert(outcome == "Hit" and damage == slash.damage, "Guard protects attacks from behind")
Rules.block(defender, Config, false, 2)
Rules.block(defender, Config, true, 2.01)
Rules.block(defender, Config, false, 2.02)
assert(not Rules.block(defender, Config, true, 2.03), "Guard tapping bypasses parry cooldown")

defender = Rules.newState(Config)
Rules.block(defender, Config, true, 1)
defender.stamina = 5
outcome, damage = Rules.defend(defender, Config, slash, 1.5, 1)
assert(outcome == "GuardBreak" and damage == slash.damage and defender.stamina == 0)
assert(not defender.blocking and defender.stunnedUntil > 1.5)
assert(not Rules.attack(defender, Config, "Slash", 1.6), "Stunned defender can attack")

for _, fps in ipairs({30, 60, 120}) do
    local state = Rules.newState(Config)
    state.stamina, state.lastSpent = 20, 0
    for tick = 1, fps do Rules.update(state, Config, 1 / fps, tick / fps) end
    assert(state.stamina == 20, "Stamina regenerates before delay")
    for tick = fps + 1, fps * 5 do Rules.update(state, Config, 1 / fps, tick / fps) end
    assert(state.stamina >= 99 and state.stamina <= Config.MaxStamina, "Stamina regen unstable across frame rates")
    Rules.block(state, Config, true, 6)
    for tick = 1, fps * 25 do Rules.update(state, Config, 1 / fps, 6 + tick / fps) end
    assert(not state.blocking, "Empty stamina sustains infinite guard")
end

assert(Rules.inReach(Config, "Slash", 7, 0.8, 1))
assert(not Rules.inReach(Config, "Slash", 20, 1, 0), "Long-range melee accepted")
assert(not Rules.inReach(Config, "Slash", 3, -1, 0), "Melee hits behind attacker")
assert(not Rules.inReach(Config, "Thrust", 6, 0.4, 0), "Thrust cone too wide")
assert(not Rules.inReach(Config, "Heavy", 7, 1, 8), "Hits through different floors accepted")
assert(Rules.bounty(nil, 25, Config.MaxBounty) == 25, "Old profile cannot gain bounty")
assert(Rules.bounty(100, -50, Config.MaxBounty) == 100)
assert(Rules.bounty(0 / 0, 25, Config.MaxBounty) == 25)
assert(Rules.bounty(math.huge, 25, Config.MaxBounty) == 25)
assert(Rules.bounty(Config.MaxBounty, 500, Config.MaxBounty) == Config.MaxBounty)
print("PASS: cooldowns, feints, directional blocks, parries, ripostes, guard breaks, stamina, reach and bounty")
