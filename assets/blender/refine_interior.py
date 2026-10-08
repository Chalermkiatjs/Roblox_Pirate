"""Close plank gaps and add the accessible gun deck, preserving other ship parts."""

import bpy
import bmesh
import runpy
from pathlib import Path

OUTPUT = Path(__file__).resolve().parent
helpers = runpy.run_path(str(OUTPUT / "build_reference_frigate.py"), run_name="frigate_helpers")
scene = bpy.data.scenes["Reference Frigate"]
root = bpy.data.objects["Reference_Frigate"]
bpy.context.window.scene = scene
backup = OUTPUT / "reference_frigate_before_interior.blend"
if not backup.exists():
    bpy.ops.wm.save_as_mainfile(filepath=str(backup), copy=True)

groups = {name: bpy.data.collections["Frigate_" + name] for name in ["Hull", "Deck", "Studio"]}
names = {
    "wood": ["Oak_1", "Oak_2", "Oak_3", "Oak_4"],
    "deck": ["Deck_1", "Deck_2", "Deck_3"],
    "bilge": "Weathered_Underwater_Oak", "dark": "Tarred_Timber",
    "paint": "Aged_Green_Paint", "gold": "Aged_Brass", "metal": "Dark_Iron",
    "glass": "Stern_Window_Glass", "void": "Gunport_Interior",
    "mast": "Spar_Pine", "canvas": "Weathered_Linen",
}
mats = {key: [bpy.data.materials["Frigate_" + n] for n in value] if isinstance(value, list)
        else bpy.data.materials["Frigate_" + value] for key, value in names.items()}
mats["lamp"] = bpy.data.materials.get("Frigate_Lantern_Glass") or helpers["material"]("Lantern_Glass",(0.9,0.5,0.12),0.32)
affected = ["Hull_Planking", "Main_Deck_Planks", "Deck_Fittings", "Wheel_Pedestal", "Ship_Wheel",
            "Gun_Deck_Floor", "Interior_Frames_And_Beams", "Interior_Bulkheads",
            "Open_Hatch_Coaming", "Companionway_Stairs", "Interior_Cargo_And_Berths", "Interior_Lanterns",
            "Bulwarks_And_Railings", "Deck_Access_Stairs"]
for name in affected:
    obj = bpy.data.objects.get("Frigate_" + name)
    if obj:
        assert obj.parent == root, f"Unexpected owner for {obj.name}"
        bpy.data.objects.remove(obj, do_unlink=True)
helpers["hull_planking"](groups,root,mats)
helpers["main_deck"](groups,root,mats)
# deck_fittings also builds the anchors, which are unchanged.
anchors = bpy.data.objects["Frigate_Anchors_And_Bow_Headrails"]
anchors.name = "Preserved_Anchors"
helpers["deck_fittings"](groups,root,mats)
bpy.data.objects.remove(bpy.data.objects["Frigate_Anchors_And_Bow_Headrails"], do_unlink=True)
anchors.name = "Frigate_Anchors_And_Bow_Headrails"
helpers["ship_wheel"](groups,root,mats)
helpers["below_deck"](groups,root,mats)
helpers["railings"](groups,root,mats)

# Close only the narrow roof seam offsets, without rebuilding the gallery.
roof = bpy.data.objects["Frigate_Stepped_Cambered_Quarterdecks"]
if not root.get("interior_revision"):
    for v in roof.data.vertices:
        p = v.co
        # Roof strip endpoints originally used r +/- 0.0015. Recover r analytically.
        if p.z < 10:
            u = (p.x-13.15)/(20.9-13.15)
            half = (4.2+(4.0-4.2)*u)*0.935+0.14
            base = 8.7+0.22*u+0.07
        else:
            u = (p.x-16)/(21.55-16)
            half = (3.74+(3.58-3.74)*u)*0.935+0.14
            base = 10.26+0.2*u+0.07
        r = p.y/half
        exact = round((r+1)*9)/9-1
        p.y = half*exact
        p.z = base+0.16*(1-exact*exact)
    roof.data.update()

for name in affected:
    obj = bpy.data.objects.get("Frigate_" + name)
    mesh = bmesh.new()
    mesh.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(mesh, faces=list(mesh.faces))
    mesh.to_mesh(obj.data)
    mesh.free()
    obj.data.update()
root["interior_revision"] = 2
root["interior_notes"] = "Sealed plank joins; aft-facing wheel grips; open companionway and walkable gun deck"
root["mesh_objects"] = sum(o.type == "MESH" for o in root.children)
helpers["interior_staging"](groups)
bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT / "reference_frigate.blend"))
print("INTERIOR REVISION 2 saved;",root["mesh_objects"],"ship meshes")
