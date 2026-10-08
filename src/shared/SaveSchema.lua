local Constants = require(script.Parent.Constants)
local Combat = require(script.Parent.CombatConfig)
local Rules = require(script.Parent.Util.CombatRules)

local SaveSchema = {}

SaveSchema.DefaultProfile = {
    schemaVersion = Constants.SchemaVersion,
    gold = 0,
    bounty = 0,
    currentShipTier = "Raft",
    discoveredIslands = {},
    collection = {},
    cargo = {},
    crew = {
        navigator = nil,
        gunner = nil,
        quartermaster = nil,
    },
    stats = {
        voyages = 0,
        krakenDefeats = 0,
        combatDefeats = 0,
        deepestDepth = 0,
    },
}

local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, child in pairs(value) do
        copy[key] = deepCopy(child)
    end
    return copy
end

function SaveSchema.createDefaultProfile()
    return deepCopy(SaveSchema.DefaultProfile)
end

function SaveSchema.mergeDefaults(profile)
    local merged = SaveSchema.createDefaultProfile()

    local function merge(target, source)
        for key, value in pairs(source) do
            if type(value) == "table" and type(target[key]) == "table" then
                merge(target[key], value)
            else
                target[key] = value
            end
        end
    end

    if type(profile) == "table" then
        merge(merged, profile)
    end

    merged.schemaVersion = Constants.SchemaVersion
    merged.bounty = Rules.bounty(merged.bounty, 0, Combat.MaxBounty)
    return merged
end

return SaveSchema
