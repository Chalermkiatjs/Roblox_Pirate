local services = script.Parent.Parent.Services
local Combat = require(services.CombatService)
local Ship = require(services.ShipService)
local Data = require(services.DataService)
local shared = game:GetService("ReplicatedStorage"):WaitForChild("PirateOcean")
local Schema = require(shared.SaveSchema)

return function()
    assert(game:GetService("RunService"):IsStudio(), "Use temporary Studio data only")
    local character, backpack, added = Instance.new("Model"), Instance.new("Folder"), Instance.new("BindableEvent")
    character.Name, character.Parent = "CombatHealthSmoke", workspace
    local root = Instance.new("Part")
    root.Name, root.Anchored, root.Position, root.Parent = "HumanoidRootPart", true, Vector3.new(1500, 200, 1500), character
    local humanoid = Instance.new("Humanoid")
    humanoid.RequiresNeck, humanoid.Parent = false, character
    local player = {UserId = -999998, Character = character, CharacterAdded = added.Event, Parent = workspace}
    function player:WaitForChild(name) if name == "Backpack" then return backpack end end
    local ok, err = pcall(function()
        local migrated = Schema.mergeDefaults({gold = 123, schemaVersion = 1})
        assert(migrated.gold == 123 and migrated.bounty == 0 and migrated.stats.combatDefeats == 0)
        local profile = Data.loadProfile(player)
        Ship.spawnShipState(player)
        Combat.addPlayer(player)
        task.wait()
        assert(Combat.getSnapshot(player).health == 100)
        humanoid:TakeDamage(25)
        assert(Combat.getSnapshot(player).health == 75 and Ship.getState(player).health == 100, "Player damage changes ship HP")
        Ship.damage(player, 40)
        assert(Ship.getState(player).health == 60 and humanoid.Health == 75, "Ship damage changes player HP")
        Data.addBounty(player, 50)
        assert(profile.bounty == 50 and profile.gold == 0, "Bounty affects gold")
        humanoid:TakeDamage(100)
        assert(Ship.getState(player).health == 60 and profile.bounty == 50, "Player defeat resets ship HP or bounty")
    end)
    Combat.removePlayer(player)
    Ship.releaseShipState(player)
    Data.releaseProfile(player)
    character:Destroy()
    backpack:Destroy()
    added:Destroy()
    assert(ok, err)
    print("PASS: player/ship health isolation and old-profile bounty migration")
end
