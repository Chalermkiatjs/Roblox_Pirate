local Rules = {}

function Rules.newState(config)
    return {stamina = config.MaxStamina, blocking = false, blockStarted = -math.huge,
        nextBlock = 0, stunnedUntil = 0, busyUntil = 0, lastSpent = -math.huge,
        riposteUntil = 0, sequence = 0, attack = nil}
end

function Rules.cancel(state)
    state.sequence += 1
    state.attack, state.blocking = nil, false
end

function Rules.attack(state, config, name, now)
    local move = type(name) == "string" and config.Attacks[name]
    if not move then return false, "InvalidAttack" end
    if now < state.stunnedUntil then return false, "Stunned" end
    if now < state.busyUntil or state.blocking then return false, "Recovering" end
    if state.stamina < move.stamina then return false, "NoStamina" end
    local riposte = now < state.riposteUntil
    state.riposteUntil = 0
    state.stamina -= move.stamina
    state.lastSpent = now
    state.sequence += 1
    local windup = move.windup * (riposte and 0.65 or 1)
    state.busyUntil = now + windup + move.recovery
    state.attack = {name = name, token = state.sequence, resolvesAt = now + windup,
        damage = move.damage + (riposte and config.RiposteBonus or 0)}
    return true, state.attack
end

function Rules.block(state, config, enabled, now)
    if not enabled then state.blocking = false return true end
    if state.blocking then return true end
    if now < state.stunnedUntil or now < state.busyUntil or now < state.nextBlock then return false, "Recovering" end
    if state.stamina <= 0 then return false, "NoStamina" end
    state.blocking, state.blockStarted = true, now
    state.nextBlock = now + config.BlockCooldown
    return true
end

function Rules.feint(state, config, now)
    if not state.attack or now >= state.attack.resolvesAt or now < state.stunnedUntil then return false, "CannotFeint" end
    if state.stamina < config.FeintCost then return false, "NoStamina" end
    Rules.cancel(state)
    state.stamina -= config.FeintCost
    state.lastSpent, state.busyUntil = now, now + config.FeintRecovery
    return true
end

function Rules.defend(state, config, attack, now, facingDot)
    if not state.blocking or now < state.stunnedUntil or facingDot < config.BlockFacingDot then
        return "Hit", attack.damage
    end
    if now - state.blockStarted <= config.ParryWindow then
        state.riposteUntil = now + config.RiposteWindow
        return "Parry", 0
    end
    local cost = config.Attacks[attack.name].blockCost
    state.lastSpent = now
    if state.stamina < cost then
        Rules.cancel(state)
        state.stamina, state.stunnedUntil = 0, now + config.GuardBreakStun
        return "GuardBreak", attack.damage
    end
    state.stamina -= cost
    if state.stamina <= 0 then state.blocking = false end
    return "Block", 0
end

function Rules.update(state, config, dt, now)
    if state.blocking then
        state.stamina = math.max(0, state.stamina - config.BlockDrain * dt)
        state.lastSpent = now
        if state.stamina <= 0 then state.blocking = false end
    elseif now >= state.lastSpent + config.RegenDelay and now >= state.stunnedUntil and now >= state.busyUntil then
        state.stamina = math.min(config.MaxStamina, state.stamina + config.StaminaRegen * dt)
    end
end

function Rules.inReach(config, name, distance, facingDot, height)
    local move = config.Attacks[name]
    return move ~= nil and distance > 0 and distance <= move.range and facingDot >= move.facingDot and math.abs(height) <= 6
end

function Rules.status(state, now)
    if now < state.stunnedUntil then return "Stunned" end
    if state.blocking then return "Guarding" end
    if state.attack then return state.attack.name end
    if now < state.busyUntil then return "Recovering" end
    if now < state.riposteUntil then return "Riposte" end
    return "Ready"
end

function Rules.bounty(current, amount, maximum)
    if type(current) ~= "number" or current ~= current or math.abs(current) == math.huge then current = 0 end
    if type(amount) ~= "number" or amount ~= amount or amount < 0 or amount == math.huge then return math.clamp(math.floor(current), 0, maximum) end
    return math.clamp(math.floor(current) + math.floor(amount), 0, maximum)
end

return Rules
