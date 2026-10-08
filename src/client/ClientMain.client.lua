local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local ContextActions = game:GetService("ContextActionService")
local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("PirateOcean")
local remotes = shared:WaitForChild("Remotes")
local Ships = require(shared.ShipConfig)
local Islands = require(shared.IslandConfig)
local Treasures = require(shared.TreasureConfig)
local Sailing = require(shared.SailingConfig)
local hud = require(script.Parent.PirateHud).new(player:WaitForChild("PlayerGui"), Sailing, Treasures)
local gui = hud.gui
require(script.Parent.CombatController).start(player, hud, remotes)
local messages = {
    ProfileUnavailable = "Still loading your ship",
    CharacterUnavailable = "Waiting for your character to respawn",
    SlowDown = "Wait a moment",
    ReturnToPort = "Return to harbor first",
    SailBackToPort = "Sail closer to harbor to dock",
    SailNearIsland = "Sail closer to an island",
    TreasureRecovering = "Treasure is recovering (25 seconds)",
    CargoFull = "Cargo full - return to sell",
    ShipTierTooLow = "Upgrade your ship first",
    MaxTier = "Your ship is at the highest tier",
    NotEnoughGold = "Not enough gold",
    NoCrewSlot = "No free crew slot",
    SailNearKraken = "Sail closer to the Kraken",
    TakeTheHelm = "Take your ship's helm first",
    InvalidSailStage = "Invalid sail stage",
    AnchorDown = "Raise anchor first",
    GoToAnchor = "Go to the bow capstan",
}
local current
local pending = false
local function invoke(name, ...)
    local remote = remotes:WaitForChild(name, 10)
    if not remote then return nil end
    local ok, result = pcall(remote.InvokeServer, remote, ...)
    if not ok then hud:showNotice("Connection interrupted", true) return nil end
    return result
end
local function refresh()
    local data = invoke("RequestSnapshot")
    if not data or not data.ship or not data.ship.stats or not data.ship.state then return end
    current = data
    hud:update(data, Ships, Islands)
end
local function act(name, argument)
    if pending then return end
    pending = true
    hud:setPending(true)
    local result = invoke(name, argument)
    if result and not result.ok then
        hud:showNotice((messages[result.error] or result.error) .. (result.required and (" | " .. result.required .. " gold") or ""), true)
    end
    refresh()
    pending = false
    hud:setPending(false)
end
hud:addButton("Sail", 1, "Set Sail", function() act(current and current.ship.state.inVoyage and "ReturnPort" or "PrepareVoyage") end)
hud:addButton("Collect", 2, "Collect", function() act("ExploreIsland") end)
hud:addButton("Sell", 3, "Sell", function() act("SellCargo") end)
hud:addButton("Upgrade", 4, "Upgrade", function() act("UpgradeShip") end)
hud:addButton("Fire", 5, "Fire", function() act("AttackKraken") end)
hud:addButton("Collection", 6, "Ledger", function() hud:toggleCollection() end)
hud:setPending(false)
remotes:WaitForChild("Notice").OnClientEvent:Connect(function(text) hud:showNotice(messages[text] or text) end)
local stageRemote = remotes:WaitForChild("StepSailStage")
local increaseAction, decreaseAction = "PirateOceanIncreaseSpeed", "PirateOceanDecreaseSpeed"
local controlsBound = false
local function helm()
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    local seat = humanoid and humanoid.Health > 0 and humanoid.SeatPart
    if seat and seat:IsA("VehicleSeat") and seat.Name == "Helm" and seat.Parent
        and seat.Parent:GetAttribute("InVoyage") then return seat end
end
local function changeSpeed(actionName, inputState)
    if not helm() or hud.overlay.Visible or Input:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
    if inputState == Enum.UserInputState.Begin then
        stageRemote:FireServer(actionName == increaseAction and 1 or -1)
    end
    return Enum.ContextActionResult.Sink
end
local function bindControls(enabled)
    if controlsBound == enabled then return end
    controlsBound = enabled
    if not enabled then
        ContextActions:UnbindAction(increaseAction)
        ContextActions:UnbindAction(decreaseAction)
        return
    end
    ContextActions:BindActionAtPriority(increaseAction, changeSpeed, true, Enum.ContextActionPriority.High.Value,
        Enum.KeyCode.W, Enum.KeyCode.Up, Enum.KeyCode.DPadUp, Enum.KeyCode.ButtonR2)
    ContextActions:BindActionAtPriority(decreaseAction, changeSpeed, true, Enum.ContextActionPriority.High.Value,
        Enum.KeyCode.S, Enum.KeyCode.Down, Enum.KeyCode.DPadDown, Enum.KeyCode.ButtonL2)
    ContextActions:SetTitle(increaseAction, "+")
    ContextActions:SetTitle(decreaseAction, "-")
    ContextActions:SetPosition(increaseAction, UDim2.new(1, -60, 1, hud.touchControlY))
    ContextActions:SetPosition(decreaseAction, UDim2.new(1, -60, 1, hud.touchControlY + 64))
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
    hud:layout()
    if controlsBound then
        ContextActions:SetPosition(increaseAction, UDim2.new(1, -60, 1, hud.touchControlY))
        ContextActions:SetPosition(decreaseAction, UDim2.new(1, -60, 1, hud.touchControlY + 64))
    end
end)
Input.InputBegan:Connect(function(input, processed)
    if not processed and hud.overlay.Visible and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then
        hud:toggleCollection(false)
    end
end)
player.CharacterRemoving:Connect(function() bindControls(false) end)
script.Destroying:Connect(function() bindControls(false) end)
local elapsed = 0
RunService.RenderStepped:Connect(function(dt)
    local seat = helm()
    bindControls(seat ~= nil and not hud.overlay.Visible)
    hud:setHelm(seat ~= nil)
    if seat then
        local stage = seat.Parent:GetAttribute("SailStage")
        hud:setStage(stage)
    end
    elapsed += dt
    if elapsed < 0.1 then return end
    elapsed = 0
    if seat then
        remotes.ShipControl:FireServer(0, seat.SteerFloat)
    end
end)
task.spawn(function()
    while gui.Parent do refresh() task.wait(1) end
end)
