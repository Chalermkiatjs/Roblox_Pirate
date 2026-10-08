"""Export the modeled ship and render two previews from its saved .blend."""

import bpy
import json
import math
from pathlib import Path


OUTPUT = Path(__file__).resolve().parent
scene = bpy.data.scenes["Reference Frigate"]
bpy.context.window.scene = scene
root = bpy.data.objects["Reference_Frigate"]
meshes = [o for o in scene.objects if o.type == "MESH" and o.parent == root]

for obj in scene.objects:
    obj.select_set(obj == root or obj in meshes)
bpy.context.view_layer.objects.active = root

assert len(meshes) >= 60, "Missing ship components"
assert all(len(obj.data.polygons) for obj in meshes), "Empty mesh"
assert all(math.isfinite(c) for obj in meshes for v in obj.data.vertices for c in v.co), "Invalid vertex"

depsgraph = bpy.context.evaluated_depsgraph_get()
stats = []
for obj in meshes:
    evaluated = obj.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    mesh.calc_loop_triangles()
    stats.append({"name": obj.name, "vertices": len(mesh.vertices), "triangles": len(mesh.loop_triangles)})
    evaluated.to_mesh_clear()

# Procedural noise is retained in the master; exports get explicit base colors.
originals, export_materials = {}, {}
for obj in meshes:
    originals[obj.name] = list(obj.data.materials)
    for index, mat in enumerate(list(obj.data.materials)):
        if mat.name not in export_materials:
            exported = mat.copy()
            exported.name = mat.name + "_Export"
            shader = next(n for n in exported.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
            for input_socket in shader.inputs:
                if input_socket.identifier in {"Base Color", "Normal"}:
                    for link in list(input_socket.links):
                        exported.node_tree.links.remove(link)
            export_materials[mat.name] = exported
        obj.data.materials[index] = export_materials[mat.name]

def export_enum(operator, parameter, desired):
    items = [i.identifier for i in operator.get_rna_type().properties[parameter].enum_items]
    if not items and parameter == "export_format":
        from io_scene_gltf2 import get_format_items
        items = [item[0] for item in get_format_items(scene, bpy.context)]
    if desired not in items:
        raise ValueError(f"Unsupported {parameter}: {desired}; available: {items}")
    return desired

try:
    bpy.ops.export_scene.gltf(
        filepath=str(OUTPUT / "reference_frigate.glb"),
        export_format=export_enum(bpy.ops.export_scene.gltf, "export_format", "GLB"),
        use_selection=True,
        export_apply=True,
        export_cameras=False,
        export_lights=False,
    )
    bpy.ops.export_scene.fbx(
        filepath=str(OUTPUT / "reference_frigate.fbx"),
        use_selection=True,
        use_mesh_modifiers=True,
        add_leaf_bones=False,
        bake_anim=False,
        mesh_smooth_type=export_enum(bpy.ops.export_scene.fbx, "mesh_smooth_type", "FACE"),
        axis_forward=export_enum(bpy.ops.export_scene.fbx, "axis_forward", "-Z"),
        axis_up=export_enum(bpy.ops.export_scene.fbx, "axis_up", "Y"),
    )
finally:
    for obj in meshes:
        for index, mat in enumerate(originals[obj.name]):
            obj.data.materials[index] = mat

summary = {
    "reference": "Large three-masted frigate at the upper centre of the user-supplied ship sheet",
    "units": "metres",
    "bow_axis": "-X",
    "mesh_objects": len(meshes),
    "evaluated_triangles": sum(item["triangles"] for item in stats),
    "components": stats,
    "materials": "Procedural weathered materials in .blend; solid base colors in GLB and FBX",
    "game_import": "Detailed source asset. LOD, texture baking, collision and sail animation are not included.",
    "hull_detail_revision": root.get("hull_detail_revision", "Proud bow stem, sternpost and longitudinal rudder, stepped aft gallery"),
    "interior_revision": root.get("interior_revision", 0),
    "collision_revision": root.get("collision_revision", 0),
    "interior": "Sealed planks, open companionway, gun deck, lanterns and aft-facing wheel grips",
}
(OUTPUT / "reference_frigate_manifest.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
print("EXPORTED", summary["mesh_objects"], "meshes;", summary["evaluated_triangles"], "evaluated triangles", flush=True)

scene.camera = bpy.data.objects["Frigate_Presentation"]
scene.render.resolution_x, scene.render.resolution_y = 1600, 1200
scene.render.filepath = str(OUTPUT / "reference_frigate_preview.png")
bpy.ops.render.render(write_still=True)
print("RENDERED presentation", flush=True)

scene.camera = bpy.data.objects["Frigate_Profile"]
scene.render.resolution_x, scene.render.resolution_y = 1400, 1050
scene.render.filepath = str(OUTPUT / "reference_frigate_profile.png")
bpy.ops.render.render(write_still=True)
print("RENDERED profile", flush=True)

for camera_name, filename in [
    ("Frigate_Bow_Detail", "reference_frigate_bow_detail.png"),
    ("Frigate_Stern_Detail", "reference_frigate_stern_detail.png"),
]:
    camera = bpy.data.objects.get(camera_name)
    if camera is not None:
        scene.camera = camera
        scene.render.resolution_x, scene.render.resolution_y = 1200, 1050
        scene.render.filepath = str(OUTPUT / filename)
        bpy.ops.render.render(write_still=True)
        print("RENDERED", camera_name, flush=True)
