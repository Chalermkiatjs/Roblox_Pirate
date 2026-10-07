local services = script.Parent.Parent.Services
local Physics = require(services.ShipPhysics)

return function()
    assert(game:GetService("RunService"):IsStudio(), "Run only during Studio Play on the server")
    local model = Instance.new("Model")
    model.Name, model.Parent = "WaterSmokeBoat", workspace
    local hull = Instance.new("Part")
    hull.Name, hull.Size = "Hull", Vector3.new(12, 3, 20)
    hull.Position, hull.Anchored = Vector3.new(-300, 1, -100), true
    hull.Parent, model.PrimaryPart = model, hull
    local rig = Physics.attach(model, hull)
    local connection
    local ok, err = pcall(function()
        local region = Region3.new(Vector3.new(-304, -8, -104), Vector3.new(-296, -4, -96)):ExpandToGrid(4)
        local materials = workspace.Terrain:ReadVoxels(region, 4)
        assert(materials[1][1][1] == Enum.Material.Water, "Ocean water missing")
        Physics.setActive(rig, true)
        connection = game:GetService("RunService").PreSimulation:Connect(function(dt)
            Physics.update(rig, math.min(dt, 0.1), 0, 0, 18)
        end)
        task.wait(6)
        assert(hull.Position.Y > -2 and hull.Position.Y < 3, "Hull does not float near water surface")
        assert(math.abs(hull.AssemblyLinearVelocity.Y) < 5, "Buoyancy is unstable")
        assert(hull.CFrame.UpVector.Y > 0.9, "Hull capsized")
        Physics.setActive(rig, false)
        assert(hull.Anchored and hull.AssemblyLinearVelocity.Magnitude < 0.01, "Docking does not stop the boat")
    end)
    if connection then connection:Disconnect() end
    model:Destroy()
    assert(ok, err)
    print("PirateOcean water and buoyancy smoke test passed")
end
