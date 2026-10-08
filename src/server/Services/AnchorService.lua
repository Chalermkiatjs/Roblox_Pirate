local shared = game:GetService("ReplicatedStorage"):WaitForChild("PirateOcean")
local Config = require(shared.WorldConfig).Docking
local FrigateConfig = require(shared.FrigateConfig)
local Motion = require(shared.Util.AnchorMotion)
local Anchor = {}

function Anchor.create(model, hull, imported, length, callback)
    local center = imported and Vector3.new(0,
        (6.35 + 0.55 * (15 / 21)^4 + FrigateConfig.VisualOffset[2]) * FrigateConfig.ArtScale,
        -15 * FrigateConfig.ArtScale) or Vector3.new(0, 2.5, -length * 0.28)
    local function piece(name, size, offset, color)
        local p = Instance.new("Part")
        p.Name, p.Size, p.CFrame = name, size, hull.CFrame * CFrame.new(center) * offset
        p.Color, p.Material = color, Enum.Material.Metal
        p.Massless, p.CanCollide, p.CanTouch = true, false, false
        p.EnableFluidForces = false
        p.Parent = model
        local joint = Instance.new("Motor6D")
        joint.Name, joint.Part0, joint.Part1 = name .. "Joint", hull, p
        joint.C0 = hull.CFrame:ToObjectSpace(p.CFrame)
        joint.Parent = hull
        return p, joint, joint.C0
    end
    local metal, wood = Color3.fromRGB(63, 70, 74), Color3.fromRGB(149, 105, 60)
    local base = piece("AnchorCapstan", Vector3.new(2.2, 0.4, 2.2), CFrame.new(0, 0.2, 0), metal)
    local drum = piece("CapstanDrum", Vector3.new(2, 1.5, 1.5),
        CFrame.new(0, 1.4, 0) * CFrame.Angles(0, 0, math.pi / 2), wood)
    drum.Shape = Enum.PartType.Cylinder
    local bars = {}
    for i = 0, 1 do
        local _, joint, c0 = piece("CapstanHandle" .. i, Vector3.new(5.5, 0.25, 0.25),
            CFrame.new(0, 2.3, 0) * CFrame.Angles(0, i * math.pi / 2, 0), wood)
        table.insert(bars, {joint = joint, c0 = c0})
    end
    if not imported then
        local side = hull.Size.X / 2 + 0.5
        piece("AnchorChain", Vector3.new(0.16, 3.8, 0.16), CFrame.new(side, -1.4, -2), metal)
        piece("BowAnchorShank", Vector3.new(0.3, 2.4, 0.3), CFrame.new(side, -4, -2), metal)
        piece("BowAnchorStock", Vector3.new(1.8, 0.25, 0.25), CFrame.new(side, -3.5, -2), metal)
        for _, sign in ipairs({-1, 1}) do
            piece("BowAnchorFluke", Vector3.new(1.4, 0.3, 0.3),
                CFrame.new(side + sign * 0.5, -5, -2) * CFrame.Angles(0, 0, sign * math.pi / 6), metal)
        end
    end
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name, prompt.ObjectText, prompt.ActionText = "AnchorPrompt", "Bow capstan", "Drop anchor"
    prompt.KeyboardKeyCode, prompt.GamepadKeyCode = Enum.KeyCode.E, Enum.KeyCode.ButtonX
    prompt.MaxActivationDistance, prompt.RequiresLineOfSight, prompt.HoldDuration = Config.PromptRange, false, 0
    prompt.Enabled, prompt.Parent = false, base
    prompt.Triggered:Connect(callback)
    local gui = Instance.new("BillboardGui")
    gui.Name, gui.Size, gui.StudsOffset = "AnchorProgress", UDim2.fromOffset(180, 32), Vector3.new(0, 4, 0)
    gui.AlwaysOnTop, gui.MaxDistance, gui.Enabled, gui.Parent = true, 24, false, base
    local label = Instance.new("TextLabel")
    label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 0.2
    label.BackgroundColor3, label.TextColor3 = Color3.fromRGB(27, 32, 36), Color3.new(1, 1, 1)
    label.Font, label.TextSize, label.Parent = Enum.Font.GothamBold, 14, gui
    return {base = base, center = center, bars = bars, prompt = prompt, gui = gui, label = label, angle = 0}
end

function Anchor.nearby(player, boat)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root or not humanoid or humanoid.Health <= 0 or humanoid.SeatPart then return nil end
    if (root.Position - boat.anchor.base.Position).Magnitude > Config.PromptRange then return nil end
    return root, humanoid
end

function Anchor.reset(boat)
    local station = boat.anchor
    station.raising, station.previous, station.angle = false, nil, 0
    station.gui.Enabled = false
    station.prompt.ActionText = boat.anchorDown and "Raise anchor" or "Drop anchor"
    boat.model:SetAttribute("AnchorRaising", false)
    boat.model:SetAttribute("AnchorProgress", 0)
    for _, bar in ipairs(station.bars) do bar.joint.C0 = bar.c0 end
end

function Anchor.begin(boat)
    if boat.anchor.raising then return end
    boat.anchor.raising, boat.anchor.previous = true, nil
    boat.anchor.gui.Enabled = true
    boat.anchor.label.Text = "Anchor 0%"
    boat.anchor.prompt.ActionText = "Continue raising"
    boat.model:SetAttribute("AnchorRaising", true)
end

function Anchor.update(player, boat, dt, inVoyage)
    local station = boat.anchor
    station.prompt.Enabled = inVoyage
    if not station.raising then return false end
    local root, humanoid = Anchor.nearby(player, boat)
    local pos = root and boat.rig.hull.CFrame:PointToObjectSpace(root.Position) - station.center
    local radius = pos and Vector2.new(pos.X, pos.Z).Magnitude
    if not inVoyage or not pos or radius < Config.MinRadius or radius > Config.MaxRadius
        or math.abs(pos.Y) > Config.MaxHeight or humanoid.FloorMaterial == Enum.Material.Air then
        station.previous = nil
        return false
    end
    -- Signed winding prevents pacing back and forth from counting as full turns.
    local delta = Motion.step(station.previous, pos.X, pos.Z, dt, Config.MaxWalkSpeed)
    station.previous = {x = pos.X, z = pos.Z}
    station.angle += delta
    local progress = math.clamp(math.abs(station.angle) / (Config.RaiseTurns * math.pi * 2), 0, 1)
    for _, bar in ipairs(station.bars) do
        bar.joint.C0 = CFrame.new(station.center) * CFrame.Angles(0, -station.angle, 0)
            * CFrame.new(-station.center) * bar.c0
    end
    station.label.Text = string.format("Anchor %d%%", math.floor(progress * 100))
    boat.model:SetAttribute("AnchorProgress", progress)
    return progress >= 1
end

return Anchor
