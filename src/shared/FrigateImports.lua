local Imports = {}

local function managed(item, root)
    local owner = item
    while owner and owner ~= root do
        if owner.Name == "FrigateVisual" or owner:GetAttribute("ShipVisual")
            or owner:GetAttribute("SailingRigReady") then return true end
        owner = owner.Parent
    end
    return false
end

local function importName(name, config)
    for _, base in ipairs({config.TemplateName, config.ImportName}) do
        if name == base then return true end
        local suffix = name:sub(#base + 1)
        if name:sub(1, #base) == base and (suffix:match("^_%d+$")
            or suffix:match("^%.%d+$") or suffix:match("^ %(%d+%)$")) then return true end
    end
    return false
end

function Imports.collect(root, validTemplate, config)
    local items = {}
    for _, item in ipairs(root:GetDescendants()) do
        if not managed(item, root) and (item:IsA("Model") or item:IsA("MeshPart")) then
            -- Named merged/incomplete imports must also leave the world, even if unusable.
            if validTemplate(item) or (importName(item.Name, config)
                and (item:IsA("MeshPart") or item:FindFirstChildWhichIsA("MeshPart", true))) then
                table.insert(items, item)
            end
        end
    end
    return items
end

return Imports
