"""Prepare a non-destructive, vertex-colored Roblox import from the master."""

import json
import math
from pathlib import Path

import bpy
import bmesh
from bpy_extras.io_utils import axis_conversion
from mathutils import Matrix


OUTPUT = Path(__file__).resolve().parent
LIMIT = 18000
scene = bpy.data.scenes["Reference Frigate"]
bpy.context.window.scene = scene
source_root = bpy.data.objects["Reference_Frigate"]
sources = [o for o in scene.objects if o.type == "MESH" and o.parent == source_root]
depsgraph = bpy.context.evaluated_depsgraph_get()
rotation = Matrix.Rotation(-math.pi / 2, 4, "Z")
conversion = axis_conversion(to_forward="-Z", to_up="Y").to_4x4()
collection = bpy.data.collections.new("Roblox_Export")
scene.collection.children.link(collection)
root = bpy.data.objects.new("ReferenceFrigate", None)
collection.objects.link(root)
exports = []
stats = []


def material_color(material):
    if material and material.use_nodes:
        shader = next((n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if shader:
            return tuple(shader.inputs["Base Color"].default_value)
    return tuple(material.diffuse_color) if material else (0.4, 0.3, 0.2, 1.0)


def face_batches(mesh):
    mesh.calc_loop_triangles()
    counts = [0] * len(mesh.polygons)
    for triangle in mesh.loop_triangles:
        counts[triangle.polygon_index] += 1
    if sum(counts) <= LIMIT:
        return [list(range(len(mesh.polygons)))]

    # Keep each disconnected plank closed instead of cutting across its faces.
    vertex_faces = [[] for _ in mesh.vertices]
    for face in mesh.polygons:
        for vertex in face.vertices:
            vertex_faces[vertex].append(face.index)
    remaining = set(range(len(mesh.polygons)))
    islands = []
    while remaining:
        todo = [min(remaining)]
        remaining.remove(todo[0])
        island = []
        while todo:
            index = todo.pop()
            island.append(index)
            for vertex in mesh.polygons[index].vertices:
                for neighbor in vertex_faces[vertex]:
                    if neighbor in remaining:
                        remaining.remove(neighbor)
                        todo.append(neighbor)
        assert sum(counts[i] for i in island) <= LIMIT, "Connected mesh needs explicit simplification"
        islands.append(island)
    batches, current, total = [], [], 0
    for island in islands:
        count = sum(counts[i] for i in island)
        if total + count > LIMIT:
            batches.append(current)
            current, total = [], 0
        current.extend(island)
        total += count
    if current:
        batches.append(current)
    return batches


for source in sorted(sources, key=lambda o: o.name):
    source_name = source.name
    source.name = "Source_" + source_name
    evaluated = source.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    triangulated = bmesh.new()
    triangulated.from_mesh(mesh)
    bmesh.ops.triangulate(triangulated, faces=list(triangulated.faces))
    triangulated.to_mesh(mesh)
    triangulated.free()
    mesh.update()
    batches = face_batches(mesh)
    colors = [material_color(m) for m in mesh.materials]
    for batch_index, indices in enumerate(batches):
        name = source_name + (f"_Chunk{batch_index + 1:02d}" if len(batches) > 1 else "")
        vertex_map, vertices, faces = {}, [], []
        for index in indices:
            face = mesh.polygons[index]
            remapped = []
            for old in face.vertices:
                if old not in vertex_map:
                    vertex_map[old] = len(vertices)
                    vertices.append(rotation @ source.matrix_world @ mesh.vertices[old].co)
                remapped.append(vertex_map[old])
            faces.append(remapped)
        data = bpy.data.meshes.new(name)
        data.from_pydata(vertices, [], faces)
        data.update()
        attribute = data.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="CORNER")
        data.color_attributes.active_color = attribute
        for new_face, old_index in zip(data.polygons, indices):
            old_face = mesh.polygons[old_index]
            new_face.use_smooth = old_face.use_smooth
            color = colors[old_face.material_index] if colors else (0.4, 0.3, 0.2, 1.0)
            for loop_index in new_face.loop_indices:
                attribute.data[loop_index].color = color
        data.calc_loop_triangles()
        assert len(data.loop_triangles) <= LIMIT
        assert all(math.isfinite(c) for vertex in data.vertices for c in vertex.co)
        obj = bpy.data.objects.new(name, data)
        obj.parent = root
        collection.objects.link(obj)
        exports.append(obj)
        stats.append({"name": obj.name, "source": source_name, "triangles": len(data.loop_triangles)})
    evaluated.to_mesh_clear()

for obj in scene.objects:
    obj.select_set(obj == root or obj in exports)
bpy.context.view_layer.objects.active = root
scene.unit_settings.system = "NONE"
scene.unit_settings.scale_length = 1.0


def enum_value(operator, parameter, desired):
    values = [i.identifier for i in operator.get_rna_type().properties[parameter].enum_items]
    assert desired in values, (parameter, values)
    return desired


bpy.ops.export_scene.fbx(
    filepath=str(OUTPUT / "reference_frigate_roblox.fbx"),
    use_selection=True,
    use_mesh_modifiers=False,
    apply_unit_scale=False,
    add_leaf_bones=False,
    bake_anim=False,
    mesh_smooth_type=enum_value(bpy.ops.export_scene.fbx, "mesh_smooth_type", "FACE"),
    axis_forward=enum_value(bpy.ops.export_scene.fbx, "axis_forward", "-Z"),
    axis_up=enum_value(bpy.ops.export_scene.fbx, "axis_up", "Y"),
)
points = [conversion @ vertex.co for obj in exports for vertex in obj.data.vertices]
minimum = [min(point[i] for point in points) for i in range(3)]
maximum = [max(point[i] for point in points) for i in range(3)]
manifest = {
    "source": "../blender/reference_frigate.blend",
    "mesh_objects": len(exports),
    "total_triangles": sum(item["triangles"] for item in stats),
    "maximum_triangles_per_mesh": max(item["triangles"] for item in stats),
    "export_budget_per_mesh": LIMIT,
    "roblox_bow_axis": "-Z",
    "roblox_up_axis": "+Y",
    "import_scale_unit": "Studs",
    "bounds_min": minimum,
    "bounds_max": maximum,
    "dimensions_studs": [maximum[i] - minimum[i] for i in range(3)],
    "colors": "Per-face linear RGBA stored as vertex colors; keep Ignore Vertex Colors disabled",
    "limitations": "Detailed static asset. Procedural textures, gameplay collision, LOD and sail animation are not included.",
    "studio_import_status": "Not imported or uploaded by this script",
    "interior_revision": source_root.get("interior_revision", 0),
    "collision_revision": source_root.get("collision_revision", 0),
    "access_hatch_source": {"z0": 2.4, "z1": 8.6, "width": 2.8},
    "gun_deck_floor_source_y": 4.18,
    "wheel_source": {"x": 14.2, "y": 0, "z": 9.65, "grip_facing": "+X (aft)"},
    "components": stats,
}
(OUTPUT / "reference_frigate_roblox_manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
print("ROBLOX_EXPORT", json.dumps({k: v for k, v in manifest.items() if k != "components"}), flush=True)
