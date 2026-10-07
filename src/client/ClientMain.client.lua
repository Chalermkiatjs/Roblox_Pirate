local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("PirateOcean")
local remotes = shared:WaitForChild("Remotes")
local Ships = require(shared.ShipConfig)
local Islands = require(shared.IslandConfig)
local Treasures = require(shared.TreasureConfig)
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn = "PirateOceanHud", false
gui.Parent = player:WaitForChild("PlayerGui")
local function label(parent, name, size, pos, textSize)
    local item = Instance.new("TextLabel")
    item.Name, item.Size, item.Position = name, size, pos
    item.BackgroundColor3, item.BackgroundTransparency = Color3.fromRGB(27, 32, 36), 0.12
    item.TextColor3, item.Font, item.TextSize = Color3.fromRGB(245, 248, 250), Enum.Font.Gotham, textSize
    item.TextWrapped = true
    item.Parent = parent
    return item
end
local status = label(gui, "Status", UDim2.new(1, -24, 0, 74), UDim2.fromOffset(12, 8), 16)
status.Text = "PIRATE OCEAN | Loading..."
local notice = label(gui, "Notice", UDim2.new(1, -24, 0, 36), UDim2.fromOffset(12, 86), 14)
notice.BackgroundColor3 = Color3.fromRGB(46, 112, 95)
notice.Text = "Harbor"
local actions = Instance.new("Frame")
actions.Name, actions.Size = "Actions", UDim2.new(1, -24, 0, 110)
actions.AnchorPoint, actions.Position = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -12)
actions.BackgroundTransparency, actions.Parent = 1, gui
local limit = Instance.new("UISizeConstraint")
limit.MaxSize, limit.Parent = Vector2.new(660, 110), actions
local grid = Instance.new("UIGridLayout")
grid.CellSize, grid.CellPadding = UDim2.new(1 / 3, -6, 0, 50), UDim2.fromOffset(6, 6)
grid.SortOrder, grid.Parent = Enum.SortOrder.LayoutOrder, actions
local buttons = {}
local function button(name, order, callback)
    local b = Instance.new("TextButton")
    b.Name, b.LayoutOrder, b.Text = name, order, name
    b.BackgroundColor3, b.TextColor3 = Color3.fromRGB(43, 93, 116), Color3.new(1, 1, 1)
    b.Font, b.TextSize, b.TextWrapped = Enum.Font.GothamBold, 14, true
    b.Parent = actions
    b.Activated:Connect(callback)
    buttons[name] = b
    return b
end
local messages = {
    ProfileUnavailable = "Still loading your ship",
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
}
local current
local pending = false
local function invoke(name, ...)
    local remote = remotes:WaitForChild(name, 10)
    if not remote then return nil end
    local ok, result = pcall(remote.InvokeServer, remote, ...)
    if not ok then notice.Text = "Connection interrupted" return nil end
    return result
end
local function refresh()
    local data = invoke("RequestSnapshot")
    if not data or not data.ship or not data.ship.stats or not data.ship.state then return end
    current = data
    local cargo, collection = 0, 0
    for _, amount in pairs(data.profile.cargo) do cargo += amount end
    for _ in pairs(data.profile.collection) do collection += 1 end
    local stats, state = data.ship.stats, data.ship.state
    status.Text = string.format("PIRATE OCEAN | %s | Gold %d\nHP %d / %d | Cargo %d / %d | Sea %d | Collection %d / 7",
        data.profile.currentShipTier, data.profile.gold, state.health, stats.maxHealth, cargo, stats.cargoSlots, state.currentDepth, collection)
    buttons.Sail.Text = state.inVoyage and "Dock" or "Set Sail"
    buttons.Collect.Text = data.nearestIsland and ("Collect\n" .. Islands.Islands[data.nearestIsland].displayName) or "Collect"
    local nextTier = Ships.getNextTier(data.profile.currentShipTier)
    buttons.Upgrade.Text = nextTier and (nextTier .. "\n" .. Ships.Tiers[nextTier].cost .. " gold") or "Max Ship"
end
local function act(name, argument)
    if pending then return end
    pending = true
    local result = invoke(name, argument)
    if result and not result.ok then
        notice.Text = (messages[result.error] or result.error) .. (result.required and (" | " .. result.required .. " gold") or "")
    end
    refresh()
    pending = false
end
button("Sail", 1, function() act(current and current.ship.state.inVoyage and "ReturnPort" or "PrepareVoyage") end)
button("Collect", 2, function() act("ExploreIsland") end)
button("Sell", 3, function() act("SellCargo") end)
button("Upgrade", 4, function() act("UpgradeShip") end)
button("Fire", 5, function() act("AttackKraken") end)
local collectionPanel = Instance.new("ScrollingFrame")
collectionPanel.Name = "Collection"
collectionPanel.Size, collectionPanel.Position = UDim2.new(1, -24, 1, -254), UDim2.fromOffset(12, 128)
collectionPanel.BackgroundColor3, collectionPanel.BackgroundTransparency = Color3.fromRGB(27, 32, 36), 0.04
collectionPanel.AutomaticCanvasSize, collectionPanel.CanvasSize = Enum.AutomaticSize.Y, UDim2.new()
collectionPanel.ScrollBarThickness, collectionPanel.Visible = 6, false
collectionPanel.Parent = gui
local layout = Instance.new("UIListLayout")
layout.Padding, layout.SortOrder, layout.Parent = UDim.new(0, 4), Enum.SortOrder.Name, collectionPanel
button("Collection", 6, function()
    collectionPanel.Visible = not collectionPanel.Visible
    if not collectionPanel.Visible then return end
    for _, child in ipairs(collectionPanel:GetChildren()) do if child:IsA("TextLabel") then child:Destroy() end end
    for id, item in pairs(Treasures.Items) do
        local amount = current and current.profile.collection[id] or 0
        local row = label(collectionPanel, id, UDim2.new(1, -12, 0, 40), UDim2.new(), 14)
        row.Text = string.format("%s | %s | %d collected", id, item.rarity, amount or 0)
    end
end)
remotes:WaitForChild("Notice").OnClientEvent:Connect(function(text) notice.Text = messages[text] or text end)
local elapsed = 0
RunService.RenderStepped:Connect(function(dt)
    elapsed += dt
    if elapsed < 0.1 then return end
    elapsed = 0
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    local seat = humanoid and humanoid.SeatPart
    if seat and seat:IsA("VehicleSeat") and seat.Name == "Helm" then
        remotes.ShipControl:FireServer(seat.ThrottleFloat, seat.SteerFloat)
    end
end)
task.spawn(function()
    while gui.Parent do refresh() task.wait(1) end
end)
