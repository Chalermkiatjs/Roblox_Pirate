local Input = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Hud = {}
local colors = {
    ink = Color3.fromRGB(24, 30, 30),
    panel = Color3.fromRGB(35, 43, 41),
    brass = Color3.fromRGB(208, 174, 101),
    paper = Color3.fromRGB(242, 239, 222),
    muted = Color3.fromRGB(168, 184, 175),
    sea = Color3.fromRGB(44, 119, 103),
    red = Color3.fromRGB(174, 71, 66),
}
local rarityColors = {
    Common = colors.muted,
    Uncommon = Color3.fromRGB(111, 194, 133),
    Rare = Color3.fromRGB(110, 189, 224),
    Epic = Color3.fromRGB(198, 144, 216),
    Legendary = colors.brass,
}

local function create(class, parent, properties)
    local object = Instance.new(class)
    for key, value in pairs(properties) do object[key] = value end
    object.Parent = parent
    return object
end

local function trim(object, color)
    create("UICorner", object, {CornerRadius = UDim.new(0, 4)})
    return create("UIStroke", object, {Color = color or colors.brass, Transparency = 0.55, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
end

local function text(parent, name, size, position, value, fontSize, color)
    return create("TextLabel", parent, {
        Name = name, Size = size, Position = position, BackgroundTransparency = 1,
        Text = value, TextSize = fontSize or 13, Font = Enum.Font.Gotham,
        TextColor3 = color or colors.paper, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
end

local function panel(parent, name)
    local frame = create("Frame", parent, {
        Name = name, BackgroundColor3 = colors.ink, BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
    })
    trim(frame)
    return frame
end

function Hud.new(playerGui, sailing, treasures)
    local self = setmetatable({}, {__index = Hud})
    self.gui = create("ScreenGui", playerGui, {
        Name = "PirateOceanHud", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    self.buttons, self.details, self.stageIndicators, self.collectionRows = {}, {}, {}, {}
    self.ready, self.pending, self.atHelm = false, false, false
    self.header = panel(self.gui, "ShipLedger")
    self.brand = text(self.header, "Brand", UDim2.new(0.6, 0, 0, 28), UDim2.fromOffset(14, 7), "PIRATE OCEAN", 25, colors.brass)
    self.brand.Font = Enum.Font.Garamond
    self.gold = text(self.header, "Gold", UDim2.new(0.4, -22, 0, 28), UDim2.new(0.6, 0, 0, 7), "-- GOLD", 14, colors.brass)
    self.gold.Font, self.gold.TextXAlignment = Enum.Font.GothamBold, Enum.TextXAlignment.Right
    self.ship = text(self.header, "Ship", UDim2.new(1, -28, 0, 20), UDim2.fromOffset(14, 36), "Preparing your vessel", 12, colors.muted)
    self.health = text(self.header, "Hull", UDim2.new(0.5, -14, 0, 20), UDim2.fromOffset(14, 61), "HULL  -- / --", 12)
    self.cargo = text(self.header, "Cargo", UDim2.new(0.5, -14, 0, 20), UDim2.new(0.5, 0, 0, 61), "HOLD  -- / --", 12)
    self.cargo.TextXAlignment = Enum.TextXAlignment.Right
    local track = create("Frame", self.header, {
        Name = "HullTrack", Size = UDim2.new(1, -28, 0, 5), Position = UDim2.fromOffset(14, 89),
        BackgroundColor3 = colors.panel, BorderSizePixel = 0, ClipsDescendants = true,
    })
    self.healthFill = create("Frame", track, {Name = "HullHealth", Size = UDim2.fromScale(0, 1), BackgroundColor3 = colors.sea, BorderSizePixel = 0})
    self.playerPanel = panel(self.gui, "PlayerVitals")
    self.playerHealth = text(self.playerPanel, "PlayerHealth", UDim2.new(0.6, -12, 0, 20), UDim2.fromOffset(10, 2), "PLAYER  -- / --", 11)
    self.bounty = text(self.playerPanel, "Bounty", UDim2.new(0.4, -12, 0, 20), UDim2.new(0.6, 0, 0, 2), "BOUNTY 0", 10, colors.brass)
    self.bounty.TextXAlignment = Enum.TextXAlignment.Right
    self.bounty.TextWrapped, self.bounty.TextTruncate = true, Enum.TextTruncate.None
    local playerTrack = create("Frame", self.playerPanel, {Name = "PlayerHealthTrack", Size = UDim2.new(1, -20, 0, 4), Position = UDim2.fromOffset(10, 23), BackgroundColor3 = colors.panel, BorderSizePixel = 0})
    self.playerHealthFill = create("Frame", playerTrack, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(183, 77, 72), BorderSizePixel = 0})
    self.stamina = text(self.playerPanel, "Stamina", UDim2.new(1, -20, 0, 18), UDim2.fromOffset(10, 29), "STAMINA  -- / --", 10, colors.muted)
    local staminaTrack = create("Frame", self.playerPanel, {Name = "StaminaTrack", Size = UDim2.new(1, -20, 0, 4), Position = UDim2.fromOffset(10, 50), BackgroundColor3 = colors.panel, BorderSizePixel = 0})
    self.staminaFill = create("Frame", staminaTrack, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = colors.brass, BorderSizePixel = 0})
    self.notice = panel(self.gui, "CaptainNotice")
    self.noticeText = text(self.notice, "Message", UDim2.new(1, -24, 1, 0), UDim2.fromOffset(12, 0), "Harbor", 12)
    self.noticeText.TextWrapped, self.noticeText.TextTruncate = true, Enum.TextTruncate.None
    self.actions = create("Frame", self.gui, {Name = "Orders", BackgroundTransparency = 1})
    self.grid = create("UIGridLayout", self.actions, {
        CellSize = UDim2.new(1 / 3, -4, 0, 48), CellPadding = UDim2.fromOffset(6, 6),
        SortOrder = Enum.SortOrder.LayoutOrder, FillDirectionMaxCells = 3,
    })
    self.stageBar = panel(self.gui, "SailingStages")
    self.telemetry = {}
    for index, name in ipairs({"Speed", "Sail", "Anchor"}) do
        local value = text(self.stageBar, name, UDim2.new(1 / 3, -8, 0, 38), UDim2.new((index - 1) / 3, 4, 0, 4), name:upper() .. "\n--", 11, colors.muted)
        value.TextXAlignment, value.TextWrapped = Enum.TextXAlignment.Center, true
        self.telemetry[name] = value
    end
    local stageCount = sailing.MaxStage - sailing.MinStage + 1
    for stage = sailing.MinStage, sailing.MaxStage do
        local indicator = create("TextLabel", self.stageBar, {
            Name = "Stage" .. stage, Text = sailing.Stages[stage].name,
            Size = UDim2.new(1 / stageCount, -6, 0, 30),
            Position = UDim2.new((stage - sailing.MinStage) / stageCount, 4, 0, 46),
            BackgroundColor3 = colors.panel, BorderSizePixel = 0,
            TextColor3 = colors.muted, Font = Enum.Font.GothamBold, TextSize = 11,
        })
        trim(indicator, colors.muted)
        self.stageIndicators[stage] = indicator
    end
    self.sailing = sailing
    self.stageBar.Visible = false
    self.combatBar = panel(self.gui, "CombatOrders")
    self.combatBar.Visible = false
    self.combatStatus = text(self.combatBar, "Stance", UDim2.new(1, -20, 0, 24), UDim2.fromOffset(10, 2), "CUTLASS / READY", 11, colors.brass)
    self.combatButtons = create("Frame", self.combatBar, {Name = "Moves", Size = UDim2.new(1, -12, 0, 94), Position = UDim2.fromOffset(6, 30), BackgroundTransparency = 1})
    create("UIGridLayout", self.combatButtons, {CellSize = UDim2.new(1 / 3, -4, 0, 44), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, FillDirectionMaxCells = 3})

    self.overlay = create("TextButton", self.gui, {
        Name = "CollectionOverlay", Size = UDim2.fromScale(1, 1), Text = "",
        BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35,
        BorderSizePixel = 0, AutoButtonColor = false, Visible = false, ZIndex = 10,
        Modal = true,
    })
    self.collection = panel(self.overlay, "TreasureLedger")
    self.collection.AnchorPoint, self.collection.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
    self.collection.ZIndex, self.collection.Active = 11, true
    local title = text(self.collection, "Title", UDim2.new(1, -70, 0, 32), UDim2.fromOffset(16, 12), "TREASURE LEDGER", 22, colors.brass)
    title.Font, title.ZIndex = Enum.Font.Garamond, 12
    self.collectionCount = text(self.collection, "Discovered", UDim2.new(1, -32, 0, 20), UDim2.fromOffset(16, 46), "0 discovered", 12, colors.muted)
    self.collectionCount.ZIndex = 12
    local close = create("TextButton", self.collection, {
        Name = "Close", Text = "X", Size = UDim2.fromOffset(40, 40), Position = UDim2.new(1, -50, 0, 10),
        BackgroundColor3 = colors.panel, TextColor3 = colors.paper, Font = Enum.Font.GothamBold,
        TextSize = 16, BorderSizePixel = 0, ZIndex = 12,
    })
    trim(close)
    close.Activated:Connect(function() self:toggleCollection(false) end)
    self.overlay.Activated:Connect(function() self:toggleCollection(false) end)
    local scroll = create("ScrollingFrame", self.collection, {
        Name = "Treasures", Size = UDim2.new(1, -32, 1, -88), Position = UDim2.fromOffset(16, 76),
        BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4,
        ScrollBarImageColor3 = colors.brass, ZIndex = 12,
    })
    create("UIListLayout", scroll, {Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder})
    local ids = {}
    for id in pairs(treasures.Items) do table.insert(ids, id) end
    table.sort(ids, function(a, b)
        local rankA, rankB = treasures.SellValues[treasures.Items[a].rarity], treasures.SellValues[treasures.Items[b].rarity]
        return rankA == rankB and a < b or rankA < rankB
    end)
    self.totalTreasures = #ids
    for order, id in ipairs(ids) do
        local item = treasures.Items[id]
        local row = create("Frame", scroll, {Name = id, Size = UDim2.new(1, -8, 0, 58), LayoutOrder = order, BackgroundTransparency = 1, ZIndex = 12})
        create("Frame", row, {Size = UDim2.fromOffset(3, 32), Position = UDim2.fromOffset(0, 12), BackgroundColor3 = rarityColors[item.rarity], BorderSizePixel = 0, ZIndex = 13})
        local name = text(row, "Name", UDim2.new(1, -72, 0, 24), UDim2.fromOffset(13, 7), (id:gsub("(%l)(%u)", "%1 %2")), 14)
        local rarity = text(row, "Rarity", UDim2.new(1, -72, 0, 18), UDim2.fromOffset(13, 31), item.rarity:upper(), 10, rarityColors[item.rarity])
        local amount = text(row, "Amount", UDim2.fromOffset(54, 42), UDim2.new(1, -54, 0, 7), "--", 16, colors.muted)
        amount.TextXAlignment, amount.Font = Enum.TextXAlignment.Right, Enum.Font.GothamBold
        name.ZIndex, rarity.ZIndex, amount.ZIndex = 13, 13, 13
        create("Frame", row, {Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), BackgroundColor3 = colors.muted, BackgroundTransparency = 0.85, BorderSizePixel = 0, ZIndex = 13})
        self.collectionRows[id] = {name = name, amount = amount}
    end
    self.resizeConnection = self.gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:layout() end)
    self.gui.Destroying:Connect(function() self.resizeConnection:Disconnect() end)
    self:layout()
    return self
end

function Hud:layout()
    local size = self.gui.AbsoluteSize
    local width, height = size.X, size.Y
    if width <= 0 or height <= 0 then return end
    local compact = height < 500
    local singleRow = compact and width >= 540
    local hudWidth = singleRow and math.min(width * 0.45 - 24, 360) or math.min(width - 24, 440)
    self.brand.TextSize = singleRow and 20 or 25
    self.gold.TextSize = singleRow and 12 or 14
    self.header.Size, self.header.Position = UDim2.fromOffset(hudWidth, compact and 86 or 106), UDim2.fromOffset(12, 8)
    self.health.Position, self.cargo.Position = UDim2.fromOffset(14, compact and 53 or 61), UDim2.new(0.5, 0, 0, compact and 53 or 61)
    self.healthFill.Parent.Position = UDim2.fromOffset(14, compact and 78 or 89)
    self.ship.Position = UDim2.fromOffset(14, compact and 32 or 36)
    self.notice.Size, self.notice.Position = UDim2.fromOffset(hudWidth, 40), UDim2.fromOffset(12, compact and 100 or 120)
    local separateVitals = width >= 900 and not singleRow
    self.playerPanel.Size = UDim2.fromOffset(separateVitals and 300 or hudWidth, compact and 54 or 60)
    if separateVitals then
        self.playerPanel.AnchorPoint, self.playerPanel.Position = Vector2.new(1, 0), UDim2.new(1, -12, 0, 8)
    else
        self.playerPanel.AnchorPoint, self.playerPanel.Position = Vector2.zero, UDim2.fromOffset(12, compact and 100 or 122)
        self.notice.Size = UDim2.fromOffset(hudWidth, compact and 28 or 40)
        self.notice.Position = UDim2.fromOffset(12, compact and 160 or 190)
    end
    local touchBottom = Input.TouchEnabled and 88 or 80
    local dockWidth = math.min(width - (Input.TouchEnabled and 128 or 24), 620)
    dockWidth = math.max(180, dockWidth)
    local dockHeight = singleRow and 48 or 102
    self.grid.FillDirectionMaxCells = singleRow and 6 or 3
    self.grid.CellSize = UDim2.new(1 / (singleRow and 6 or 3), -5, 0, 48)
    self.actions.Size = UDim2.fromOffset(dockWidth, dockHeight)
    self.actions.AnchorPoint, self.actions.Position = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -touchBottom)
    local stageWidth = singleRow and math.min(width * 0.5 - 24, 440) or dockWidth
    self.stageBar.Size = UDim2.fromOffset(stageWidth, 82)
    if singleRow then
        self.stageBar.AnchorPoint, self.stageBar.Position = Vector2.new(1, 0), UDim2.new(1, -12, 0, 8)
    else
        self.stageBar.AnchorPoint, self.stageBar.Position = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -touchBottom - dockHeight - 8)
    end
    self.combatBar.Size = UDim2.fromOffset(stageWidth, 130)
    if singleRow then
        self.combatBar.AnchorPoint, self.combatBar.Position = self.stageBar.AnchorPoint, self.stageBar.Position
    else
        self.combatBar.AnchorPoint, self.combatBar.Position = self.actions.AnchorPoint, self.actions.Position
    end
    self.collection.Size = UDim2.fromOffset(math.min(width - 24, 520), math.min(height - 24, 510))
    local shortStages = {[-1] = "REV", [0] = "STOP", [1] = "OARS", [2] = "I", [3] = "II"}
    for stage, indicator in pairs(self.stageIndicators) do
        indicator.Text = stageWidth < 360 and shortStages[stage] or self.sailing.Stages[stage].name
    end
    self.touchControlY = -touchBottom - dockHeight - (singleRow and 72 or 150)
end

function Hud:addButton(name, order, title, callback)
    local button = create("TextButton", self.actions, {
        Name = name, LayoutOrder = order, Text = "", BackgroundColor3 = colors.panel,
        BorderSizePixel = 0, AutoButtonColor = false,
    })
    local border = trim(button)
    local heading = text(button, "Title", UDim2.new(1, -8, 0, 22), UDim2.fromOffset(4, 4), title, 12)
    heading.Font, heading.TextXAlignment = Enum.Font.GothamBold, Enum.TextXAlignment.Center
    local detail = text(button, "Detail", UDim2.new(1, -8, 0, 16), UDim2.fromOffset(4, 27), "", 10, colors.muted)
    detail.TextXAlignment = Enum.TextXAlignment.Center
    if name == "Sail" then button.BackgroundColor3 = colors.sea end
    if name == "Fire" then heading.TextColor3 = Color3.fromRGB(236, 152, 137) end
    button.MouseEnter:Connect(function() border.Transparency = 0.05 end)
    button.MouseLeave:Connect(function() border.Transparency = 0.55 end)
    button.SelectionGained:Connect(function() border.Transparency = 0.05 end)
    button.SelectionLost:Connect(function() border.Transparency = 0.55 end)
    button.Activated:Connect(function()
        if name == "Collection" or (self.ready and not self.pending) then callback() end
    end)
    self.buttons[name], self.details[name] = {button = button, heading = heading}, detail
end

function Hud:showNotice(message, isError)
    self.noticeText.Text = message
    self.notice.BackgroundColor3 = isError and Color3.fromRGB(76, 36, 34) or colors.ink
end

function Hud:setPending(pending)
    self.pending = pending
    for name, entry in pairs(self.buttons) do
        local available = name == "Collection" or (self.ready and not pending)
        entry.button.Active, entry.button.Selectable = available, available
        entry.heading.TextTransparency = available and 0 or 0.5
        self.details[name].TextTransparency = available and 0 or 0.5
    end
end

function Hud:setStage(stage)
    if self.stage == stage then return end
    self.stage = stage
    for index, indicator in pairs(self.stageIndicators) do
        indicator.BackgroundColor3 = index == stage and colors.sea or colors.panel
        indicator.TextColor3 = index == stage and colors.paper or colors.muted
        indicator.UIStroke.Color = index == stage and colors.brass or colors.muted
        indicator.UIStroke.Transparency = index == stage and 0.2 or 0.75
    end
end

function Hud:setHelm(enabled)
    self.atHelm = enabled
    self.stageBar.Visible = enabled and not self.overlay.Visible
    self.combatBar.Visible = self.combatEquipped == true and not enabled and not self.overlay.Visible
    self.actions.Visible = not self.overlay.Visible and (enabled or not self.combatEquipped)
end

function Hud:addCombatButton(title, order, callback)
    local button = create("TextButton", self.combatButtons, {
        Name = title, LayoutOrder = order, Text = title, Font = Enum.Font.GothamBold,
        TextSize = 11, BackgroundColor3 = colors.panel, TextColor3 = colors.paper, BorderSizePixel = 0,
    })
    trim(button)
    button.Activated:Connect(callback)
    return button
end

function Hud:setCombat(enabled, state)
    self.combatEquipped = enabled
    self.combatBar.Visible = enabled and not self.atHelm and not self.overlay.Visible
    self.actions.Visible = not self.overlay.Visible and (self.atHelm or not enabled)
    self.combatStatus.Text = "CUTLASS / " .. (state or "Ready"):upper()
    local guard = self.combatButtons:FindFirstChild("Block")
    if guard then guard.Text = state == "Guarding" and "Release" or "Block" end
end

function Hud:updatePlayer(health, maxHealth, stamina, maxStamina)
    self.playerHealth.Text = string.format("PLAYER  %d / %d", math.ceil(health), maxHealth)
    self.playerHealthFill.Size = UDim2.fromScale(math.clamp(health / math.max(1, maxHealth), 0, 1), 1)
    self.stamina.Text = string.format("STAMINA  %d / %d", math.floor(stamina), maxStamina)
    self.staminaFill.Size = UDim2.fromScale(math.clamp(stamina / math.max(1, maxStamina), 0, 1), 1)
end

function Hud:toggleCollection(visible)
    if visible == nil then visible = not self.overlay.Visible end
    self.overlay.Visible = visible
    self.actions.Visible = not visible and (self.atHelm or not self.combatEquipped)
    self.stageBar.Visible = self.atHelm and not visible
    self.combatBar.Visible = self.combatEquipped == true and not self.atHelm and not visible
end

function Hud:update(data, ships, islands)
    self.ready = not data.player or data.player.health > 0
    local profile, stats, state = data.profile, data.ship.stats, data.ship.state
    local cargo, discovered = 0, 0
    for _, amount in pairs(profile.cargo) do cargo += amount end
    for id, row in pairs(self.collectionRows) do
        local amount = profile.collection[id] or 0
        if amount > 0 then discovered += 1 end
        row.name.TextColor3 = amount > 0 and colors.paper or colors.muted
        row.amount.Text, row.amount.TextColor3 = amount > 0 and tostring(amount) or "--", amount > 0 and colors.brass or colors.muted
    end
    self.gold.Text = string.format("%d GOLD", profile.gold)
    local bounty = profile.bounty or 0
    local amount = bounty >= 1000000 and string.format("%.1fM", bounty / 1000000) or bounty >= 1000 and string.format("%.1fK", bounty / 1000) or tostring(bounty)
    self.bounty.Text = "BOUNTY " .. amount
    if data.player then self:updatePlayer(data.player.health, data.player.maxHealth, data.player.stamina, data.player.maxStamina) end
    self.ship.Text = string.format("%s  /  %s  /  SEA %d", profile.currentShipTier:upper(), state.inVoyage and "UNDERWAY" or "HARBOR", state.currentDepth)
    self.health.Text = string.format("HULL  %d / %d", state.health, stats.maxHealth)
    self.cargo.Text = string.format("HOLD  %d / %d", cargo, stats.cargoSlots)
    self.cargo.TextColor3 = cargo >= stats.cargoSlots and colors.brass or colors.paper
    local health = math.clamp(state.health / math.max(1, stats.maxHealth), 0, 1)
    self.healthFill.BackgroundColor3 = health <= 0.3 and colors.red or colors.sea
    if self.healthTween then self.healthTween:Cancel() end
    self.healthTween = TweenService:Create(self.healthFill, TweenInfo.new(0.25), {Size = UDim2.fromScale(health, 1)})
    self.healthTween:Play()
    self.collectionCount.Text = string.format("%d / %d treasures discovered", discovered, self.totalTreasures)
    self.buttons.Sail.heading.Text = state.inVoyage and "Dock" or "Set Sail"
    self.details.Sail.Text = state.inVoyage and "Harbor" or "Depart"
    local island = data.nearestIsland and islands.Islands[data.nearestIsland]
    self.details.Collect.Text = island and island.displayName or "Island loot"
    self.details.Sell.Text = string.format("%d in hold", cargo)
    local nextTier = ships.getNextTier(profile.currentShipTier)
    self.buttons.Upgrade.heading.Text = nextTier and "Upgrade" or "Max Ship"
    self.details.Upgrade.Text = nextTier and string.format("%d gold", ships.Tiers[nextTier].cost) or profile.currentShipTier
    self.details.Fire.Text = "Kraken"
    self.details.Collection.Text = string.format("%d / %d found", discovered, self.totalTreasures)
    if data.sailing then
        local sailing = data.sailing
        local anchor = sailing.anchorDown and (sailing.anchorRaising and "HAULING" or "DOWN") or "UP"
        self.telemetry.Speed.Text = string.format("SPEED\n%.1f", sailing.speed)
        self.telemetry.Sail.Text = string.format("SAIL\n%d%%", math.floor(sailing.deployment * 100))
        self.telemetry.Anchor.Text = "ANCHOR\n" .. anchor
        self:setStage(sailing.stage)
    end
    self:setPending(self.pending)
end

return Hud
