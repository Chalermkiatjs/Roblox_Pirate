"""Offline checks of native primitive coverage. These do not replace Studio physics tests."""
import json
import math
import runpy
from pathlib import Path
import bpy
import bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[2]
H = runpy.run_path(str(ROOT/"assets/blender/build_reference_frigate.py"),run_name="helpers")
data = json.loads((ROOT/"assets/roblox/frigate_collision_manifest.json").read_text())["data"]
parts = data["Parts"]


def geometry(spec):
    half = Vector(spec["size"])/2
    if spec["kind"]=="Wedge":
        # Roblox WedgePart: tall edge at local +Z, slope toward local -Z.
        local = [Vector((x*half.x,y*half.y,z*half.z)) for x in [-1,1]
                 for y,z in [(-1,-1),(-1,1),(1,1)]]
        faces = [(0,1,2),(5,4,3),(0,3,4,1),(1,4,5,2),(2,5,3,0)]
    elif spec["kind"]=="Cylinder":
        n = 24
        local = [Vector((x*half.x,math.cos(i*math.tau/n)*half.y,math.sin(i*math.tau/n)*half.z))
                 for x in [-1,1] for i in range(n)]
        faces = [tuple(range(n)),tuple(range(n,2*n))]
        faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    else:
        local = [Vector((x*half.x,y*half.y,z*half.z)) for x,y,z in
                 [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),
                  (-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
        faces = [(0,1,2,3),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    axes = [Vector(a) for a in spec["axes"]]
    position = Vector(spec["position"])
    return [position+sum((a*v for a,v in zip(axes,p)),Vector()) for p in local],faces


def tree(categories):
    verts,faces = [],[]
    for p in parts:
        if p["category"] not in categories:
            continue
        vs,fs = geometry(p)
        offset = len(verts)
        verts.extend(vs)
        faces.extend(tuple(i+offset for i in f) for f in fs)
    return BVHTree.FromPolygons(verts,faces)


def down(t,x,z,y=12):
    return t.ray_cast(Vector((x,y,z)),Vector((0,-1,0)),20)[0]


main,gun,gallery = [tree({cat}) for cat in ["MainFloor","GunFloor","GalleryFloor"]]
samples = 0
for i in range(410):
    z = -20.95+i*.1
    half = max(.04,H["side_y"](z,6.35)-.04)
    for fraction in [-.98,-.9,-.75,-.5,-.25,0,.25,.5,.75,.9,.98]:
        x = half*fraction
        opening = 2.4<z<8.6 and abs(x)<1.4
        hit = down(main,x,z)
        assert (hit is None)==opening, f"Floor gap/blocked hatch {x,z}"
        if hit:
            assert abs(hit.y-(6.35+H["sheer"](z)))<.045, f"Floating floor {x,z,hit.y}"
        samples += 1
for z in [-15.9+i*.2 for i in range(140)]:
    half = H["side_y"](z,4.18)-.16
    for f in [-.97,-.75,-.5,0,.5,.75,.97]:
        assert down(gun,half*f,z), f"Missing lower floor {f,z}"
        samples += 1
for spec in H["GALLERY_SPECS"]:
    point = H["gallery_point"](spec)
    for i in range(1,20):
        for j in range(1,20):
            u,r = i/20,-1+j/10
            p = point(u,1,1)
            x,z = (p.y+.14)*r,p.x
            expected = p.z+.07+.16*(1-r*r)
            hit = down(gallery,x,z,expected+.03)
            assert hit and abs(hit.y-expected)<.012, f"Gallery gap/height {x,z,expected,hit}"
            samples += 1
walls = tree({"HullWall","Transom"})
wall_samples = 0
for z in [-20.8+i*.2 for i in range(204)]:
    for level in [1,2,3,4.3,5,6]:
        y = H["hull_z"](z,level)
        for side in [-1,1]:
            assert walls.ray_cast(Vector((side*10,y,z)),Vector((-side,0,0)),10)[0], f"Hull wall hole {side,y,z}"
            wall_samples += 1
for level in [.1+i*.1 for i in range(63)]:
    y = H["hull_z"](20,level)
    for fraction in [-.9,-.5,0,.5,.9]:
        x = H["side_y"](20,level)*fraction
        assert walls.ray_cast(Vector((x,y,23)),Vector((0,0,-1)),5)[0], f"Transom collider hole {x,y}"
        wall_samples += 1

def contains(part,point,margin=0):
    delta = point-Vector(part["position"])
    q = [delta.dot(Vector(a)) for a in part["axes"]]
    half = Vector(part["size"])/2
    if part["kind"]=="Cylinder":
        return abs(q[0])<half.x+margin and (q[1]**2+q[2]**2)**.5<half.y+margin
    if part["kind"]=="Wedge":
        return (abs(q[0])<half.x+margin and abs(q[2])<half.z+margin and
                q[1]>-half.y-margin and q[1]<q[2]*half.y/half.z+margin)
    return all(abs(q[i])<half[i]+margin for i in range(3))

# A 2-stud-wide, 5.4-stud-high avatar volume over each tread must clear walls/guards.
path_samples = 0
stair_specs = [(3,8.6,4.18+H["sheer"](3),6.35+H["sheer"](8.6),0,14),
               (10,13.1,6.45,8.97,.95,14),(14,16.1,9,10.53,-1.8,9)]
obstacles = [p for p in parts if p["category"] not in
             {"MainFloor","GunFloor","GalleryFloor","Stairs","HullWall","Transom"}]
for a,b,lo,hi,x,count in stair_specs:
    for i in range(count):
        z = a+(b-a)*(i+.5)/count
        floor = lo+(hi-lo)*(i+1)/count
        for dx in [-.32,0,.32]:
            for dy in [.05,.6,1.2,1.8]:
                point = Vector((x+dx,floor+dy,z))
                for p in obstacles:
                    assert not contains(p,point), f"Blocked stairs by {p['name']} at {tuple(point)}"
                path_samples += 1
for name in ["Frigate_Stern_Transom_Planking","Frigate_Stepped_Cambered_Quarterdecks"]:
    bm = bmesh.new()
    bm.from_mesh(bpy.data.objects[name].data)
    assert all(e.is_manifold for e in bm.edges), f"Open shell {name}"
    assert bm.calc_volume(signed=True)>0, f"Inside-out shell {name}"
    bm.free()
for p in parts:
    if p.get("requires"):
        assert bpy.data.objects.get(p["requires"]), p["requires"]
    if p.get("follow"):
        assert p["follow"] in ["Frigate_Rudder_Stock","Frigate_Rudder_Blade"]
report = dict(status="passed",collision_parts=len(parts),floor_samples=samples,
              shell_samples=wall_samples,stair_avatar_samples=path_samples,
              transom_and_roofs_closed=True,studio_play="Not tested")
(ROOT/"assets/roblox/collision_validation.json").write_text(json.dumps(report,indent=2))
print("COLLISION VALIDATED",json.dumps(report),flush=True)
