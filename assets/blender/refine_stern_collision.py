"""Repair inward-facing transom bands without replacing unrelated ship work."""
import bpy
import bmesh
import runpy
from pathlib import Path

output = Path(__file__).resolve().parent
helpers = runpy.run_path(str(output / "build_reference_frigate.py"), run_name="helpers")
root = bpy.data.objects["Reference_Frigate"]
bpy.context.window.scene = bpy.data.scenes["Reference Frigate"]
backup = output / "reference_frigate_before_collision.blend"
if not backup.exists():
    bpy.ops.wm.save_as_mainfile(filepath=str(backup), copy=True)
groups = {n:bpy.data.collections["Frigate_"+n] for n in ["Hull","Deck"]}
mats = {"wood":[bpy.data.materials[f"Frigate_Oak_{i}"] for i in range(1,5)],
        "deck":[bpy.data.materials[f"Frigate_Deck_{i}"] for i in range(1,4)],
        "dark":bpy.data.materials["Frigate_Tarred_Timber"]}
names = ["Keel_Stem_Transom","Stern_Transom_Planking","Stepped_Cambered_Quarterdecks"]
for name in names:
    obj = bpy.data.objects.get("Frigate_"+name)
    if obj:
        assert obj.parent == root
        bpy.data.objects.remove(obj, do_unlink=True)
helpers["hull_structure"](groups,root,mats)
helpers["stern_transom"](groups,root,mats)
helpers["quarterdeck_roofs"](groups,root,mats)
for name in names:
    obj = bpy.data.objects["Frigate_"+name]
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges), name
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
root["collision_revision"] = 3
root["mesh_objects"] = sum(o.type == "MESH" for o in root.children)
bpy.ops.wm.save_as_mainfile(filepath=str(output / "reference_frigate.blend"))
print("STERN COLLISION REVISION 3: closed outward-facing transom and solid roofs saved")
