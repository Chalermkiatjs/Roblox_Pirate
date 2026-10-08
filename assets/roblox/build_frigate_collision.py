"""Generate native Roblox hitboxes from the editable, unmodified source geometry."""
import json
import math
import runpy
from collections import Counter
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
H = runpy.run_path(str(ROOT / "assets/blender/build_reference_frigate.py"),run_name="helpers")
parts = []


def canonical(p):
    return Vector((p[1],p[2],p[0]))


def add(name,category,position,size,axes=None,kind="Block",requires=None,follow=None):
    axes = axes or [Vector((1,0,0)),Vector((0,1,0)),Vector((0,0,1))]
    assert all(math.isfinite(v) for p in [position,size,*axes] for v in p), name
    assert min(size)>1e-6, name
    assert abs(axes[0].cross(axes[1]).dot(axes[2])-1)<1e-5, name
    item = dict(name=name,category=category,position=list(position),size=list(size),
                axes=[list(a) for a in axes],kind=kind)
    if requires:
        item["requires"] = requires
    if follow:
        item["follow"] = follow
    parts.append(item)


def plate(name,category,points,thickness=.12,requires=None):
    points = [canonical(p) for p in points]
    x = (points[1]-points[0]).normalized()
    normal = x.cross(points[-1]-points[0]).normalized()
    y = normal.cross(x).normalized()
    axes = [x,y,normal]
    bounds = [(min(p.dot(a) for p in points),max(p.dot(a) for p in points)) for a in axes]
    center = sum((a*((lo+hi)/2) for a,(lo,hi) in zip(axes,bounds)),Vector())
    add(name,category,center,[bounds[0][1]-bounds[0][0]+.025,
                            bounds[1][1]-bounds[1][0]+.025,
                            max(thickness,bounds[2][1]-bounds[2][0]+thickness)],axes,requires=requires)


def triangle(name,category,a,b,c,thickness=.1,requires=None):
    a,b,c = map(canonical,(a,b,c))
    ab,ac,bc = b-a,c-a,c-b
    if ab.length_squared>max(ac.length_squared,bc.length_squared):
        a,c = c,a
    elif ac.length_squared>max(ab.length_squared,bc.length_squared):
        a,b = b,a
    ab,ac,bc = b-a,c-a,c-b
    right = ac.cross(ab).normalized()
    if right.length<.99:
        return
    up = bc.cross(right).normalized()
    back = bc.normalized()
    height = abs(ab.dot(up))
    # Native WedgePart's local X is thickness; put its upper face on the art plane.
    normal = right if right.y>=0 else -right
    for index,(endpoint,length,axes) in enumerate([
            (b,abs(ab.dot(back)),[right,up,back]),
            (c,abs(ac.dot(back)),[-right,up,-back])]):
        if length>1e-5 and height>1e-5:
            add(name+f"_{index}",category,(a+endpoint)/2-normal*thickness/2,
                [thickness,height,length],axes,kind="Wedge",requires=requires)


def floor_strip(name,category,x0,x1,ya,yb,elevation,breadth,requires=None):
    # Reuse the source's outline clipping, not an undersized rectangle at the narrow end.
    collector = H["Geometry"]("Collision",None)
    H["deck_board"](collector,x0,x1,ya,yb,elevation,breadth,None)
    if not collector.faces:
        return
    outline = [collector.vertices[i] for i in collector.faces[0]]
    for i in range(1,len(outline)-1):
        triangle(name+f"_{i}",category,outline[0],outline[i],outline[i+1],requires=requires)


def floors():
    h0,h1,half = H["ACCESS_HATCH"]
    divisions = sorted(set([x for x,_ in H["STATIONS"]]+list(range(-21,21,2))+[20,h0,h1]))
    for i,(a,b) in enumerate(zip(divisions,divisions[1:])):
        intervals = [(-6,6)] if not h0<=((a+b)/2)<=h1 else [(-6,-half),(half,6)]
        for j,(ya,yb) in enumerate(intervals):
            floor_strip(f"DeckSegment{i}_{j}","MainFloor",a,b,ya,yb,
                        lambda x:6.35+H["sheer"](x),lambda x:max(.04,H["side_y"](x,6.35)-.04))
    for i,a in enumerate(range(-16,12,2)):
        floor_strip(f"GunDeckFloor{i}","GunFloor",a,a+2,-6,6,
                    lambda x:4.18+H["sheer"](x),lambda x:H["side_y"](x,4.18)-.16,
                    "Frigate_Gun_Deck_Floor")
    for tier,spec in enumerate(H["GALLERY_SPECS"]):
        point = H["gallery_point"](spec)
        def roof(u,r):
            p=point(u,1,1)
            return Vector((p.x,(p.y+.14)*r,p.z+.07+.16*(1-r*r)))
        for i in range(2):
            for j in range(4):
                a,b = i/2,(i+1)/2
                c,d = -1+j/2,-1+(j+1)/2
                p = [roof(a,c),roof(b,c),roof(b,d),roof(a,d)]
                name = ("Quarterdeck" if tier==0 else "PoopDeck")+f"{i}_{j}"
                triangle(name+"A","GalleryFloor",*p[:3])
                triangle(name+"B","GalleryFloor",p[0],p[2],p[3])


def shells():
    for side in [-1,1]:
        for i,((a,_),(b,_)) in enumerate(zip(H["STATIONS"],H["STATIONS"][1:])):
            for j,(lo,hi) in enumerate(zip([0,1.3,2.8,4.18],[1.3,2.8,4.18,6.45])):
                plate(f"HullWall{side}_{i}_{j}","HullWall",
                      [(x,side*H["side_y"](x,z),H["hull_z"](x,z))
                       for x,z in [(a,lo),(b,lo),(b,hi),(a,hi)]])
    levels = [i*6.45/16 for i in range(17)]
    for i,(lo,hi) in enumerate(zip(levels,levels[1:])):
        plate(f"TransomWall{i}","Transom",[(20,s*H["side_y"](20,z),H["hull_z"](20,z))
              for s,z in [(-1,lo),(1,lo),(1,hi),(-1,hi)]],.18)
    for tier,spec in enumerate(H["GALLERY_SPECS"]):
        point = H["gallery_point"](spec)
        for side in [-1,1]:
            plate(f"CabinSide{tier}_{side}","CabinWall",
                  [point(u,v,side) for u,v in [(0,0),(1,0),(1,1),(0,1)]])
        for u in [0,1]:
            plate(f"CabinEnd{tier}_{u}","CabinWall",
                  [point(u,v,s) for s,v in [(-1,0),(1,0),(1,1),(-1,1)]])


def guard(name,a,b,height,category="Rail"):
    a,b = Vector(a),Vector(b)
    plate(name,category,[a,b,b+Vector((0,0,height)),a+Vector((0,0,height))],.12)


def railings():
    for side in [-1,1]:
        for i in range(35):
            a,b = -19.5+i*.92,-19.5+(i+1)*.92
            guard(f"DeckRail{side}_{i}",(a,side*H["width"](a)*.97,6.6+H["sheer"](a)),
                  (b,side*H["width"](b)*.97,6.6+H["sheer"](b)),.85)
    for tier,spec in enumerate(H["GALLERY_SPECS"]):
        point = H["gallery_point"](spec)
        end = .34 if tier==0 else 1
        for side in [-1,1]:
            offset = Vector((0,side*.12,.12))
            guard(f"GalleryRail{tier}_{side}",point(0,1,side)+offset,point(end,1,side)+offset,.82)
        for u in ([0] if tier==0 else [0,1]):
            p = point(u,1,1)
            half = p.y+.12
            intervals = [(-half,half)]
            if u==0:
                gap = (-1.8,1.8) if tier==0 else (-2.85,-.75)
                intervals = [(-half,gap[0]),(gap[1],half)]
            for i,(a,b) in enumerate(intervals):
                guard(f"GalleryEndRail{tier}_{u}_{i}",(p.x,a,p.z+.12),(p.x,b,p.z+.12),.82)
    for side in [-1,1]:
        guard(f"HatchGuard{side}",(2.4,side*1.455,6.35),(8.6,side*1.455,6.35),.85,"HatchGuard")
    guard("HatchForwardGuard",(2.35,-1.455,6.35),(2.35,1.455,6.35),.85,"HatchGuard")


def islands(mesh):
    adjacency = [set() for _ in mesh.vertices]
    for edge in mesh.edges:
        a,b = edge.vertices
        adjacency[a].add(b)
        adjacency[b].add(a)
    todo = set(range(len(mesh.vertices)))
    faces = [[] for _ in mesh.vertices]
    for face in mesh.polygons:
        for i in face.vertices:
            faces[i].append(face)
    while todo:
        seed = min(todo)
        todo.remove(seed)
        stack,group = [seed],[]
        while stack:
            i = stack.pop()
            group.append(i)
            for j in adjacency[i]&todo:
                todo.remove(j)
                stack.append(j)
        fs = {f.index:f for i in group for f in faces[i]}
        yield sorted(group),list(fs.values())


def primitives():
    names = ["Deck_Fittings","Interior_Frames_And_Beams","Interior_Cargo_And_Berths",
             "Interior_Bulkheads","Companionway_Stairs","Deck_Access_Stairs","Wheel_Pedestal",
             "Bowsprit_And_Booms","Rudder_Stock"]
    names += [o.name.removeprefix("Frigate_") for o in bpy.data.objects if o.name.startswith("Frigate_Cannon_")]
    for name in names:
        obj = bpy.data.objects["Frigate_"+name]
        category = "Stairs" if "Stairs" in name else "Prop"
        for index,(indices,faces) in enumerate(islands(obj.data)):
            points = [canonical(obj.matrix_world@obj.data.vertices[i].co) for i in indices]
            center = sum(points,Vector())/len(points)
            if name=="Interior_Bulkheads":
                continue
            if name=="Deck_Fittings" and -5.1<center.z<-2.3 and abs(center.x)<1.6:
                continue
            follow = obj.name if name=="Rudder_Stock" else None
            if len(points)==8 and len(faces)==6 and all(len(f.vertices)==4 for f in faces):
                vectors = [points[i]-points[0] for i in [1,3,4]]
                if category=="Stairs" and vectors[2].length>.12 and vectors[0].length<.1:
                    continue
                axes = [v.normalized() for v in vectors]
                if axes[0].cross(axes[1]).dot(axes[2])<0:
                    axes[2] = -axes[2]
                add(name+str(index),category,center,[v.length for v in vectors],axes,requires=obj.name)
            else:
                caps = [f for f in faces if len(f.vertices)>4]
                if len(caps)!=2 or len(points)!=2*len(caps[0].vertices):
                    continue
                rings = [[canonical(obj.matrix_world@obj.data.vertices[i].co) for i in f.vertices] for f in caps]
                a,b = [sum(r,Vector())/len(r) for r in rings]
                direction = b-a
                if direction.length<.015:
                    continue
                if name.startswith("Cannon_") and direction.length<.15:
                    continue
                x = direction.normalized()
                reference = Vector((0,1,0)) if abs(x.y)<.9 else Vector((0,0,1))
                z = x.cross(reference).normalized()
                y = z.cross(x).normalized()
                radius = max((p-c).length for ring,c in zip(rings,[a,b]) for p in ring)
                add(name+str(index),category,(a+b)/2,[direction.length,2*radius,2*radius],
                    [x,y,z],"Cylinder",obj.name,follow)
    for x,top in [(-10.3,32*.52+1),(1,36*.52+1),(11.3,27.5*.52+1)]:
        bottom = 6.35+H["sheer"](x)
        add(f"MastCollision{x}","Mast",canonical((x,0,(bottom+top)/2)),
            [top-bottom,.78,.78],[Vector((0,1,0)),Vector((0,0,1)),Vector((1,0,0))],"Cylinder")
    add("ClosedForeHatch","Prop",canonical((-3.7,0,(6.485+6.965)/2)),[3.1,.48,2.7])
    for x in [-16,12]:
        add(f"GunDeckBulkhead{x}","Bulkhead",canonical((x,0,5.22+H["sheer"](x))),
            [2*(H["side_y"](x,4.18)-.16),2.08,.12],requires="Frigate_Interior_Bulkheads")
    add("WheelCollision","Wheel",canonical((14.2,0,9.65)),[.26,1.92,1.92],
        [Vector((0,0,1)),Vector((0,1,0)),Vector((-1,0,0))],"Cylinder","Frigate_Ship_Wheel")
    blade = bpy.data.objects["Frigate_Rudder_Blade"]
    points = [canonical(blade.matrix_world@v.co) for v in blade.data.vertices]
    lo,hi = [Vector([fn(p[i] for p in points) for i in range(3)]) for fn in [min,max]]
    add("RudderBladeCollision","Rudder",(lo+hi)/2,hi-lo,requires=blade.name,follow=blade.name)
    for x in [-12,-4,10]:
        for side in [-1,1]:
            add(f"LanternCollision{x}_{side}","Lantern",canonical((x,side*2.9,6+H["sheer"](x))),
                [.27,.52,.27],requires="Frigate_Interior_Lanterns")


def lua(value):
    if isinstance(value,dict):
        return "{"+", ".join(k+" = "+lua(v) for k,v in value.items())+"}"
    if isinstance(value,list):
        return "{"+", ".join(lua(v) for v in value)+"}"
    if isinstance(value,str):
        return json.dumps(value)
    return format(value,".8g")


floors()
shells()
railings()
primitives()
assert len(parts)<800, len(parts)
data = {"Revision":3,"Parts":parts}
module = "-- Generated by assets/roblox/build_frigate_collision.py; canonical source units.\nreturn {\n    Revision = 3,\n    Parts = {\n"
module += "".join("        "+lua(p)+",\n" for p in parts)
module += "    },\n}\n"
(ROOT/"src/shared/FrigateCollision.lua").write_text(module,encoding="utf-8")
report = {"revision":3,"parts":len(parts),"categories":dict(Counter(p["category"] for p in parts)),
          "studio_play_status":"Not tested in Studio","data":data}
(ROOT/"assets/roblox/frigate_collision_manifest.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
print("COLLISION GENERATED",len(parts),report["categories"])
