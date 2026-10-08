local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("PirateOcean")
local Config = require(shared.CharacterCameraConfig)
local Motion = require(shared.Util.ShipCameraMotion)
local MouseLook = require(script.Parent.MouseLook)
local player = Players.LocalPlayer
local active
local yaw, pitch, distance = 0, Config.DefaultPitch, Config.Distance
local touch, stick = nil, Vector2.zero
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater, params.RespectCanCollide = true, true

local function release()
    MouseLook.release("Character")
    touch, stick = nil, Vector2.zero
    if active then
        if active.humanoid.Parent then active.humanoid.AutoRotate = active.autoRotate end
        if active.camera.Parent then
            active.camera.CameraType, active.camera.FieldOfView = active.cameraType, active.fov
            active.camera.CameraSubject = active.humanoid.Parent and active.humanoid or active.subject
        end
    end
    active = nil
end

local function look(dx, dy, sensitivity)
    yaw -= dx * sensitivity
    yaw = math.atan2(math.sin(yaw), math.cos(yaw))
    pitch = math.clamp(pitch + dy * sensitivity, Config.MinPitch, Config.MaxPitch)
end

Input.InputBegan:Connect(function(input, processed)
    if processed or not active or MouseLook.cursorFree() then return end
    if input.UserInputType == Enum.UserInputType.Touch and not touch
        and input.Position.X > active.camera.ViewportSize.X * 0.5 then touch = input end
end)
Input.InputChanged:Connect(function(input, processed)
    if not active or MouseLook.cursorFree() then return end
    if input == touch then look(input.Delta.X, input.Delta.Y, Config.TouchSensitivity)
    elseif input.UserInputType == Enum.UserInputType.MouseWheel and not processed then
        distance = math.clamp(distance - input.Position.Z, Config.MinDistance, Config.MaxDistance)
    elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then stick = Vector2.new(input.Position.X, input.Position.Y) end
end)
Input.InputEnded:Connect(function(input)
    if input == touch then touch = nil end
    if input.KeyCode == Enum.KeyCode.Thumbstick2 then stick = Vector2.zero end
end)
Input.WindowFocusReleased:Connect(function() touch, stick = nil, Vector2.zero end)
player.CharacterRemoving:Connect(release)

-- Hand off before the ship camera runs; both controllers share cursor ownership.
RunService:BindToRenderStep("PirateOceanCharacterCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
    local character, camera = player.Character, workspace.CurrentCamera
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not camera or not humanoid or not root or humanoid.Health <= 0 or humanoid.SeatPart then
        if active then release() end
        return
    end
    if not active and camera.CameraType == Enum.CameraType.Scriptable then return end
    if not active or active.character ~= character or active.camera ~= camera then
        release()
        local forward = camera.CFrame.LookVector
        yaw = math.atan2(-forward.X, -forward.Z)
        pitch, distance = Config.DefaultPitch, Config.Distance
        active = {character = character, humanoid = humanoid, camera = camera,
            cameraType = camera.CameraType, subject = camera.CameraSubject, fov = camera.FieldOfView,
            autoRotate = humanoid.AutoRotate, focus = root.Position + Vector3.yAxis * Config.FocusHeight}
        params.FilterDescendantsInstances = {character}
    end
    dt = math.min(dt, 0.1)
    camera.CameraType = Enum.CameraType.Scriptable
    local captured = MouseLook.update("Character")
    if captured then
        local delta = Input:GetMouseDelta()
        look(delta.X, delta.Y, Config.MouseSensitivity)
    end
    if not MouseLook.cursorFree() and stick.Magnitude > 0.15 then
        look(stick.X * dt, -stick.Y * dt, Config.GamepadSensitivity)
    end
    local state = humanoid:GetState()
    local faceCamera = (captured or not MouseLook.cursorFree() and (touch ~= nil or stick.Magnitude > 0.15))
        and state ~= Enum.HumanoidStateType.Swimming and state ~= Enum.HumanoidStateType.Climbing
    if faceCamera then humanoid.AutoRotate = false else humanoid.AutoRotate = active.autoRotate end
    if faceCamera then root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0) end
    local focus = root.Position + Vector3.yAxis * Config.FocusHeight
    if (active.focus - focus).Magnitude > 30 then active.focus = focus
    else active.focus = active.focus:Lerp(focus, Motion.alpha(Config.FollowResponse, dt)) end
    local orbit = CFrame.Angles(0, yaw, 0)
    local viewport = camera.ViewportSize
    local framing = viewport.Y > viewport.X and 1.2 or 1
    local position = active.focus + orbit.ZVector * math.cos(pitch) * distance * framing
        + Vector3.yAxis * math.sin(pitch) * distance * framing + orbit.RightVector * Config.ShoulderOffset
    local offset = position - active.focus
    local hit = workspace:Raycast(active.focus, offset, params)
    if hit then position = active.focus + offset.Unit * math.max(0.1, hit.Distance - Config.CollisionPadding) end
    camera.CFrame, camera.Focus = CFrame.lookAt(position, active.focus), CFrame.new(active.focus)
    camera.FieldOfView = Config.FieldOfView
end)

script.Destroying:Connect(function()
    release()
    RunService:UnbindFromRenderStep("PirateOceanCharacterCamera")
end)
