local Collision = require("../src/shared/FrigateCollision")
assert(Collision.Revision == 3 and #Collision.Parts > 500 and #Collision.Parts < 800)
local names, categories, cannonNames, follows = {}, {}, {}, {}
local function dot(a, b)
    return a[1]*b[1] + a[2]*b[2] + a[3]*b[3]
end
for _, p in ipairs(Collision.Parts) do
    assert(not names[p.name], "Duplicate hitbox: " .. p.name)
    names[p.name] = true
    categories[p.category] = (categories[p.category] or 0) + 1
    assert(p.kind == "Block" or p.kind == "Wedge" or p.kind == "Cylinder")
    for i = 1, 3 do
        assert(p.size[i] > 0 and p.size[i] < 50)
        assert(p.position[i] == p.position[i] and math.abs(p.position[i]) < 100)
        assert(math.abs(dot(p.axes[i], p.axes[i]) - 1) < 0.00001)
        for j = i + 1, 3 do assert(math.abs(dot(p.axes[i], p.axes[j])) < 0.00001) end
    end
    if p.requires and p.requires:match("^Frigate_Cannon_") then cannonNames[p.requires] = true end
    if p.follow then
        assert(p.follow == p.requires, "Moving hitbox welded to wrong art")
        follows[p.follow] = true
    end
end
local count = 0
for _ in pairs(cannonNames) do count += 1 end
assert(count == 20, "Missing cannon hitboxes")
assert(follows.Frigate_Rudder_Stock and follows.Frigate_Rudder_Blade)
for _, category in ipairs({"MainFloor", "GunFloor", "GalleryFloor", "HullWall", "Transom",
    "CabinWall", "Rail", "HatchGuard", "Prop", "Stairs", "Mast", "Wheel", "Lantern", "Bulkhead"}) do
    assert(categories[category] and categories[category] > 0, "Missing collision category: " .. category)
end
assert(categories.Mast == 3 and categories.Lantern == 6 and categories.Bulkhead == 2)
print("PASS: generated frigate hitbox bases, sizes, all 20 cannons and moving rudder targets")
