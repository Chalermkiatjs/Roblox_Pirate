local RunService = game:GetService("RunService")
local services = script.Parent.Parent.Services
local Visual = require(services.FrigateVisual)
local Physics = require(services.ShipPhysics)

return function()
    assert(RunService:IsStudio() and RunService:IsServer(), "Run during Studio Play on the server")
    Visual.prepareTemplate()
    local shared = game:GetService("ReplicatedStorage"):WaitForChild("PirateOcean")
    local imports = require(shared.FrigateImports)
    local config = require(shared.FrigateConfig)
    assert(#imports.collect(workspace, function() return false end, config) == 0,
        "Named source import left in Workspace; it may fall or overlap the map")
    local model = Instance.new("Model")
    model.Name, model.Parent = "FrigateSmokeBoat", workspace
    local connection
    local ok, err = pcall(function()
        local hull, seat = Visual.create(model, Vector3.new(-300, 1, -120), "Raft")
        assert(hull and seat, "Import ReferenceFrigate before running this test")
        local rig = Physics.attach(model, hull)
        Visual.bind(rig)
        assert(#rig.frigate.sails == 22, "Expected 11 sails with matching seam meshes")
        assert(#rig.frigate.rudders == 3, "Missing rudder assembly")
        assert(model:GetAttribute("CollisionRevision") == 3, "Sync the revision-3 collision code")
        assert(model:GetAttribute("AssetRevision") == 3, "Reimport the closed-stern revision-3 FBX")
        assert(model.QuarterdeckAccess.CanCollide and model.PoopDeckAccess.CanCollide)
        assert(model:GetAttribute("VisualScale") == 3 and hull.Size.Z >= 90, "Ship remains too small")
        assert(model:GetAttribute("InteriorAccessible"), "Reimport the revision-2 FBX before testing the interior")
        assert(model.GunDeckFloor0_1_0.CanCollide and model.CompanionwayAccess.CanCollide)
        local bow = model:FindFirstChild("Frigate_Bow_Stem", true)
        local stock = model:FindFirstChild("Frigate_Rudder_Stock", true)
        assert(bow.Position.Z < stock.Position.Z, "Imported ship is facing backward")
        local wheel = hull.WheelAnchor.WorldPosition
        assert(seat.Position.Z > wheel.Z and (seat.Position - wheel).Magnitude < 3, "Helm is not behind the wheel")
        assert(seat.CFrame.LookVector:Dot((Vector3.new(wheel.X, seat.Position.Y, wheel.Z) - seat.Position).Unit) > 0.99,
            "Helmsman faces away from the wheel")
        local pedestal = model:FindFirstChild("Frigate_Wheel_Pedestal", true)
        assert(pedestal.Position.Z < wheel.Z, "Wheel mount faces the helmsman instead of the bow")
        local floors = RaycastParams.new()
        floors.FilterType, floors.FilterDescendantsInstances = Enum.RaycastFilterType.Include, {model}
        for _, z in ipairs({14.95, 19, 21}) do
            local hit = workspace:Raycast(hull.CFrame * Vector3.new(0, 60, z * 3), Vector3.new(0, -80, 0), floors)
            assert(hit and hit.Instance:GetAttribute("ShipCollision"), "Missing walkable aft floor at " .. z)
        end
        local hatch = workspace:Raycast(hull.CFrame * Vector3.new(0, 15, 7.5), Vector3.new(0, -10, 0), floors)
        assert(hatch and hatch.Instance.Name:match("^GunDeckFloor"), "Hatch blocked by main-deck collision")
        for _, x in ipairs({-6, 6}) do
            local side = workspace:Raycast(hull.CFrame * Vector3.new(x, 20, 15), Vector3.new(0, -15, 0), floors)
            assert(side and side.Instance.Name:match("^DeckSegment"), "Missing walkway beside the hatch")
        end
        for _, z in ipairs({-14, -8, -4, 0, 10}) do
            local lower = workspace:Raycast(hull.CFrame * Vector3.new(3, 10, z * 3), Vector3.new(0, -6, 0), floors)
            assert(lower and lower.Instance.Name:match("^GunDeckFloor"), "Interior floor missing at " .. z)
        end
        local stairs = model.CompanionwayAccess
        local room = OverlapParams.new()
        room.FilterType, room.FilterDescendantsInstances = Enum.RaycastFilterType.Include, {model}
        room.RespectCanCollide = true
        for _, p in ipairs(workspace:GetPartBoundsInBox(hull.CFrame * CFrame.new(0, 9.35, 6), Vector3.new(2, 5.4, 2), room)) do
            assert(not p.Name:match("^DeckSegment") and p.Name ~= "Hull", "Entry landing blocked: " .. p.Name)
        end
        assert(stairs.Size.X >= 5.4 and hull:FindFirstChild("InteriorLantern6"), "Narrow or unlit companionway")
        assert(hull.RootPriority == 127 and hull.EnableFluidForces and seat:IsA("VehicleSeat"))
        local categories, follows = {}, 0
        for _, p in ipairs(model:GetDescendants()) do
            if p:IsA("BasePart") and p ~= hull then
                assert(not p.Anchored and p.Massless, "Anchored or heavy child: " .. p.Name)
                if p:IsDescendantOf(model.FrigateVisual) then assert(not p.CanCollide, "Detailed mesh collision enabled") end
                local category = p:GetAttribute("CollisionCategory")
                if category then
                    categories[category] = true
                    assert(p.CanCollide and p.CanQuery and not p.EnableFluidForces, "Invalid hitbox flags: " .. p.Name)
                end
                if p:GetAttribute("CollisionFollow") then
                    follows += 1
                    local target = model:FindFirstChild(p:GetAttribute("CollisionFollow"), true)
                    local welded = false
                    for _, joint in ipairs(hull:GetChildren()) do
                        if joint:IsA("WeldConstraint") and joint.Part1 == p then
                            welded = joint.Part0 == target
                        end
                    end
                    assert(welded, "Rudder hitbox attached to hull instead of moving rudder")
                end
            end
        end
        assert(follows == 2, "Missing moving rudder collision")
        for _, category in ipairs({"HullWall", "CabinWall", "Prop", "Mast", "Wheel", "Rail", "Transom"}) do
            assert(categories[category], "Missing category " .. category)
        end
        local startingZ = hull.Position.Z
        Physics.setActive(rig, true)
        local steer = 0
        connection = RunService.PreSimulation:Connect(function(dt)
            Physics.update(rig, math.min(dt, 0.1), 0, steer, 18)
            Visual.update(rig, rig.deployment, steer)
        end)
        rig.stage = 2
        task.wait(2)
        assert(math.abs(rig.deployment - 0.5) < 0.01, "Half sails never deployed")
        rig.stage = 3
        task.wait(2)
        assert(math.abs(rig.deployment - 1) < 0.01, "Full sails never deployed")
        for _, entry in ipairs(rig.frigate.sails) do
            assert((entry.part.Size - entry.size).Magnitude < 0.01, "Full mesh shape was not restored")
        end
        assert(hull.Position.Z < startingZ - 2, "Sails did not propel the boat")
        steer = 0.5
        task.wait(0.5)
        assert(rig.yaw < 0, "Steering did not change heading")
        for _, entry in ipairs(rig.frigate.rudders) do
            assert((entry.joint.C0.Position - rig.frigate.rudderHinge.Position).Magnitude < 0.001,
                "Rudder hinge slides sideways while turning")
            assert(entry.joint.C0.LookVector:Dot(entry.c0.LookVector) < 0.999, "Rudder joint did not rotate")
        end
        local stockCenter = hull.CFrame:PointToObjectSpace(stock.Position)
        assert((stockCenter - rig.frigate.rudderHinge.Position).Magnitude < 0.05, "Rudder stock drifts away from its hinge")
        rig.stage, steer = 0, 0
        task.wait(2)
        assert(rig.deployment < 0.01, "Sails never stowed")
        assert(hull.Position.Y > -2 and hull.Position.Y < hull.Size.Y / 2, "Frigate does not float at the water surface")
        assert(hull.CFrame.UpVector.Y > 0.9, "Frigate capsized")
        Physics.setActive(rig, false)
        Physics.reset(rig)
        Visual.update(rig, 0, 0)
        assert(hull.Anchored and hull.AssemblyLinearVelocity.Magnitude < 0.01, "Docking left residual movement")
        assert(rig.frigate.deployment == 0 and rig.frigate.steer == 0)
    end)
    if connection then connection:Disconnect() end
    model:Destroy()
    assert(ok, err)
    print("PirateOcean frigate assembly, sails, rudder and buoyancy smoke test passed")
end
