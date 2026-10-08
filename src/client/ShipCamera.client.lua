local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local MouseLook = require(script.Parent.MouseLook)
local shared = game:GetService("ReplicatedStorage"):WaitForChild("PirateOcean")
local Config = require(shared.ShipCameraConfig)
local Motion = require(shared.Util.ShipCameraMotion)
local player = Players.LocalPlayer
local active, saved
local orbitYaw, pitch, zoom = 0, Config.DefaultPitch, 1
local mouseCaptured, touch, stick = false, nil, Vector2.zero
local lastLook = 0
local params = RaycastParams.new()
params.ExcludeInstances = {}
params.IgnoreWater, params.RespectCanCollide = true, true

local function stopMouseLook()
    MouseLook.release("Ship")
    mouseCaptured = false
end

local function release()
    stopMouseLook()
    touch, stick = nil, Vector2.zero
    if saved and saved.camera.Parent then
        saved.camera.CameraType = saved.cameraType
        local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        saved.camera.CameraSubject = humanoid or saved.subject
        saved.camera.FieldOfView = saved.fov
    end
    active, saved = nil, nil
end

local function shipAtHelm()
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end
    local seat = humanoid.SeatPart
    if not seat or not seat:IsA("VehicleSeat") or seat.Name ~= "Helm" then return end
    local model = seat.Parent
    if not model or not model:IsA("Model") or not model:GetAttribute("SailingRigReady")
        or not model:GetAttribute("InVoyage") then return end
    local hull = model:FindFirstChild("Hull")
    if hull and hull:IsA("BasePart") then return model, hull, seat end
end

local function look(dx, dy, sensitivity)
    orbitYaw -= dx * sensitivity
    orbitYaw = math.atan2(math.sin(orbitYaw), math.cos(orbitYaw))
    pitch = math.clamp(pitch + dy * sensitivity, Config.MinPitch, Config.MaxPitch)
    lastLook = os.clock()
end

Input.InputBegan:Connect(function(input, processed)
    if processed or not active or MouseLook.cursorFree() then return end
    if input.UserInputType == Enum.UserInputType.Touch and not touch
        and input.Position.X > saved.camera.ViewportSize.X * 0.5 then
        touch = input
        lastLook = os.clock()
    end
end)

Input.InputChanged:Connect(function(input, processed)
    if not active or MouseLook.cursorFree() then return end
    if input == touch then
        look(input.Delta.X, input.Delta.Y, Config.TouchSensitivity)
    elseif input.UserInputType == Enum.UserInputType.MouseWheel and not processed then
        zoom = math.clamp(zoom - input.Position.Z * 0.1, Config.MinZoom, Config.MaxZoom)
    elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
        stick = Vector2.new(input.Position.X, input.Position.Y)
    end
end)

Input.InputEnded:Connect(function(input)
    if input == touch then touch = nil end
    if input.KeyCode == Enum.KeyCode.Thumbstick2 then stick = Vector2.zero end
end)
Input.WindowFocusReleased:Connect(function()
    stopMouseLook()
    touch, stick = nil, Vector2.zero
end)
player.CharacterRemoving:Connect(release)

RunService:BindToRenderStep("PirateOceanShipCamera", Enum.RenderPriority.Camera.Value + 2, function(dt)
    local camera = workspace.CurrentCamera
    local model, hull, seat = shipAtHelm()
    if not camera or not model then
        if active then release() end
        return
    end
    if not active or active.model ~= model or saved.camera ~= camera then
        release()
        saved = {camera = camera, cameraType = camera.CameraType, subject = camera.CameraSubject,
            fov = camera.FieldOfView}
        local _, bounds = model:GetBoundingBox()
        local lookVector = hull.CFrame.LookVector
        active = {model = model, hull = hull, length = bounds.Z, width = bounds.X, height = bounds.Y,
            heading = math.atan2(-lookVector.X, -lookVector.Z), position = camera.CFrame.Position,
            focus = camera.Focus.Position, helmHeight = hull.CFrame:PointToObjectSpace(seat.Position).Y}
        orbitYaw, pitch, zoom = 0, Config.DefaultPitch, 1
        lastLook = os.clock()
        params.ExcludeInstances = {model, player.Character}
    end
    dt = math.min(dt, 0.1)
    camera.CameraType = Enum.CameraType.Scriptable
    mouseCaptured = MouseLook.update("Ship")
    if mouseCaptured then
        local delta = Input:GetMouseDelta()
        if delta.Magnitude > 0 then look(delta.X, delta.Y, Config.MouseSensitivity) end
    end
    if stick.Magnitude > 0.15 and not MouseLook.cursorFree() then
        look(stick.X * dt, -stick.Y * dt, Config.GamepadSensitivity)
    end
    if not MouseLook.cursorFree() and not mouseCaptured and not touch and os.clock() - lastLook > Config.RecenterDelay then
        orbitYaw = Motion.followAngle(orbitYaw, 0, Config.RecenterResponse, dt)
        pitch += (Config.DefaultPitch - pitch) * Motion.alpha(Config.RecenterResponse, dt)
    end
    local forward = hull.CFrame.LookVector
    local yaw = math.atan2(-forward.X, -forward.Z)
    active.heading = Motion.followAngle(active.heading, yaw, Config.HeadingResponse, dt)
    local heading = CFrame.Angles(0, active.heading, 0)
    local orbit = CFrame.Angles(0, active.heading + orbitYaw, 0)
    local speed = Vector3.new(hull.AssemblyLinearVelocity.X, 0, hull.AssemblyLinearVelocity.Z).Magnitude
    local speedFactor = math.clamp(speed / 32, 0, 1)
    local viewport = camera.ViewportSize
    local distance = Motion.distance(active.length, active.width, active.height,
        viewport.X / math.max(1, viewport.Y), Config.FieldOfView) * zoom * (1 + speedFactor * 0.05)
    local focus = hull.Position + Vector3.yAxis * math.max(active.helmHeight, active.height * 0.22)
        + heading.LookVector * active.length * 0.1
    local position = focus + orbit.ZVector * (math.cos(pitch) * distance)
        + Vector3.yAxis * (math.sin(pitch) * distance) + orbit.RightVector * active.width * 0.1
    local alpha = Motion.alpha(Config.FollowResponse, dt)
    -- Teleports during docking/recovery must not leave the camera crossing the map.
    if (active.focus - focus).Magnitude > math.max(100, active.length * 2) then
        active.position, active.focus = position, focus
    else
        active.focus = active.focus:Lerp(focus, alpha)
        active.position = active.focus + (position - focus)
    end
    local offset = active.position - active.focus
    local visiblePosition = active.position
    if offset.Magnitude > 0.01 then
        local hit = workspace:Raycast(active.focus, offset, params)
        if hit then
            visiblePosition = active.focus + offset.Unit * math.max(0.1, hit.Distance - Config.CollisionPadding)
        end
    end
    camera.CFrame = CFrame.lookAt(visiblePosition, active.focus, Vector3.yAxis)
    camera.Focus = CFrame.new(active.focus)
    camera.FieldOfView += (Config.FieldOfView + Config.SpeedFieldOfView * speedFactor
        - camera.FieldOfView) * alpha
end)

script.Destroying:Connect(function()
    release()
    RunService:UnbindFromRenderStep("PirateOceanShipCamera")
end)
