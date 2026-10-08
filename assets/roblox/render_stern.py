"""Close-up of the repaired stern with backface culling enabled."""
import bpy
from pathlib import Path
from mathutils import Vector

scene = bpy.data.scenes["Reference Frigate"]
bpy.context.window.scene = scene
camera_data = bpy.data.cameras.new("Stern_Repair_Inspection")
camera = bpy.data.objects.new("Stern_Repair_Inspection",camera_data)
scene.collection.objects.link(camera)
camera.location = (40,-14,8)
camera.rotation_euler = (Vector((20,0,5.5))-camera.location).to_track_quat("-Z","Y").to_euler()
camera_data.type = "ORTHO"
camera_data.ortho_scale = 13.5
scene.camera = camera
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 1100
scene.render.resolution_y = 1000
scene.render.resolution_percentage = 100
for mat in bpy.data.materials:
    mat.use_backface_culling = True
scene.render.filepath = str(Path(__file__).resolve().parent/"stern_closed_preview.png")
bpy.ops.render.render(write_still=True)
print("STERN PREVIEW",scene.render.filepath,flush=True)
