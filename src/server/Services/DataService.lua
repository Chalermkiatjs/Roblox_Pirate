local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedRoot = ReplicatedStorage:WaitForChild("PirateOcean")
local Constants = require(sharedRoot.Constants)
local SaveSchema = require(sharedRoot.SaveSchema)

local DataService = {}

local store = DataStoreService:GetDataStore(Constants.DataStoreName)
local profiles = {}

local function keyFor(player)
    return `player_{player.UserId}`
end

function DataService.loadProfile(player)
    local success, data = pcall(function()
        return store:GetAsync(keyFor(player))
    end)

    if not success then
        warn(`Failed to load profile for {player.UserId}: {data}`)
    end

    profiles[player] = SaveSchema.mergeDefaults(success and data or nil)
    return profiles[player]
end

function DataService.getProfile(player)
    return profiles[player]
end

function DataService.saveProfile(player)
    local profile = profiles[player]
    if not profile then
        return false
    end

    local success, err = pcall(function()
        store:SetAsync(keyFor(player), profile)
    end)

    if not success then
        warn(`Failed to save profile for {player.UserId}: {err}`)
    end

    return success
end

function DataService.releaseProfile(player)
    profiles[player] = nil
end

function DataService.addGold(player, amount)
    local profile = DataService.getProfile(player)
    if not profile then
        return
    end

    profile.gold += amount
end

function DataService.spendGold(player, amount)
    local profile = DataService.getProfile(player)
    if not profile or profile.gold < amount then
        return false
    end

    profile.gold -= amount
    return true
end

function DataService.addCargo(player, itemId, amount)
    local profile = DataService.getProfile(player)
    if not profile then
        return
    end

    profile.cargo[itemId] = (profile.cargo[itemId] or 0) + amount
end

function DataService.addCollection(player, itemId, amount)
    local profile = DataService.getProfile(player)
    if not profile then
        return
    end

    profile.collection[itemId] = (profile.collection[itemId] or 0) + amount
end

return DataService

