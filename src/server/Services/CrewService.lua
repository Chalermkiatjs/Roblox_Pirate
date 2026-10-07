local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedRoot = ReplicatedStorage:WaitForChild("PirateOcean")
local CrewConfig = require(sharedRoot.CrewConfig)
local ShipConfig = require(sharedRoot.ShipConfig)
local DataService = require(script.Parent.DataService)

local CrewService = {}

local function assignedCount(crew)
    local count = 0
    for _, recruitId in pairs(crew) do
        if recruitId then
            count += 1
        end
    end
    return count
end

function CrewService.assignRecruit(player, recruitId)
    local profile = DataService.getProfile(player)
    local recruit = CrewConfig.Recruits[recruitId]

    if not profile or not recruit then
        return { ok = false, error = "InvalidRecruit" }
    end

    local tier = ShipConfig.getTier(profile.currentShipTier)
    if assignedCount(profile.crew) >= tier.crewSlots and not profile.crew[recruit.role] then
        return { ok = false, error = "NoCrewSlot" }
    end

    if not profile.crew[recruit.role] and not DataService.spendGold(player, recruit.cost) then
        return { ok = false, error = "NotEnoughGold", required = recruit.cost }
    end

    profile.crew[recruit.role] = recruitId

    return {
        ok = true,
        role = recruit.role,
        recruitId = recruitId,
        crew = profile.crew,
    }
end

return CrewService

