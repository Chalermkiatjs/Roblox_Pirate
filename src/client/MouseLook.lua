local Input = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local player = game:GetService("Players").LocalPlayer
local MouseLook = {}
local owner, previousBehavior, previousIcon
local focused = true

function MouseLook.cursorFree()
    local playerGui = player:FindFirstChild("PlayerGui")
    local hud = playerGui and playerGui:FindFirstChild("PirateOceanHud")
    local ledger = hud and hud:FindFirstChild("CollectionOverlay")
    return not focused or GuiService.MenuIsOpen or Input:GetFocusedTextBox()
        or Input:IsKeyDown(Enum.KeyCode.LeftAlt) or Input:IsKeyDown(Enum.KeyCode.RightAlt)
        or (ledger and ledger.Visible)
end

function MouseLook.release(requester)
    if owner ~= requester or not owner then return end
    Input.MouseBehavior, Input.MouseIconEnabled = previousBehavior, previousIcon
    owner, previousBehavior, previousIcon = nil, nil, nil
end

function MouseLook.update(requester)
    if not Input.MouseEnabled or MouseLook.cursorFree() then
        MouseLook.release(requester)
        if not owner then
            Input.MouseBehavior = Enum.MouseBehavior.Default
            Input.MouseIconEnabled = true
        end
        return false
    end
    if owner ~= requester then
        if owner then MouseLook.release(owner) end
        owner, previousBehavior, previousIcon = requester, Input.MouseBehavior, Input.MouseIconEnabled
    end
    Input.MouseBehavior = Enum.MouseBehavior.LockCenter
    Input.MouseIconEnabled = false
    return true
end

Input.WindowFocusReleased:Connect(function()
    focused = false
    if owner then MouseLook.release(owner) end
end)
Input.WindowFocused:Connect(function() focused = true end)

return MouseLook
