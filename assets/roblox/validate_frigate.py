"""Round-trip the FBX in a fresh Blender process before Studio import."""

import json
import math
from pathlib import Path

import bpy
import bmesh
from bpy_extras.io_utils import axis_conversion
from mathutils import Vector
from mathutils.bvhtree import BVHTree


OUTPUT = Path(__file__).resolve().parent
manifest = json.loads((OUTPUT / "reference_frigate_roblox_manifest.json").read_text(encoding="utf-8"))
bpy.ops.import_scene.fbx(filepath=str(OUTPUT / "reference_frigate_roblox.fbx"))
meshes = [o for o in bpy.context.selected_objects if o.type == "MESH"]
assert len(meshes) == manifest["mesh_objects"]
expected = {item["name"]: item["triangles"] for item in manifest["components"]}
conversion = axis_conversion(to_forward="-Z", to_up="Y").to_4x4()
points, unique_colors = [], set()
for obj in meshes:
    obj.data.calc_loop_triangles()
    assert len(obj.data.loop_triangles) == expected[obj.name], obj.name
    assert len(obj.data.loop_triangles) <= 18000, obj.name
    assert len(obj.data.color_attributes) > 0, obj.name
    attribute = obj.data.color_attributes[0]
    assert len(attribute.data) == len(obj.data.loops), obj.name
    for item in attribute.data:
        unique_colors.add(tuple(round(c, 4) for c in item.color))
    for vertex in obj.data.vertices:
        point = conversion @ obj.matrix_world @ vertex.co
        assert all(math.isfinite(c) for c in point), obj.name
        points.append(point)
minimum = [min(point[i] for point in points) for i in range(3)]
maximum = [max(point[i] for point in points) for i in range(3)]
dimensions = [maximum[i] - minimum[i] for i in range(3)]
assert all(abs(a - b) < 0.01 for a, b in zip(dimensions, manifest["dimensions_studs"]))
assert len(unique_colors) >= 10, "Missing surface colors"
names = set(expected)
for required in ["Frigate_Bow_Stem", "Frigate_Sternpost_And_Deadwood", "Frigate_Rudder_Blade", "Frigate_Stern_Gallery",
                 "Frigate_Main_Deck_Planks", "Frigate_Gun_Deck_Floor", "Frigate_Companionway_Stairs",
                 "Frigate_Ship_Wheel", "Frigate_Wheel_Pedestal", "Frigate_Open_Hatch_Coaming"]:
    assert required in names, required
assert "Frigate_Quarterdeck_Stairs" not in names
for name in ["Frigate_Stern_Transom_Planking", "Frigate_Stepped_Cambered_Quarterdecks"]:
    obj = next(o for o in meshes if o.name == name)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    assert all(e.is_manifold for e in bm.edges), "Open FBX shell: " + name
    assert bm.calc_volume(signed=True) > 0, "Inside-out FBX shell: " + name
    bm.free()
def canonical_tree(name):
    obj=next(o for o in meshes if o.name==name)
    verts=[conversion @ obj.matrix_world @ v.co for v in obj.data.vertices]
    return BVHTree.FromPolygons(verts,[tuple(p.vertices) for p in obj.data.polygons])
deck=canonical_tree("Frigate_Main_Deck_Planks")
gun=canonical_tree("Frigate_Gun_Deck_Floor")
transom = canonical_tree("Frigate_Stern_Transom_Planking")
for y in [2.7+i*.05 for i in range(90)]:
    hit, normal, _, _ = transom.ray_cast(Vector((0,y,23)),Vector((0,0,-1)),5)
    assert hit is not None and normal.z > .99, "Missing/back-facing transom band at " + str(y)
for z in [2.5,3,5,7,8.5]:
    for x in [-1.3,0,1.3]:
        assert deck.ray_cast(Vector((x,8,z)),Vector((0,-1,0)),10)[0] is None,"FBX hatch filled in"
        hit=gun.ray_cast(Vector((x,8,z)),Vector((0,-1,0)),10)[0]
        assert hit is not None and hit.y>4.1,"FBX interior floor missing"
report = {
    "fbx_round_trip": "passed",
    "mesh_objects": len(meshes),
    "triangles": sum(expected.values()),
    "maximum_triangles_per_mesh": max(expected.values()),
    "distinct_vertex_colors": len(unique_colors),
    "dimensions_studs": dimensions,
    "revised_bow_stern_rudder_present": True,
    "removed_stairs_absent": True,
    "accessible_interior_present": True,
    "interior_revision": manifest["interior_revision"],
    "round_trip_hatch_open": True,
    "round_trip_interior_floor": True,
    "closed_transom_and_roofs": True,
    "outward_transom_samples": 90,
    "studio_import": "Not tested; Windows control runtime failed to start",
}
(OUTPUT / "validation_report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print("VALIDATED", json.dumps(report), flush=True)
