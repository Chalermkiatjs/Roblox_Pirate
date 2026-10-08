local Imports = require("../src/shared/FrigateImports")
local config = {TemplateName = "ReferenceFrigate", ImportName = "reference_frigate_roblox"}
local function item(name, class, parent, attributes)
    local obj = {Name = name, Class = class, Parent = parent, attributes = attributes or {}, children = {}}
    if parent then table.insert(parent.children, obj) end
    function obj:IsA(wanted) return self.Class == wanted end
    function obj:GetAttribute(key) return self.attributes[key] end
    function obj:GetDescendants()
        local result = {}
        local function append(node)
            for _, child in ipairs(node.children) do table.insert(result, child) append(child) end
        end
        append(self)
        return result
    end
    function obj:FindFirstChildWhichIsA(wanted)
        for _, child in ipairs(self:GetDescendants()) do if child:IsA(wanted) then return child end end
    end
    return obj
end
local root = item("Workspace", "Workspace")
local old = item("OldShipImport", "Model", root, {valid = true})
local fresh = item("ReferenceFrigate", "Model", root, {valid = true})
item("Deck", "MeshPart", fresh)
local merged = item("ReferenceFrigate.001", "MeshPart", root)
local partial = item("reference_frigate_roblox (2)", "Model", root)
item("RemainingMesh", "MeshPart", partial)
local runtime = item("PlayerBoat", "Model", root, {ShipVisual = "ReferenceFrigate"})
item("ReferenceFrigate", "Model", runtime, {valid = true})
local clone = item("FrigateVisual", "Model", root, {valid = true})
item("ReferenceFrigate", "MeshPart", clone)
item("ReferenceFrigate", "Model", root) -- Empty unrelated placeholder is left alone.
item("OtherArt", "MeshPart", root)
local collected = Imports.collect(root, function(obj) return obj:GetAttribute("valid") == true end, config)
assert(#collected == 4, "Missing import or runtime boat incorrectly collected")
assert(collected[1] == old and collected[2] == fresh and collected[3] == merged and collected[4] == partial)
print("PASS: all duplicate, merged and incomplete frigate imports collected; runtime boats and unrelated art excluded")
