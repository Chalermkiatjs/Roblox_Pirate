"""Revise only the frigate's bow, stern gear and aft gallery in the live file."""

import bpy
import bmesh
import runpy
from pathlib import Path
from mathutils import Vector


OUTPUT = Path(__file__).resolve().parent
helpers = runpy.run_path(str(OUTPUT / "build_reference_frigate.py"), run_name="frigate_helpers")
scene = bpy.data.scenes["Reference Frigate"]
root = bpy.data.objects["Reference_Frigate"]
bpy.context.window.scene = scene

backup = OUTPUT / "reference_frigate_before_hull_detail.blend"
if not backup.exists():
    bpy.ops.wm.save_as_mainfile(filepath=str(backup), copy=True)
groups = {name: bpy.data.collections["Frigate_" + name] for name in ["Hull", "Deck", "Studio"]}
names = {
    "wood": ["Oak_1", "Oak_2", "Oak_3", "Oak_4"],
    "deck": ["Deck_1", "Deck_2", "Deck_3"],
    "bilge": "Weathered_Underwater_Oak", "dark": "Tarred_Timber",
    "paint": "Aged_Green_Paint", "gold": "Aged_Brass", "metal": "Dark_Iron",
    "glass": "Stern_Window_Glass",
}
mats = {key: [bpy.data.materials["Frigate_" + n] for n in value] if isinstance(value, list)
        else bpy.data.materials["Frigate_" + value] for key, value in names.items()}

affected = ["Keel_Stem_Transom", "Rudder_Hinges", "Quarterdeck_Stairs", "Stern_Gallery",
            "Bulwarks_And_Railings", "Bow_Stem", "Sternpost_And_Deadwood", "Rudder_Stock",
            "Rudder_Blade", "Rudder_Gudgeons_And_Straps", "Stern_Gallery_Windows_And_Mouldings",
            "Stepped_Cambered_Quarterdecks"]
for name in affected:
    obj = bpy.data.objects.get("Frigate_" + name)
    if obj:
        assert obj.parent == root, f"Unexpected owner for {obj.name}"
        bpy.data.objects.remove(obj, do_unlink=True)

helpers["hull_structure"](groups, root, mats)
helpers["bow_and_rudder"](groups, root, mats)
helpers["cabins_and_rails"](groups, root, mats)

for name in affected:
    obj = bpy.data.objects.get("Frigate_" + name)
    if not obj:
        continue
    mesh = bmesh.new()
    mesh.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(mesh, faces=list(mesh.faces))
    mesh.to_mesh(obj.data)
    mesh.free()
    obj.data.update()

for name, position, target, scale in [
    ("Bow_Detail", (-35, -32, 16), (-19.5, 0, 4.4), 16),
    ("Stern_Detail", (36, -32, 20), (19.2, 0, 6.2), 18),
]:
    obj = bpy.data.objects.get("Frigate_" + name)
    if obj is None:
        data = bpy.data.cameras.new("Frigate_" + name)
        obj = bpy.data.objects.new("Frigate_" + name, data)
        groups["Studio"].objects.link(obj)
    obj.data.type = helpers["enum_id"](obj.data, "type", "ORTHO")
    obj.data.ortho_scale = scale
    obj.location = position
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()

assert bpy.data.objects.get("Frigate_Quarterdeck_Stairs") is None
assert bpy.data.objects.get("Frigate_Rudder_Hinges") is None
blade = bpy.data.objects["Frigate_Rudder_Blade"]
assert blade.dimensions.x > blade.dimensions.y * 3, "Rudder blade must lie along the hull"
meshes = [obj for obj in scene.objects if obj.type == "MESH" and obj.parent == root]
root["mesh_objects"] = len(meshes)
root["base_faces"] = sum(len(obj.data.polygons) for obj in meshes)
root["hull_detail_revision"] = "Proud curved bow stem; sternpost and longitudinal rudder; raked two-tier gallery; no aft stairs"
bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT / "reference_frigate.blend"))
print("REVISED bow, sternpost, rudder and two-tier gallery;", len(meshes), "mesh objects")
