"""Exercise a clean rebuild in a temporary folder, without replacing the master."""

import bpy
import runpy
import tempfile
from pathlib import Path

OUTPUT=Path(__file__).resolve().parent
helpers=runpy.run_path(str(OUTPUT/"build_reference_frigate.py"),run_name="frigate_helpers")
assert bpy.data.scenes.get("Reference Frigate") is None,"Use a factory-startup Blender process"
with tempfile.TemporaryDirectory(prefix="frigate-build-check-",dir=str(OUTPUT)) as folder:
    destination=Path(folder).resolve()
    assert destination.parent==OUTPUT.resolve(),"Build must stay inside the asset workspace"
    helpers["build"].__globals__["OUTPUT"]=destination
    helpers["build"]()
    assert (destination/"reference_frigate.blend").is_file()
    assert bpy.data.scenes.get("Scene"),"Default scene was removed"
    root=bpy.data.objects["Reference_Frigate"]
    assert root["interior_revision"]==2
    assert root["mesh_objects"]==79
    for name in ["Ship_Wheel","Gun_Deck_Floor","Companionway_Stairs","Deck_Access_Stairs"]:
        assert bpy.data.objects["Frigate_"+name].parent==root
    assert bpy.data.objects.get("Frigate_Quarterdeck_Stairs") is None
    assert len([o for o in bpy.data.objects if o.type=="LIGHT" and "Interior_Light" in o.name])==6
    for obj in root.children:
        if obj.type=="MESH":
            assert len(obj.data.polygons)>0,obj.name
print("CLEAN GENERATOR REBUILD PASSED; editable master unchanged",flush=True)
