local Input = game:GetService("UserInputService")
local Actions = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Controller = {}

function Controller.start(player, hud, remotes)
    local remote = remotes:WaitForChild("CombatAction")
    local feedback = remotes:WaitForChild("CombatFeedback")
    local bound, equipped, activatedConnection = false, nil, nil
    local guardHeld = false
    local names = {"PirateSlash", "PirateThrust", "PirateHeavy", "PirateBlock", "PirateFeint"}
    local function available()
        local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        return equipped and equipped.Parent == player.Character and humanoid and humanoid.Health > 0
            and not humanoid.Sit and not hud.overlay.Visible and not Input:GetFocusedTextBox()
    end
    local function command(action, argument)
        if available() then remote:FireServer(action, argument) end
    end
    local function release()
        guardHeld = false
        remote:FireServer("Block", false)
    end
    local function input(name, state)
        if name == "PirateBlock" and (state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel) then
            release()
            return Enum.ContextActionResult.Sink
        end
        if not available() then return Enum.ContextActionResult.Pass end
        if state == Enum.UserInputState.Begin then
            if name == "PirateBlock" then guardHeld = true command("Block", true)
            elseif name == "PirateFeint" then command("Feint")
            else command("Attack", name == "PirateThrust" and "Thrust" or name == "PirateHeavy" and "Heavy" or "Slash") end
        end
        return Enum.ContextActionResult.Sink
    end
    local function bind(enabled)
        if enabled == bound then return end
        bound = enabled
        if not enabled then
            release()
            for _, name in ipairs(names) do Actions:UnbindAction(name) end
            return
        end
        local priority = Enum.ContextActionPriority.High.Value
        Actions:BindActionAtPriority("PirateThrust", input, false, priority, Enum.KeyCode.T, Enum.KeyCode.ButtonX)
        Actions:BindActionAtPriority("PirateHeavy", input, false, priority, Enum.KeyCode.R, Enum.KeyCode.ButtonY)
        Actions:BindActionAtPriority("PirateBlock", input, false, priority, Enum.KeyCode.F, Enum.KeyCode.ButtonL2, Enum.UserInputType.MouseButton2)
        Actions:BindActionAtPriority("PirateFeint", input, false, priority, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
    end
    for order, move in ipairs({"Slash", "Thrust", "Heavy"}) do
        hud:addCombatButton(move, order, function() command("Attack", move) end)
    end
    hud:addCombatButton("Block", 4, function()
        local guarding = player.Character and player.Character:GetAttribute("CombatState") == "Guarding"
        if guarding or guardHeld then release() else guardHeld = true command("Block", true) end
    end)
    hud:addCombatButton("Feint", 5, function() command("Feint") end)
    hud:addCombatButton("Stow", 6, function()
        release()
        local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then humanoid:UnequipTools() end
    end)
    local messages = {
        Hit = "Cutlass hit", Miss = "Out of reach", Parry = "Attack parried", Parried = "Parry - riposte ready",
        Block = "Attack blocked", Blocked = "Guard held", GuardBreak = "Guard broken", Damaged = "Player hit",
        Protected = "Target protected", InvalidAttack = "Invalid attack", Stunned = "Staggered",
        Recovering = "Recovering", NoStamina = "Not enough stamina", CannotFeint = "Feint during windup",
    }
    feedback.OnClientEvent:Connect(function(kind, detail)
        if kind == "Defeated" then
            hud:showNotice(string.format("Raider defeated | +%d bounty | +%d gold", detail.bounty, detail.gold))
        elseif kind == "Error" then
            hud:showNotice(messages[detail] or detail, true)
        else
            hud:showNotice(messages[kind] or kind, kind == "Damaged" or kind == "GuardBreak")
        end
    end)
    pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false) end)
    local elapsed = 0
    local render = RunService.RenderStepped:Connect(function(dt)
        local character = player.Character
        local tool = character and character:FindFirstChild("Cutlass")
        if tool and (not tool:IsA("Tool") or not tool:GetAttribute("PirateOceanWeapon")) then tool = nil end
        if tool ~= equipped then
            release()
            if activatedConnection then activatedConnection:Disconnect() end
            equipped = tool
            activatedConnection = tool and tool.Activated:Connect(function() command("Attack", "Slash") end) or nil
        end
        local enabled = not not available()
        bind(enabled)
        elapsed += dt
        if elapsed < 0.1 then return end
        elapsed = 0
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        hud:setCombat(enabled, character and character:GetAttribute("CombatState"))
        if humanoid then
            hud:updatePlayer(humanoid.Health, humanoid.MaxHealth, character:GetAttribute("Stamina") or 0, character:GetAttribute("MaxStamina") or 100)
        else
            hud:updatePlayer(0, 100, 0, 100)
        end
    end)
    local focus = Input.WindowFocusReleased:Connect(release)
    hud.gui.Destroying:Connect(function()
        bind(false)
        render:Disconnect()
        focus:Disconnect()
        if activatedConnection then activatedConnection:Disconnect() end
        pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, true) end)
    end)
end

return Controller
