local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local sharedRoot = ReplicatedStorage:WaitForChild("PirateOcean")
local remotes = sharedRoot:WaitForChild("Remotes")

local function safeInvoke(remoteName, ...)
    local remote = remotes:WaitForChild(remoteName)
    local ok, result = pcall(function(...)
        return remote:InvokeServer(...)
    end, ...)

    if not ok then
        warn(`Remote {remoteName} failed: {result}`)
        return nil
    end

    return result
end

local function createHud()
    local gui = Instance.new("ScreenGui")
    gui.Name = "PirateOceanHud"
    gui.ResetOnSpawn = false

    local label = Instance.new("TextLabel")
    label.Name = "Status"
    label.Size = UDim2.fromOffset(420, 96)
    label.Position = UDim2.fromOffset(24, 24)
    label.BackgroundTransparency = 0.25
    label.BackgroundColor3 = Color3.fromRGB(20, 31, 39)
    label.TextColor3 = Color3.fromRGB(242, 236, 220)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.Font = Enum.Font.Gotham
    label.TextSize = 16
    label.Parent = gui

    gui.Parent = player:WaitForChild("PlayerGui")
    return label
end

local function countDictionary(dictionary)
    local count = 0
    for _, amount in pairs(dictionary or {}) do
        count += amount
    end
    return count
end

local statusLabel = createHud()
local snapshot = safeInvoke("RequestSnapshot")

if snapshot and snapshot.profile and snapshot.ship then
    statusLabel.Text = string.format(
        "PirateOcean MVP\nGold: %d\nShip: %s\nCargo items: %d",
        snapshot.profile.gold,
        snapshot.profile.currentShipTier,
        countDictionary(snapshot.profile.cargo)
    )
else
    statusLabel.Text = "PirateOcean MVP\nWaiting for profile..."
end

_G.PirateOceanDebug = {
    prepareVoyage = function()
        return safeInvoke("PrepareVoyage")
    end,
    exploreIsland = function(islandId)
        return safeInvoke("ExploreIsland", islandId)
    end,
    triggerOceanEvent = function(depth)
        return safeInvoke("TriggerOceanEvent", depth)
    end,
    attackKraken = function()
        return safeInvoke("AttackKraken")
    end,
    upgradeShip = function()
        return safeInvoke("UpgradeShip")
    end,
    assignCrew = function(recruitId)
        return safeInvoke("AssignCrew", recruitId)
    end,
    sellCargo = function()
        return safeInvoke("SellCargo")
    end,
}
