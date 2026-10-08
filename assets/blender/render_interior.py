"""Render interior, wheel and plank-join inspection views from the master."""

import bpy
from pathlib import Path

OUTPUT=Path(__file__).resolve().parent
scene=bpy.data.scenes["Reference Frigate"]
bpy.context.window.scene=scene
scene.render.resolution_x,scene.render.resolution_y=1400,1000
for name,filename in [
    ("Interior_Detail","reference_frigate_interior.png"),
    ("Wheel_Detail","reference_frigate_wheel.png"),
    ("Hull_Joins_Detail","reference_frigate_plank_joins.png"),
    ("Hatch_Detail","reference_frigate_hatch.png"),
]:
    hidden={}
    if name=="Hatch_Detail":
        for obj in scene.objects:
            if any(word in obj.name for word in ["Sail","Spars","Ratlines","Stays"]):
                hidden[obj]=obj.hide_render
                obj.hide_render=True
    scene.camera=bpy.data.objects["Frigate_"+name]
    scene.render.filepath=str(OUTPUT/filename)
    bpy.ops.render.render(write_still=True)
    for obj,state in hidden.items():
        obj.hide_render=state
    print("RENDERED",filename,flush=True)
