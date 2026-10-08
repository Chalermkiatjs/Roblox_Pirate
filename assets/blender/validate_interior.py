"""Check actual source surfaces, the hatch and closed plank joins with ray casts."""

import bpy
import json
import runpy
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

OUTPUT = Path(__file__).resolve().parent
helpers = runpy.run_path(str(OUTPUT / "build_reference_frigate.py"),run_name="frigate_helpers")
scene=bpy.data.scenes["Reference Frigate"]
bpy.context.window.scene=scene
deps=bpy.context.evaluated_depsgraph_get()
def tree(name):
    return BVHTree.FromObject(bpy.data.objects["Frigate_"+name],deps)
def down(mesh,x,y,z=8):
    return mesh.ray_cast(Vector((x,y,z)),Vector((0,0,-1)),10)[0]
main,gun,hull=tree("Main_Deck_Planks"),tree("Gun_Deck_Floor"),tree("Hull_Planking")
for x in [2.5,3,4,5,6,7,8.5]:
    for y in [-1.3,0,1.3]:
        assert down(main,x,y) is None, f"Blocked hatch at {x,y}"
    for y in [-1.5,1.5]:
        assert down(main,x,y) is not None, f"Missing side walkway at {x,y}"
for x in [-15.8,-12,-8,-4,0,2.4,5,8.6,11.8]:
    for y in [-2,0,2]:
        hit=down(gun,x,y)
        assert hit is not None,f"Missing gun-deck floor at {x,y}"
        assert hit.z>4.1,"Interior overlaps the solid buoyancy proxy"
for x in [-15,-7,0,7,14,19]:
    for z in [0.7,1.05,1.4,2.1,2.8,3.5,5.6,5.95,6.3]:
        for epsilon in [-0.004,0,0.004]:
            height=helpers["hull_z"](x,z+epsilon)
            hit=hull.ray_cast(Vector((x,-12,height)),Vector((0,1,0)),12)[0]
            assert hit is not None,f"Light-leaking hull plank join at {x,z,epsilon}"
for x in [-14,-6,-2,0,10,14]:
    for y in [-2.7,-1.8,-0.9,0,0.9,1.8,2.7]:
        assert down(main,x,y) is not None,f"Main deck plank gap at {x,y}"
for x in [-20.8,-20.3,-19.6,-18.6,-17.3]:
    for side in [-1,1]:
        for fraction in [0.2,0.6,0.94]:
            y=side*(helpers["side_y"](x,6.35)-0.04)*fraction
            assert down(main,x,y) is not None,f"Unfilled triangular bow plank at {x,y}"
surface_samples=0
for i in range(205):
    x=-20.9+i*0.2
    half=max(0.04,helpers["side_y"](x,6.35)-0.04)
    for fraction in [-0.96,-0.75,-0.5,-0.25,0,0.25,0.5,0.75,0.96]:
        y=half*fraction
        h0,h1,hhalf=helpers["ACCESS_HATCH"]
        opening=h0+1e-5<x<h1-1e-5 and abs(y)<hhalf-1e-5
        assert (down(main,x,y) is None)==opening,f"Incorrect deck coverage at {x,y}"
        surface_samples+=1
beams=tree("Interior_Frames_And_Beams")
headroom=[]
for x in [-15,-14,-12,-10,-8,-6,-4,-2,0,1,2,10,11.5]:
    for y in [-1.5,1.5]:
        floor_hit=down(gun,x,y)
        start=floor_hit+Vector((0,0,0.01))
        hits=[t.ray_cast(start,Vector((0,0,1)),4)[0] for t in [main,beams]]
        clearance=min(hit.z-floor_hit.z for hit in hits if hit is not None)
        assert clearance*3 >= 5.6,f"Low interior headroom at {x,y}: {clearance*3}"
        headroom.append(clearance*3)
stairs=tree("Companionway_Stairs")
low=helpers["GUN_DECK_Y"]+helpers["sheer"](3)
rise=6.35+helpers["sheer"](8.6)-low
for i in range(14):
    x=3+(8.6-3)*(i+0.5)/14
    hit=down(stairs,x,0)
    assert hit is not None and abs(hit.z-(low+rise*(i+1)/14))<0.001,"Incorrect stair tread surface"
wheel=bpy.data.objects["Frigate_Ship_Wheel"]
pedestal=bpy.data.objects["Frigate_Wheel_Pedestal"]
assert max(v.co.x for v in pedestal.data.vertices) < helpers["WHEEL_X"]+0.15
assert min(v.co.x for v in wheel.data.vertices) > helpers["WHEEL_X"]-0.15
assert min(v.co.z for v in pedestal.data.vertices) > 8.96,"Wheel base hidden below deck"
assert wheel.dimensions.x < wheel.dimensions.y*0.25,"Wheel not across the ship beam"
rails=tree("Bulwarks_And_Railings")
for x,y,z in [(13.15,0,9.4),(16,-1.8,10.95)]:
    assert rails.ray_cast(Vector((x-0.2,y,z)),Vector((1,0,0)),0.4)[0] is None,"Rails block a deck staircase"
assert min(6.2-0.12-helpers["GUN_DECK_Y"],6.35-0.12-helpers["GUN_DECK_Y"])*3 >= 5.6
report={"sealed_hull_joins":True,"sealed_deck_joins":True,"open_hatch":True,
        "walkable_gun_deck":True,"wheel_pedestal_forward":True,"revision":2,
        "deck_surface_samples":surface_samples,"minimum_sampled_headroom_studs":min(headroom),
        "verified_treads":14}
(OUTPUT/"interior_validation.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
print("SOURCE INTERIOR VALIDATED",json.dumps(report),flush=True)
