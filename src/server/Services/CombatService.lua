local RunService = game:GetService("RunService")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("PirateOcean")
local Config = require(shared.CombatConfig)
local Rules = require(shared.Util.CombatRules)
local WorldConfig = require(shared.WorldConfig)
local Islands = require(shared.IslandConfig)
local Data = require(script.Parent.DataService)
local Moveset = require(script.Parent.MovesetAnimator)

local Combat = {}
local actors, connections, enemies = {}, {}, {}
local feedback, enemyFolder

local function sword(parent)
    local tool = Instance.new("Tool")
    tool.Name, tool.CanBeDropped, tool.ToolTip = "Cutlass", false, "Cutlass"
    tool:SetAttribute("PirateOceanWeapon", true)
    tool.Grip = CFrame.new(0, -0.3, 0)
    local handle = Instance.new("Part")
    handle.Name, handle.Size = "Handle", Vector3.new(0.3, 1.2, 0.3)
    handle.Color, handle.Material = Color3.fromRGB(75, 54, 39), Enum.Material.Wood
    handle.CanCollide, handle.CanTouch, handle.Massless = false, false, true
    handle.Parent = tool
    for _, detail in ipairs({
        {"Guard", Vector3.new(1.2, 0.18, 0.5), Vector3.new(0, 0.65, 0), Color3.fromRGB(208, 174, 101)},
        {"Blade", Vector3.new(0.42, 3, 0.14), Vector3.new(0, 2.2, 0), Color3.fromRGB(205, 220, 220)},
    }) do
        local part = Instance.new("Part")
        part.Name, part.Size, part.Color = detail[1], detail[2], detail[4]
        part.Material, part.CanCollide, part.CanTouch, part.Massless = Enum.Material.Metal, false, false, true
        part.CFrame, part.Parent = handle.CFrame * CFrame.new(detail[3]), tool
        local weld = Instance.new("WeldConstraint")
        weld.Part0, weld.Part1, weld.Parent = handle, part, handle
    end
    tool.Parent = parent
    return tool
end

local function ready(actor)
    return actor and actor.model.Parent and actor.humanoid.Health > 0 and actor.tool.Parent == actor.model
        and not actor.humanoid.Sit
end

local function send(actor, kind, detail)
    if actor.player and actor.player.Parent and feedback then feedback:FireClient(actor.player, kind, detail) end
end

local function publish(actor, now)
    local model, state = actor.model, actor.state
    local stamina = math.floor(state.stamina + 0.5)
    local status = actor.humanoid.Health <= 0 and "Defeated" or Rules.status(state, now)
    if model:GetAttribute("Stamina") ~= stamina then model:SetAttribute("Stamina", stamina) end
    if model:GetAttribute("CombatState") ~= status then model:SetAttribute("CombatState", status) end
    model:SetAttribute("MaxStamina", Config.MaxStamina)
    if actor.label then
        actor.label.Text = string.format("%s\n%d HP  /  %s", actor.training and "SPARRING MATE" or "ISLAND RAIDER", math.ceil(actor.humanoid.Health), status:upper())
    end
end

local function lineOfSight(attacker, target)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {attacker.model, target.model}
    params.IgnoreWater = true
    local direction = target.root.Position - attacker.root.Position
    return workspace:Raycast(attacker.root.Position, direction, params) == nil
end

local function facing(actor, target)
    local delta = target.root.Position - actor.root.Position
    local distance = delta.Magnitude
    return distance, distance > 0 and actor.root.CFrame.LookVector:Dot(delta.Unit) or 1, delta.Y
end

local function flash(actor, color)
    local highlight = Instance.new("Highlight")
    highlight.Adornee, highlight.FillColor, highlight.OutlineColor = actor.model, color, color
    highlight.FillTransparency, highlight.OutlineTransparency, highlight.Parent = 0.65, 0.2, actor.model
    game:GetService("Debris"):AddItem(highlight, 0.18)
end

local function cancel(actor)
    Rules.cancel(actor.state)
    if actor.tool.Parent then actor.tool.Grip = actor.neutralGrip end
    local pose = ready(actor) and "Idle" or "None"
    if actor.model:GetAttribute("MovesetName") ~= pose then Moveset.play(actor, pose) end
    actor.guardPose = false
end

local function hit(attacker, target, attack)
    if not ready(attacker) or target.humanoid.Health <= 0 then return end
    if target.model:FindFirstChildOfClass("ForceField") then send(attacker, "Protected") return end
    local _, defenderFacing = facing(target, attacker)
    local outcome, damage = Rules.defend(target.state, Config, attack, os.clock(), defenderFacing)
    local reward
    if outcome == "Parry" then
        cancel(attacker)
        attacker.state.stunnedUntil = os.clock() + Config.ParryStun
        Moveset.play(attacker, "Stagger", Config.ParryStun)
        Moveset.play(target, "Parry", 0.22)
        flash(target, Color3.fromRGB(86, 199, 176))
    elseif damage > 0 then
        cancel(target)
        target.state.stunnedUntil = math.max(target.state.stunnedUntil, os.clock() + Config.HitStun)
        local oldHealth = target.humanoid.Health
        target.humanoid:TakeDamage(damage)
        if target.humanoid.Health > 0 then
            Moveset.play(target, "Stagger", math.max(Config.HitStun, target.state.stunnedUntil - os.clock()))
        end
        if target.humanoid.Health < oldHealth then flash(target, Color3.fromRGB(239, 214, 157)) end
        if target.humanoid.Health <= 0 and not target.training and not target.rewarded and attacker.player then
            target.rewarded = true
            local profile = Data.getProfile(attacker.player)
            if profile then
                Data.addGold(attacker.player, target.gold)
                Data.addBounty(attacker.player, target.bounty)
                profile.stats.combatDefeats += 1
                reward = {bounty = target.bounty, gold = target.gold}
            end
        end
    else
        flash(target, Color3.fromRGB(208, 174, 101))
    end
    send(attacker, outcome)
    if reward then send(attacker, "Defeated", reward) end
    send(target, outcome == "Parry" and "Parried" or outcome == "Block" and "Blocked" or "Damaged")
end

local function resolve(attacker, attack)
    if not ready(attacker) or attacker.state.sequence ~= attack.token then return end
    attacker.state.attack = nil
    local targets = {}
    if attacker.player then
        for _, enemy in pairs(enemies) do table.insert(targets, enemy) end
    elseif attacker.target then
        table.insert(targets, attacker.target)
    end
    local nearest, nearestDistance = nil, math.huge
    for _, target in ipairs(targets) do
        if target.model.Parent and target.humanoid.Health > 0 then
            local distance, dot, height = facing(attacker, target)
            if distance < nearestDistance and Rules.inReach(Config, attack.name, distance, dot, height) and lineOfSight(attacker, target) then
                nearest, nearestDistance = target, distance
            end
        end
    end
    if nearest then hit(attacker, nearest, attack) else send(attacker, "Miss") end
end

local function attack(actor, name)
    local ok, result = Rules.attack(actor.state, Config, name, os.clock())
    if not ok then return false, result end
    if not actor.player then result.damage = math.floor(actor.damage * (name == "Heavy" and 1.5 or 1)) end
    local windup = math.max(0, result.resolvesAt - os.clock())
    Moveset.play(actor, name, windup + Config.Attacks[name].recovery, windup)
    task.delay(windup, function()
        if actor.state.sequence ~= result.token then return end
        resolve(actor, result)
    end)
    return true
end

function Combat.request(player, action, argument)
    local actor = actors[player]
    if not ready(actor) or player.Character ~= actor.model then return end
    local now = os.clock()
    -- Releases are never throttled, so a delayed input cannot leave the guard held.
    if action == "Block" and argument == false then Rules.block(actor.state, Config, false, now) return end
    if now - actor.lastRequest < Config.RequestInterval then return end
    actor.lastRequest = now
    local ok, err
    if action == "Attack" and type(argument) == "string" then ok, err = attack(actor, argument)
    elseif action == "Block" and type(argument) == "boolean" then ok, err = Rules.block(actor.state, Config, argument, now)
    elseif action == "Feint" then
        ok, err = Rules.feint(actor.state, Config, now)
        if ok then
            actor.tool.Grip = actor.neutralGrip
            Moveset.play(actor, "Feint", Config.FeintRecovery)
        end
    else return end
    if not ok then send(actor, "Error", err) end
    publish(actor, now)
end

function Combat.getSnapshot(player)
    local actor = actors[player]
    if not actor or not actor.model.Parent or player.Character ~= actor.model then
        return {health = 0, maxHealth = Config.PlayerHealth, stamina = 0, maxStamina = Config.MaxStamina, state = "Respawning"}
    end
    return {health = actor.humanoid.Health, maxHealth = actor.humanoid.MaxHealth,
        stamina = actor.state.stamina, maxStamina = Config.MaxStamina,
        state = actor.humanoid.Health <= 0 and "Respawning" or Rules.status(actor.state, os.clock())}
end

function Combat.addPlayer(player)
    local function spawned(character)
        local humanoid = character:WaitForChild("Humanoid", 10)
        local root = character:WaitForChild("HumanoidRootPart", 10)
        local backpack = player:WaitForChild("Backpack", 10)
        if not humanoid or not root or not backpack or player.Character ~= character or not player.Parent then return end
        if actors[player] then cancel(actors[player]) Moveset.destroy(actors[player]) end
        humanoid.MaxHealth, humanoid.Health = Config.PlayerHealth, Config.PlayerHealth
        local tool = sword(backpack)
        local actor = {player = player, model = character, humanoid = humanoid, root = root, tool = tool,
            neutralGrip = tool.Grip, state = Rules.newState(Config), lastRequest = -math.huge, baseSpeed = humanoid.WalkSpeed}
        actors[player] = actor
        Moveset.attach(actor)
        tool.Equipped:Connect(function() Moveset.play(actor, "Idle") end)
        tool.Unequipped:Connect(function()
            cancel(actor)
        end)
        humanoid.Died:Connect(function() cancel(actor) end)
        publish(actor, os.clock())
    end
    connections[player] = player.CharacterAdded:Connect(spawned)
    if player.Character then task.spawn(spawned, player.Character) end
end

function Combat.removePlayer(player)
    if actors[player] then cancel(actors[player]) Moveset.destroy(actors[player]) end
    if connections[player] then connections[player]:Disconnect() end
    connections[player], actors[player] = nil, nil
end

local function enemyRig(position)
    local model = Instance.new("Model")
    model.Name = "IslandRaider"
    local parts = {}
    for _, body in ipairs({
        {"HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.zero},
        {"Torso", Vector3.new(2, 2, 1), Vector3.zero},
        {"Head", Vector3.new(2, 1, 1), Vector3.new(0, 1.5, 0)},
        {"Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0)},
        {"Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0)},
        {"Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0)},
        {"Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0)},
    }) do
        local part = Instance.new("Part")
        part.Name, part.Size, part.CFrame = body[1], body[2], CFrame.new(position + body[3])
        part.Color = body[1] == "Head" and Color3.fromRGB(212, 174, 135) or Color3.fromRGB(129, 60, 55)
        part.CanCollide = body[1] == "Torso"
        part.Transparency = body[1] == "HumanoidRootPart" and 1 or 0
        part.Parent, parts[body[1]] = model, part
    end
    local function joint(name, a, b, c0, c1)
        local motor = Instance.new("Motor6D")
        motor.Name, motor.Part0, motor.Part1, motor.C0, motor.C1, motor.Parent = name, parts[a], parts[b], c0, c1, parts[a]
    end
    joint("RootJoint", "HumanoidRootPart", "Torso", CFrame.new(), CFrame.new())
    joint("Neck", "Torso", "Head", CFrame.new(0, 1, 0), CFrame.new(0, -0.5, 0))
    joint("Right Shoulder", "Torso", "Right Arm", CFrame.new(1, 0.5, 0), CFrame.new(-0.5, 0.5, 0))
    joint("Left Shoulder", "Torso", "Left Arm", CFrame.new(-1, 0.5, 0), CFrame.new(0.5, 0.5, 0))
    joint("Right Hip", "Torso", "Right Leg", CFrame.new(0.5, -1, 0), CFrame.new(0, 1, 0))
    joint("Left Hip", "Torso", "Left Leg", CFrame.new(-0.5, -1, 0), CFrame.new(0, 1, 0))
    local humanoid = Instance.new("Humanoid")
    humanoid.DisplayDistanceType, humanoid.WalkSpeed = Enum.HumanoidDisplayDistanceType.None, Config.Enemy.WalkSpeed
    humanoid.Parent = model
    local animator = Instance.new("Animator")
    animator.Parent = humanoid
    model.PrimaryPart, model.Parent = parts.HumanoidRootPart, enemyFolder
    parts.HumanoidRootPart:SetNetworkOwner(nil)
    local tool = sword(model)
    humanoid:EquipTool(tool)
    local billboard = Instance.new("BillboardGui")
    billboard.Size, billboard.StudsOffset, billboard.MaxDistance = UDim2.fromOffset(180, 52), Vector3.new(0, 3, 0), 80
    billboard.Parent = parts.Head
    local label = Instance.new("TextLabel")
    label.Size, label.BackgroundColor3, label.BackgroundTransparency = UDim2.fromScale(1, 1), Color3.fromRGB(24, 30, 30), 0.15
    label.TextColor3, label.Font, label.TextSize, label.Parent = Color3.fromRGB(242, 239, 222), Enum.Font.GothamBold, 12, billboard
    return model, humanoid, parts.HumanoidRootPart, tool, label
end

local spawnEnemy
spawnEnemy = function(id, home, depth, training)
    if not enemyFolder.Parent then return end
    local model, humanoid, root, tool, label = enemyRig(home)
    model.Name = training and "SparringMate" or id .. "Raider"
    humanoid.MaxHealth = training and Config.Enemy.TrainingHealth or 60 + depth * 20
    humanoid.Health = humanoid.MaxHealth
    local actor = {model = model, humanoid = humanoid, root = root, tool = tool, neutralGrip = tool.Grip,
        state = Rules.newState(Config), label = label, home = home, training = training, depth = depth,
        bounty = depth * 25, gold = depth * 12, damage = training and Config.Enemy.TrainingDamage or 8 + depth * 3,
        baseSpeed = Config.Enemy.WalkSpeed, nextAttack = 0, attacks = 0}
    enemies[id] = actor
    Moveset.attach(actor)
    Moveset.play(actor, "Idle")
    humanoid.Died:Connect(function()
        cancel(actor)
        task.delay(training and 8 or Config.Enemy.RespawnTime, function()
            if enemies[id] ~= actor then return end
            Moveset.destroy(actor)
            model:Destroy()
            spawnEnemy(id, home, depth, training)
        end)
    end)
    if training then
        local prompt = Instance.new("ProximityPrompt")
        prompt.ActionText, prompt.ObjectText, prompt.MaxActivationDistance = "Spar", "Sparring Mate", 10
        prompt.Parent = root
        prompt.Triggered:Connect(function(player)
            local visitor = actors[player]
            if visitor and visitor.humanoid.Health > 0 and (visitor.root.Position - root.Position).Magnitude <= 12 then
                actor.sparringPlayer = player
            end
        end)
    end
    publish(actor, os.clock())
end

local function thinkEnemy(actor, now)
    if actor.humanoid.Health <= 0 then return end
    local target, distance = nil, Config.Enemy.AggroRange
    for player, visitor in pairs(actors) do
        if visitor.model.Parent and visitor.humanoid.Health > 0 and not visitor.humanoid.Sit
            and not visitor.model:FindFirstChildOfClass("ForceField")
            and (not actor.training or actor.sparringPlayer == player)
            and (visitor.root.Position - actor.home).Magnitude <= Config.Enemy.LeashRange then
            local d = (visitor.root.Position - actor.root.Position).Magnitude
            if d < distance then target, distance = visitor, d end
        end
    end
    actor.target = target
    if not target then
        if actor.training then
            local visitor = actors[actor.sparringPlayer]
            if not visitor or not visitor.model.Parent or visitor.humanoid.Health <= 0
                or (visitor.root.Position - actor.home).Magnitude > Config.Enemy.LeashRange then
                actor.sparringPlayer = nil
            end
        end
        Rules.block(actor.state, Config, false, now)
        actor.humanoid:MoveTo(actor.home)
        return
    end
    if now < actor.state.busyUntil or now < actor.state.stunnedUntil then
        actor.humanoid:MoveTo(actor.root.Position)
        return
    end
    actor.humanoid:MoveTo(distance > 5 and target.root.Position or actor.root.Position)
    local look = Vector3.new(target.root.Position.X, actor.root.Position.Y, target.root.Position.Z)
    if (look - actor.root.Position).Magnitude > 0.1 then actor.root.CFrame = CFrame.lookAt(actor.root.Position, look) end
    if target.state.attack and distance <= 10 then
        if actor.threatToken ~= target.state.attack.token or actor.threatActor ~= target then
            actor.threatToken, actor.threatActor, actor.reactAt = target.state.attack.token, target, now + Config.Enemy.ReactionTime
        end
        if now >= actor.reactAt then Rules.block(actor.state, Config, true, now) end
    else
        actor.threatToken, actor.threatActor = nil, nil
        Rules.block(actor.state, Config, false, now)
        if distance <= 7 and now >= actor.nextAttack then
            actor.attacks += 1
            if attack(actor, actor.attacks % 3 == 0 and "Heavy" or "Slash") then
                actor.nextAttack = now + Config.Enemy.AttackInterval
            end
        end
    end
end

function Combat.init(remote)
    feedback = remote
    enemyFolder = Instance.new("Folder")
    enemyFolder.Name, enemyFolder.Parent = "Combatants", workspace:WaitForChild("PirateOceanWorld")
    spawnEnemy("Training", Vector3.new(64, 11, 30), 1, true)
    for id, island in pairs(Islands.Islands) do
        spawnEnemy(id, WorldConfig.Islands[id] + Vector3.new(14, 9, -8), island.depth, false)
    end
    local elapsed, thinking = 0, 0
    RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        thinking += dt
        if elapsed < 0.05 then return end
        local step, now = elapsed, os.clock()
        elapsed = 0
        local all = {}
        for _, actor in pairs(actors) do table.insert(all, actor) end
        for _, actor in pairs(enemies) do table.insert(all, actor) end
        for _, actor in ipairs(all) do
            if not actor.model.Parent then continue end
            if not ready(actor) then cancel(actor) end
            if actor.humanoid.Health > 0 then Rules.update(actor.state, Config, step, now) end
            if actor.guardPose ~= actor.state.blocking then
                actor.guardPose = actor.state.blocking
                if actor.state.blocking then
                    Moveset.play(actor, "Guard")
                elseif actor.model:GetAttribute("MovesetName") == "Guard" then
                    Moveset.play(actor, "Idle")
                end
            end
            Moveset.update(actor)
            actor.humanoid.WalkSpeed = now < actor.state.stunnedUntil and 0 or actor.state.blocking and actor.baseSpeed * 0.5 or actor.baseSpeed
            publish(actor, now)
        end
        if thinking >= Config.Enemy.ThinkInterval then
            thinking = 0
            for _, actor in pairs(enemies) do thinkEnemy(actor, now) end
        end
    end)
end

return Combat
