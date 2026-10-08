"""Build an editable three-masted frigate inspired by the supplied ship sheet.

Run in Blender's Python environment. The original scene is preserved.
The procedural materials belong to the .blend; interchange exports use base colors.
"""

import bpy
import math
import random
from pathlib import Path
from mathutils import Vector, Quaternion


OUTPUT = Path(__file__).resolve().parent
SCENE_NAME = "Reference Frigate"
PREFIX = "Frigate_"
RNG = random.Random(1708)


def enum_id(owner, prop, wanted):
    available = [item.identifier for item in owner.bl_rna.properties[prop].enum_items]
    if wanted not in available:
        raise ValueError(f"{wanted} not in {prop}: {available}")
    return wanted


def factory_enum(collection, prop, wanted):
    available = [i.identifier for i in collection.bl_rna.functions["new"].parameters[prop].enum_items]
    if wanted not in available:
        raise ValueError(f"Unsupported {prop}: {wanted}")
    return wanted


def socket(node, identifier):
    return next(s for s in node.inputs if s.identifier == identifier or s.name == identifier)


def material(name, color, roughness=0.65, metallic=0.0, grain=None):
    mat = bpy.data.materials.new(PREFIX + name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    shader = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    socket(shader, "Base Color").default_value = (*color, 1)
    socket(shader, "Roughness").default_value = roughness
    socket(shader, "Metallic").default_value = metallic
    if grain:
        texcoord = nodes.new("ShaderNodeTexCoord")
        stretch = nodes.new("ShaderNodeVectorMath")
        stretch.operation = enum_id(stretch, "operation", "MULTIPLY")
        stretch.inputs[1].default_value = grain
        noise = nodes.new("ShaderNodeTexNoise")
        socket(noise, "Scale").default_value = 2.8
        socket(noise, "Detail").default_value = 3.0
        ramp = nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].position = 0.18
        low, high = (0.84, 1.08) if "Linen" in name else (0.58, 1.18)
        ramp.color_ramp.elements[0].color = (*(c * low for c in color), 1)
        ramp.color_ramp.elements[1].position = 0.83
        ramp.color_ramp.elements[1].color = (*(min(1, c * high) for c in color), 1)
        bump = nodes.new("ShaderNodeBump")
        socket(bump, "Strength").default_value = 0.16
        socket(bump, "Distance").default_value = 0.045
        links.new(texcoord.outputs[0], stretch.inputs[0])
        links.new(stretch.outputs[0], noise.inputs[0])
        links.new(noise.outputs[0], ramp.inputs[0])
        links.new(ramp.outputs[0], socket(shader, "Base Color"))
        links.new(noise.outputs[0], socket(bump, "Height"))
        links.new(bump.outputs[0], socket(shader, "Normal"))
    return mat


class Geometry:
    """Accumulate mesh parts without thousands of UI operators."""

    def __init__(self, name, collection):
        self.name, self.collection = name, collection
        self.vertices, self.faces, self.indices, self.materials = [], [], [], []

    def part(self, verts, faces, mat):
        offset = len(self.vertices)
        if mat not in self.materials:
            self.materials.append(mat)
        idx = self.materials.index(mat)
        self.vertices.extend(tuple(v) for v in verts)
        self.faces.extend(tuple(offset + i for i in face) for face in faces)
        self.indices.extend([idx] * len(faces))

    def box(self, center, size, mat, rotation=None):
        center, half = Vector(center), Vector(size) * 0.5
        points = [Vector((x * half.x, y * half.y, z * half.z))
                  for x, y, z in [(-1,-1,-1), (1,-1,-1), (1,1,-1), (-1,1,-1),
                                  (-1,-1,1), (1,-1,1), (1,1,1), (-1,1,1)]]
        points = [center + (rotation @ p if rotation else p) for p in points]
        self.part(points, [(0,3,2,1), (4,5,6,7), (0,1,5,4),
                           (1,2,6,5), (2,3,7,6), (3,0,4,7)], mat)

    def rod(self, start, end, radius, mat, end_radius=None, sides=10):
        a, b = Vector(start), Vector(end)
        direction = b - a
        if direction.length < 0.0001:
            return
        quat = direction.to_track_quat("Z", "Y")
        end_radius = radius if end_radius is None else end_radius
        verts = []
        for pos, r in [(a, radius), (b, end_radius)]:
            verts.extend(pos + quat @ Vector((r * math.cos(i * math.tau / sides),
                                              r * math.sin(i * math.tau / sides), 0))
                         for i in range(sides))
        faces = [(i, (i+1)%sides, (i+1)%sides+sides, i+sides) for i in range(sides)]
        faces += [tuple(reversed(range(sides))), tuple(range(sides, sides*2))]
        self.part(verts, faces, mat)

    def line(self, points, radius, mat, sides=6):
        # Shared rings keep the exportable rigging mesh compact.
        verts, faces = [], []
        for i, point in enumerate(points):
            prev = Vector(points[max(0, i-1)])
            nxt = Vector(points[min(len(points)-1, i+1)])
            direction = nxt - prev
            quat = direction.to_track_quat("Z", "Y")
            verts.extend(Vector(point) + quat @ Vector((radius*math.cos(j*math.tau/sides),
                                                        radius*math.sin(j*math.tau/sides), 0))
                         for j in range(sides))
            if i:
                a, b = (i-1)*sides, i*sides
                faces.extend((a+j, a+(j+1)%sides, b+(j+1)%sides, b+j) for j in range(sides))
        faces += [tuple(reversed(range(sides))), tuple(range(len(verts)-sides, len(verts)))]
        self.part(verts, faces, mat)

    def ring(self, center, normal, radius, tube, mat, sides=20):
        q = Vector(normal).to_track_quat("Z", "Y")
        points = [Vector(center) + q @ Vector((radius*math.cos(i*math.tau/sides),
                                               radius*math.sin(i*math.tau/sides), 0))
                  for i in range(sides+1)]
        self.line(points, tube, mat, 6)

    def profile(self, points, thickness, mat):
        points = list(points)
        area = sum(x0*z1-x1*z0 for (x0,z0),(x1,z1) in zip(points,points[1:]+points[:1]))
        if area < 0:
            points.reverse()
        count = len(points)
        verts = [(x, y, z) for y in [-thickness*0.5, thickness*0.5] for x,z in points]
        faces = [tuple(range(count)), tuple(reversed(range(count,count*2)))]
        faces += [(i,i+count,(i+1)%count+count,(i+1)%count) for i in range(count)]
        self.part(verts, faces, mat)

    def finish(self, parent=None, smooth=False, bevel=0):
        mesh = bpy.data.meshes.new(PREFIX + self.name)
        mesh.from_pydata(self.vertices, [], self.faces)
        mesh.update()
        obj = bpy.data.objects.new(PREFIX + self.name, mesh)
        self.collection.objects.link(obj)
        for mat in self.materials:
            mesh.materials.append(mat)
        for face, idx in zip(mesh.polygons, self.indices):
            face.material_index = idx
            face.use_smooth = smooth
        obj.parent = parent
        if bevel:
            mod = obj.modifiers.new("Soft crafted edges", factory_enum(obj.modifiers, "type", "BEVEL"))
            mod.width, mod.segments = bevel, 2
        return obj


STATIONS = [(-21,0.13), (-20,0.85), (-18,2.65), (-16,3.9), (-12,5.0),
            (-6,5.55), (0,5.65), (6,5.55), (12,5.15), (16,4.7), (20,4.0)]
PORTS = [-14 + 3.25*i for i in range(10)]
ACCESS_HATCH = (2.4, 8.6, 1.4)
GUN_DECK_Y = 4.18
WHEEL_X = 14.2
GALLERY_SPECS = [(12.6,13.15,19.95,20.9,4.2,4.0,6.75,1.95,0.22,6),
                 (15.8,16.0,20.9,21.55,3.74,3.58,8.68,1.58,0.2,4)]


def width(x):
    for (a, wa), (b, wb) in zip(STATIONS, STATIONS[1:]):
        if a <= x <= b:
            return wa + (wb-wa)*(x-a)/(b-a)
    return STATIONS[0][1] if x < -21 else STATIONS[-1][1]


def sheer(x):
    return 0.55*(abs(x)/21)**4 + max(0, x-12)*0.035


def hull_z(x, z):
    rocker = 4.0*(max(0,-x-11)/10)**2 + 1.9*(max(0,x-12)/8)**2
    return z + sheer(x) + rocker * max(0, 1-z/6.45)**2


def side_y(x, z):
    profile = [(0,0.04), (0.6,0.29), (1.3,0.57), (2,0.74),
               (3,0.89), (4,0.98), (5,1.01), (6.5,0.98)]
    for (a, wa), (b, wb) in zip(profile, profile[1:]):
        if a <= z <= b:
            return width(x)*(wa+(wb-wa)*(z-a)/(b-a))
    return width(x)*0.98


def sag(a, b, amount=0.1, steps=9):
    a, b = Vector(a), Vector(b)
    return [a.lerp(b, i/steps) - Vector((0,0,amount*math.sin(math.pi*i/steps)))
            for i in range(steps+1)]


def hull_structure(groups,root,mats):
    structure = Geometry("Keel_Stem_Transom",groups["Hull"])
    structure.line([(x,0,hull_z(x,0.08)) for x,_ in STATIONS],0.18,mats["dark"],8)
    structure.line([(-21,0,hull_z(-21,z)) for z in [0.3,2,4,6.4]],0.22,mats["dark"],8)
    structure.finish(root,bevel=0.03)


def closed_grid(geometry, rows, cols, surface, offset, materials):
    """One connected shell, including the underside and all perimeter edges."""
    top = [surface(i/cols, j/rows) for j in range(rows+1) for i in range(cols+1)]
    count = len(top)
    vertices = top + [p + Vector(offset) for p in top]
    faces, indices = [], []
    for j in range(rows):
        for i in range(cols):
            a = j*(cols+1)+i
            face = (a,a+1,a+cols+2,a+cols+1)
            faces.extend([face,tuple(v+count for v in reversed(face))])
            indices.extend([j % len(materials)]*2)
    boundary = (list(range(cols+1)) + [j*(cols+1)+cols for j in range(1,rows+1)]
                + [rows*(cols+1)+i for i in range(cols-1,-1,-1)]
                + [j*(cols+1) for j in range(rows-1,0,-1)])
    for a,b in zip(boundary,boundary[1:]+boundary[:1]):
        faces.append((b,a,a+count,b+count))
        indices.append(0)
    # Geometry.part records materials per part; remap this shell's bands afterward.
    start = len(geometry.indices)
    geometry.part(vertices,faces,materials[0])
    for mat in materials:
        if mat not in geometry.materials:
            geometry.materials.append(mat)
    geometry.indices[start:] = [geometry.materials.index(materials[i]) for i in indices]


def stern_transom(groups,root,mats):
    shell = Geometry("Stern_Transom_Planking",groups["Hull"])
    def surface(u,v):
        z = 6.45*v
        return Vector((20,(2*u-1)*side_y(20,z),hull_z(20,z)))
    closed_grid(shell,32,12,surface,(-0.18,0,0),mats["wood"])
    shell.finish(root)


def quarterdeck_roofs(groups,root,mats):
    roofs = Geometry("Stepped_Cambered_Quarterdecks",groups["Deck"])
    for spec in GALLERY_SPECS:
        point = gallery_point(spec)
        def surface(u,v,point=point):
            p = point(u,1,1)
            r = 2*v-1
            return Vector((p.x,(p.y+0.14)*r,p.z+0.07+0.16*(1-r*r)))
        closed_grid(roofs,18,12,surface,(0,0,-0.26),mats["deck"])
    roofs.finish(root)


def bow_stem(groups,root,mats):
    bow=Geometry("Bow_Stem",groups["Hull"])
    outline=[(-21.45,7.0),(-21.5,6.3),(-21.45,5.25),(-21.4,4.5),
             (-20.65,3.5),(-19.6,2.5),(-18.25,1.72),(-16.6,0.92),
             (-14.5,0.5),(-12.0,0.05),(-11.9,0.23),(-14.3,0.8),
             (-16.3,1.42),(-18.1,2.3),(-19.4,3.25),(-20.5,4.5),
             (-20.74,5.5),(-20.8,6.5),(-20.85,7.05)]
    bow.profile(outline,0.48,mats["dark"])
    for side in [-1,1]:
        bow.line([(x,side*0.25,z) for x,z in outline[:10]],0.035,mats["wood"][1],6)
    bow.finish(root,bevel=0.04)


def bow_and_rudder(groups,root,mats):
    bow_stem(groups,root,mats)
    stern=Geometry("Sternpost_And_Deadwood",groups["Hull"])
    stern.profile([(17.8,0.55),(20.68,0.65),(20.5,2.5),
                   (20.0,4.2),(19.5,3.35),(18.5,1.7)],0.58,mats["bilge"])
    stern.profile([(20.05,0.65),(20.52,0.65),(21.2,6.75),(20.75,6.75)],0.52,mats["dark"])
    stern.profile([(19.82,2.6),(20.65,2.6),(21.0,6.45),(19.82,6.45)],0.48,mats["wood"][2])
    stern.finish(root,bevel=0.035)

    stock=Geometry("Rudder_Stock",groups["Hull"])
    def axis(z):
        return 20.5+0.115*z
    stock.rod((axis(0.55),0,0.55),(axis(7.1),0,7.1),0.17,mats["dark"],sides=14)
    stock.finish(root,smooth=True)

    blade=Geometry("Rudder_Blade",groups["Hull"])
    blade_outline=[(21.3,6.75),(21.94,6.48),(22.3,5.1),(22.38,3.3),
                   (22.8,0.9),(22.64,0.48),(20.58,0.5),(20.84,2.3),(21.08,4.5)]
    blade.profile(blade_outline,0.34,mats["wood"][2])
    blade.finish(root,bevel=0.035)

    fittings=Geometry("Rudder_Gudgeons_And_Straps",groups["Hull"])
    for z in [1.8,3.8,5.8]:
        intersections=[]
        for (x0,z0),(x1,z1) in zip(blade_outline,blade_outline[1:]+blade_outline[:1]):
            if min(z0,z1)<=z<=max(z0,z1) and abs(z1-z0)>0.0001:
                intersections.append(x0+(x1-x0)*(z-z0)/(z1-z0))
        leading,trailing=min(intersections),max(intersections)
        for y in [-0.182,0.182]:
            fittings.box(((leading+trailing)*0.5,y,z),(trailing-leading,0.025,0.075),mats["metal"])
            fittings.rod((20.0,y,z),(axis(z)+0.06,y,z),0.055,mats["metal"],sides=8)
        fittings.rod((axis(z),0,z-0.13),(axis(z),0,z+0.13),0.215,mats["metal"],sides=12)
    for z in [1.0,2.5,4.8,6.1]:
        for y in [-0.178,0.178]:
            fittings.rod((axis(z)+0.28,y,z),(axis(z)+0.28,y*1.1,z),0.035,mats["metal"],sides=8)
    fittings.finish(root,smooth=True)


def plank_divisions():
    divisions = sorted(set([-21+i*0.8 for i in range(52)] + [-21,20] +
                           [p+d for p in PORTS for d in [-0.7,0.7]]))
    return [x for x in divisions if -21 <= x <= 20]


def hull_planking(groups, root, mats):
    planks = Geometry("Hull_Planking", groups["Hull"])
    divisions = plank_divisions()
    levels = sorted(set([i*0.35 for i in range(19)] + [4.25,5.35,6.45]))
    for side in [-1,1]:
        for j, (z0,z1) in enumerate(zip(levels,levels[1:])):
            for x0,x1 in zip(divisions,divisions[1:]):
                xm, zm = (x0+x1)*0.5, (z0+z1)*0.5
                if 4.25 < zm < 5.35 and any(abs(xm-p)<0.7 for p in PORTS):
                    continue
                a,b = z0,z1
                verts = [(x,side*side_y(x,z),hull_z(x,z))
                         for x,z in [(x0,a),(x1,a),(x1,b),(x0,b)]]
                verts += [(x,y-side*0.11,z) for x,y,z in verts]
                faces = [(0,1,2,3),(7,6,5,4),(0,4,5,1),
                         (1,5,6,2),(2,6,7,3),(3,7,4,0)]
                if side > 0:
                    faces = [tuple(reversed(f)) for f in faces]
                mat = mats["wood"][RNG.randrange(len(mats["wood"]))]
                if zm < 1.3:
                    mat = mats["bilge"]
                if 3.15 < zm < 3.85 or zm > 6:
                    mat = mats["paint"]
                planks.part(verts,faces,mat)
    planks.finish(root)


def deck_board(geometry, x0, x1, ya, yb, elevation, breadth, mat, thickness=0.12):
    outline=[Vector((x0,ya)),Vector((x1,ya)),Vector((x1,yb)),Vector((x0,yb))]
    # Clip the board to both hull sides, retaining triangular pieces near the bow.
    for side in [-1,1]:
        clipped=[]
        for a,b in zip(outline,outline[1:]+outline[:1]):
            da,db=breadth(a.x)-side*a.y,breadth(b.x)-side*b.y
            if da >= 0:
                clipped.append(a)
            if (da >= 0) != (db >= 0):
                clipped.append(a.lerp(b,da/(da-db)))
        outline=clipped
        if len(outline)<3:
            return
    if abs(sum(a.x*b.y-b.x*a.y for a,b in zip(outline,outline[1:]+outline[:1]))) < 1e-8:
        return
    top=[(p.x,p.y,elevation(p.x)) for p in outline]
    n=len(top)
    faces=[tuple(range(n)),tuple(reversed(range(n,n*2)))]
    faces += [(i,i+n,(i+1)%n+n,(i+1)%n) for i in range(n)]
    geometry.part(top+[(x,y,z-thickness) for x,y,z in top],faces,mat)


def main_deck(groups, root, mats):
    deck=Geometry("Main_Deck_Planks",groups["Deck"])
    h0,h1,half=ACCESS_HATCH
    divisions=sorted(set([-21+i*1.6 for i in range(26)]+[20,h0,h1]+[x for x,_ in STATIONS]))
    rows=sorted(set([row*0.45 for row in range(-13,14)]+[-half,half]))
    for row,(ya,yb) in enumerate(zip(rows,rows[1:])):
        for x0,x1 in zip(divisions,divisions[1:]):
            if h0 <= (x0+x1)/2 <= h1 and -half < (ya+yb)/2 < half:
                continue
            deck_board(deck,x0,x1,ya,yb,lambda x:6.35+sheer(x),
                       lambda x:max(0.04,side_y(x,6.35)-0.04),mats["deck"][RNG.randrange(3)])
    deck.finish(root)


def hull(scene, groups, root, mats):
    divisions = plank_divisions()
    hull_planking(groups,root,mats)
    hull_structure(groups,root,mats)
    stern_transom(groups,root,mats)
    bow_and_rudder(groups,root,mats)
    closure=Geometry("Keel_Closure",groups["Hull"])
    for x0,x1 in zip(divisions,divisions[1:]):
        y0,y1=side_y(x0,0.012),side_y(x1,0.012)
        closure.part([(x0,-y0,hull_z(x0,0.012)),(x1,-y1,hull_z(x1,0.012)),
                      (x1,y1,hull_z(x1,0.012)),(x0,y0,hull_z(x0,0.012))],
                     [(3,2,1,0)],mats["bilge"])
    closure.finish(root)
    trim=Geometry("Wales_And_Gold_Trim",groups["Hull"])
    for side in [-1,1]:
        for z,r,mat in [(2.8,0.12,mats["dark"]),(3.75,0.095,mats["gold"]),
                        (4.05,0.09,mats["dark"]),(5.65,0.12,mats["dark"]),
                        (6.02,0.045,mats["gold"]),(6.4,0.13,mats["gold"])]:
            trim.line([(x,side*(side_y(x,z)+0.05),hull_z(x,z)) for x in divisions],r,mat,8)
    trim.finish(root,smooth=True)
    main_deck(groups,root,mats)


def gallery_point(spec):
    def point(u,v,side):
        fore0,fore1,aft0,aft1,wfore,waft,base,height,rise,_=spec
        fore=fore0+(fore1-fore0)*v
        aft=aft0+(aft1-aft0)*v
        return Vector((fore+(aft-fore)*u,
                       side*(wfore+(waft-wfore)*u)*(1-0.065*v),
                       base+height*v+rise*u))
    return point


def cabins_and_rails(groups,root,mats):
    cabin=Geometry("Stern_Gallery",groups["Deck"])
    windows=Geometry("Stern_Gallery_Windows_And_Mouldings",groups["Deck"])
    tiers=[]
    for spec in GALLERY_SPECS:
        point=gallery_point(spec)
        tiers.append(point)
        verts=[point(u,v,side) for v in [0,1] for u,side in [(0,-1),(1,-1),(1,1),(0,1)]]
        cabin.part(verts,[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),
                         (2,3,7,6),(3,0,4,7)],mats["paint"])

        for side in [-1,1]:
            offset=Vector((0,side*0.035,0))
            count=spec[-1]
            for i in range(count):
                u0=0.065+i*(0.88/count)
                u1=u0+0.88/count-0.025
                v0,v1=0.22,0.76
                corners=[point(u,v,side)+offset for u,v in [(u0,v0),(u1,v0),(u1,v1),(u0,v1)]]
                face=(0,1,2,3) if side<0 else (3,2,1,0)
                windows.part(corners,[face],mats["glass"])
                for u in [u0,(u0+u1)*0.5,u1]:
                    windows.rod(point(u,v0-0.04,side)+offset,
                                point(u,v1+0.04,side)+offset,0.038,mats["gold"],sides=6)
                for v in [v0,(v0+v1)*0.5,v1]:
                    windows.rod(point(u0,v,side)+offset,point(u1,v,side)+offset,
                                0.033,mats["gold"],sides=6)
            for v,r,mat in [(0.02,0.09,mats["dark"]),(0.13,0.07,mats["gold"]),
                            (0.82,0.065,mats["gold"]),(0.94,0.09,mats["dark"]),
                            (1,0.06,mats["gold"])]:
                windows.line([point(u/12,v,side)+offset for u in range(13)],r,mat,8)
            for u in [0.015,0.985]:
                windows.rod(point(u,0.1,side)+offset,point(u,0.96,side)+offset,
                            0.065,mats["gold"],sides=8)

        def rear(r,v,point=point):
            p=point(1,v,1)
            return Vector((p.x+0.035,p.y*r,p.z))
        count=7 if spec[-1]==6 else 6
        for i in range(count):
            r0=-0.88+i*1.76/count
            r1=r0+1.76/count-0.04
            windows.part([rear(r,v) for r,v in [(r0,0.22),(r1,0.22),(r1,0.76),(r0,0.76)]],
                         [(0,1,2,3)],mats["glass"])
            for r in [r0,(r0+r1)*0.5,r1]:
                windows.rod(rear(r,0.18),rear(r,0.8),0.038,mats["gold"],sides=6)
            for v in [0.22,0.49,0.76]:
                windows.rod(rear(r0,v),rear(r1,v),0.033,mats["gold"],sides=6)
        for v,r,mat in [(0.02,0.09,mats["dark"]),(0.13,0.065,mats["gold"]),
                        (0.82,0.065,mats["gold"]),(0.94,0.09,mats["dark"]),
                        (1,0.065,mats["gold"])]:
            windows.line([rear(-1+i/12*2,v) for i in range(13)],r,mat,8)

        # The roof rises towards the stern and crowns gently across the beam.
        def roof(u,r,point=point):
            p=point(u,1,1)
            return Vector((p.x,(p.y+0.14)*r,p.z+0.07+0.16*(1-r*r)))
        for side in [-1,1]:
            windows.line([roof(i/12,side) for i in range(13)],0.1,mats["dark"],8)
        for u in [0,1]:
            windows.line([roof(u,-1+i/12*2) for i in range(13)],0.1,mats["dark"],8)

    cabin.finish(root,bevel=0.025)
    windows.finish(root,smooth=True)
    quarterdeck_roofs(groups,root,mats)
    railings(groups,root,mats,tiers)


def railings(groups,root,mats,tiers=None):
    tiers=tiers or [gallery_point(spec) for spec in GALLERY_SPECS]
    rails=Geometry("Bulwarks_And_Railings",groups["Deck"])
    for side in [-1,1]:
        pts=[]
        for i in range(36):
            x=-19.5+i*0.92
            z=6.6+sheer(x)
            pts.append((x,side*(width(x)*0.97),z))
            rails.box((x,side*width(x)*0.97,z+0.35),(0.11,0.15,0.8),mats["dark"])
        rails.line([(x,y,z+0.74) for x,y,z in pts],0.115,mats["dark"],8)
        rails.line([(x,y,z+0.39) for x,y,z in pts],0.055,mats["gold"])
    for level,point in enumerate(tiers):
        end=0.34 if level==0 else 1
        for side in [-1,1]:
            basepoints=[]
            for i in range(9):
                p=point(i/8*end,1,side)+Vector((0,side*0.12,0.12))
                basepoints.append(p)
                rails.rod(p,p+Vector((0,0,0.74)),0.045,mats["gold"],sides=8)
            rails.line([p+Vector((0,0,0.75)) for p in basepoints],0.075,mats["dark"],8)
        for u in ([0] if level==0 else [0,1]):
            p=point(u,1,1)
            half=p.y+0.12
            intervals=[(-half,half)]
            if u==0:
                # Leave the existing deck-access routes clear of decorative rails.
                gap=(-1.8,1.8) if level==0 else (-2.85,-0.75)
                intervals=[(-half,gap[0]),(gap[1],half)]
            for ya,yb in intervals:
                pts=[Vector((p.x,ya+(yb-ya)*i/8,p.z+0.12)) for i in range(9)]
                for a in pts:
                    rails.rod(a,a+Vector((0,0,0.74)),0.045,mats["gold"],sides=8)
                rails.line([a+Vector((0,0,0.75)) for a in pts],0.075,mats["dark"],8)
    rails.finish(root,smooth=True)


def cannons(groups,root,mats):
    frames=Geometry("Gunport_Frames_And_Lids",groups["Hull"])
    for side in [-1,1]:
        for index,x in enumerate(PORTS):
            y=side*side_y(x,4.8)
            z=4.8+sheer(x)
            frames.box((x,y-side*0.26,z),(1.36,0.04,1.05),mats["void"])
            for dx in [-0.73,0.73]:
                frames.box((x+dx,y,z),(0.09,0.2,1.2),mats["gold"])
            for dz in [-0.58,0.58]:
                frames.box((x,y,z+dz),(1.55,0.2,0.09),mats["dark"])
            # Open lids lean out from their hinges above each port.
            hinge=Vector((x,y,z+0.62))
            verts=[hinge+Vector((dx,dy,dz)) for dx,dy,dz in
                   [(-0.66,0,0),(0.66,0,0),(0.66,side*0.68,0.6),(-0.66,side*0.68,0.6)]]
            frames.part(verts,[(0,1,2,3)],mats["wood"][1])
            for dx in [-0.43,0.43]:
                frames.rod((x+dx,y,z+0.62),(x+dx,y+side*0.68,z+1.22),0.035,mats["metal"],sides=6)
            gun=Geometry(f"Cannon_{'Port' if side<0 else 'Starboard'}_{index+1:02d}",groups["Deck"])
            gun.box((x,y-side*0.75,z-0.4),(0.85,1.3,0.28),mats["dark"])
            gun.rod((x,y-side*1.2,z),(x,y+side*0.95,z+0.06),0.26,mats["metal"],0.17,12)
            for dy,r in [(-0.6,0.29),(0.13,0.24),(0.88,0.195)]:
                gun.rod((x,y+side*dy,z+0.02),(x,y+side*(dy+0.08),z+0.02),r,mats["metal"],sides=12)
            gun.rod((x,y+side*0.955,z+0.06),(x,y+side*0.965,z+0.06),0.127,mats["void"],sides=12)
            for dx in [-0.52,0.52]:
                for dy in [-1.0,-0.2]:
                    gun.rod((x+dx-0.08,y+side*dy,z-0.46),(x+dx+0.08,y+side*dy,z-0.46),
                            0.25,mats["deck"][0],sides=12)
            gun.finish(root,smooth=True)
    frames.finish(root)


def deck_fittings(groups,root,mats):
    detail=Geometry("Deck_Fittings",groups["Deck"])
    for x in [-3.7]:
        detail.box((x,0,6.66),(2.7,3.1,0.35),mats["dark"])
        detail.box((x,0,6.85),(2.35,2.75,0.05),mats["void"])
        for i in range(11):
            detail.box((x-1.1+i*0.22,0,6.91),(0.065,2.75,0.07),mats["deck"][1])
        for i in range(12):
            detail.box((x,-1.3+i*0.235,6.93),(2.35,0.065,0.07),mats["deck"][0])
    detail.rod((-15,0,6.45),(-15,0,7.65),0.45,mats["dark"],sides=16)
    detail.rod((-15,0,7.5),(-15,0,7.7),0.65,mats["gold"],sides=16)
    for angle in [i*math.tau/8 for i in range(8)]:
        detail.rod((-15,0,7.55),(-15+1.55*math.cos(angle),1.55*math.sin(angle),7.55),0.065,mats["deck"][1])
    for side in [-1,1]:
        for x in [-17,-11,-5,2,8]:
            y=side*(width(x)-0.65)
            for dx in [-0.28,0.28]:
                detail.rod((x+dx,y,6.55+sheer(x)),(x+dx,y,7.15+sheer(x)),0.13,mats["dark"],sides=8)
            detail.rod((x-0.55,y,7.05+sheer(x)),(x+0.55,y,7.05+sheer(x)),0.1,mats["dark"])
    # Barrels have hoops and a gently bulging stave profile.
    for k,(x,y) in enumerate([(-6,3.8),(-5,3.7),(7,-3.7),(8,-3.55)]):
        z=6.4+sheer(x)
        for dz0,dz1,r0,r1 in [(0,0.25,0.36,0.45),(0.25,0.65,0.45,0.48),
                             (0.65,1.0,0.48,0.42),(1,1.12,0.42,0.36)]:
            detail.rod((x,y,z+dz0),(x,y,z+dz1),r0,mats["wood"][k%4],r1,12)
        for dz,r in [(0.2,0.44),(0.55,0.49),(0.98,0.435)]:
            detail.ring((x,y,z+dz),(0,0,1),r,0.035,mats["metal"],16)
    detail.finish(root,smooth=True)
    anchors=Geometry("Anchors_And_Bow_Headrails",groups["Hull"])
    for side in [-1,1]:
        x,y,z=-18,side*3.35,4.0
        anchors.rod((x,y,z+1.35),(x+0.35,y,z-0.8),0.11,mats["metal"])
        anchors.rod((x-0.8,y,z+0.55),(x+0.9,y,z+0.55),0.12,mats["dark"])
        anchors.ring((x,y,z+1.5),(0,1,0),0.22,0.065,mats["metal"])
        anchors.line([(x-1,y,z-0.1),(x-0.7,y,z-0.7),(x+0.35,y,z-0.9),
                      (x+1.2,y,z-0.5),(x+1.35,y,z)],0.13,mats["metal"],8)
        anchors.line([(-21,side*0.35,6.7),(-22.2,side*1.3,7.15),
                      (-21,side*2.1,7.25),(-18,side*3.0,7.55)],0.12,mats["gold"],8)
        anchors.line([(-21.1,side*0.2,5.9),(-22.0,side*0.7,6.2),
                      (-20.2,side*1.9,6.8),(-18,side*3.0,7.0)],0.09,mats["dark"],8)
    anchors.finish(root,smooth=True)


def ship_wheel(groups,root,mats):
    support=Geometry("Wheel_Pedestal",groups["Deck"])
    x=WHEEL_X
    # The pedestal is forward of the wheel; the helmsman stands aft facing the bow.
    support.box((x-0.32,0,9.05),(0.55,0.72,0.14),mats["dark"])
    support.box((x-0.32,0,9.4),(0.24,0.26,0.68),mats["wood"][1])
    support.rod((x-0.39,0,9.65),(x+0.08,0,9.65),0.14,mats["gold"],sides=12)
    support.finish(root,bevel=0.015)
    wheel=Geometry("Ship_Wheel",groups["Deck"])
    wheel.ring((x,0,9.65),(1,0,0),0.73,0.075,mats["deck"][0],32)
    wheel.ring((x+0.065,0,9.65),(1,0,0),0.71,0.018,mats["gold"],32)
    wheel.rod((x-0.07,0,9.65),(x+0.15,0,9.65),0.17,mats["gold"],sides=16)
    for angle in [i*math.tau/10 for i in range(10)]:
        y,z=math.cos(angle),math.sin(angle)
        wheel.rod((x,0,9.65),(x,0.85*y,9.65+0.85*z),0.045,mats["deck"][0],sides=8)
        wheel.rod((x,0.85*y,9.65+0.85*z),(x+0.15,0.9*y,9.65+0.9*z),
                  0.06,mats["wood"][1],end_radius=0.045,sides=8)
    wheel.finish(root,smooth=True)


def below_deck(groups,root,mats):
    floor=Geometry("Gun_Deck_Floor",groups["Deck"])
    divisions=sorted(set([-16+i*0.8 for i in range(36)]+[-16,12]+[x for x,_ in STATIONS if -16<x<12]))
    for row in range(-13,13):
        for x0,x1 in zip(divisions,divisions[1:]):
            deck_board(floor,x0,x1,row*0.45,(row+1)*0.45,lambda x:GUN_DECK_Y+sheer(x),
                       lambda x:side_y(x,GUN_DECK_Y)-0.16,mats["deck"][row%3],0.1)
    floor.finish(root)
    beams=Geometry("Interior_Frames_And_Beams",groups["Deck"])
    for x in [-14,-10,-6,-2,1,10]:
        low=GUN_DECK_Y+sheer(x)
        ceiling=6.2+sheer(x)
        y=side_y(x,GUN_DECK_Y)-0.28
        beams.box((x,0,ceiling-0.06),(0.18,2*y,0.12),mats["dark"])
        for side in [-1,1]:
            beams.box((x,side*y,(low+ceiling)/2),(0.19,0.18,ceiling-low),mats["wood"][2])
            beams.line([(x,side*y,ceiling-0.4),(x,side*(y-0.3),ceiling-0.1),
                        (x,side*(y-0.65),ceiling-0.1)],0.07,mats["dark"],6)
    for x in [-10.3,1,11.3]:
        floor_y=GUN_DECK_Y+sheer(x)
        beams.rod((x,0,floor_y),(x,0,6.38+sheer(x)),0.28,mats["mast"],sides=14)
        beams.ring((x,0,floor_y+0.1),(0,0,1),0.31,0.04,mats["metal"],16)
    beams.finish(root)
    walls=Geometry("Interior_Bulkheads",groups["Deck"])
    for x in [-16,12]:
        half=side_y(x,GUN_DECK_Y)-0.16
        for j in range(20):
            ya,yb=-half+j*half/10,-half+(j+1)*half/10
            walls.box((x,(ya+yb)/2,5.22+sheer(x)),(0.12,yb-ya,2.08),mats["wood"][j%4])
    walls.finish(root)
    access=Geometry("Open_Hatch_Coaming",groups["Deck"])
    h0,h1,half=ACCESS_HATCH
    for side in [-1,1]:
        y=side*(half+0.055)
        access.box(((h0+h1)/2,y,6.37),(h1-h0,0.11,0.18),mats["dark"])
        for x in [h0,h0+2,h1-2,h1]:
            top=6.35+sheer(x)
            access.rod((x,y,top),(x,y,top+0.8),0.042,mats["gold"],sides=8)
        access.line([(x,y,7.15+sheer(x)) for x in [h0,h1]],0.06,mats["dark"],8)
    access.box((h0-0.05,0,6.4),(0.1,2*half+0.22,0.18),mats["dark"])
    access.rod((h0,-half,7.15),(h0,half,7.15),0.06,mats["dark"])
    access.finish(root)
    stairs=Geometry("Companionway_Stairs",groups["Deck"])
    x0,x1=3.0,h1
    y0,y1=GUN_DECK_Y+sheer(x0),6.35+sheer(x1)
    for i in range(14):
        a,b=x0+(x1-x0)*i/14,x0+(x1-x0)*(i+1)/14
        top=y0+(y1-y0)*(i+1)/14
        stairs.box(((a+b)/2,0,top-0.055),(b-a+0.002,1.8,0.11),mats["deck"][i%3])
        stairs.box((a,0,top-(y1-y0)/28),(0.08,1.8,(y1-y0)/14),mats["wood"][1])
    for side in [-1,1]:
        stairs.rod((x0,side*0.83,y0-0.1),(x1,side*0.83,y1-0.1),0.09,mats["dark"],sides=8)
        for t in [0,0.25,0.5,0.75,1]:
            x=x0+(x1-x0)*t
            z=y0+(y1-y0)*t
            stairs.rod((x,side*1.04,z),(x,side*1.04,z+0.75),0.035,mats["gold"],sides=6)
        stairs.rod((x0,side*1.04,y0+0.75),(x1,side*1.04,y1+0.75),0.055,mats["dark"],sides=8)
    stairs.finish(root)
    cargo=Geometry("Interior_Cargo_And_Berths",groups["Deck"])
    for x in [-5,9]:
        for side in [-1,1]:
            y=side*3.1
            top=GUN_DECK_Y+sheer(x)
            cargo.box((x,y,top+0.43),(1.4,0.95,0.86),mats["wood"][1])
            for dz in [0.18,0.68]:
                cargo.box((x,y,top+dz),(1.44,0.99,0.06),mats["dark"])
            for dx in [-0.5,0.5]:
                cargo.box((x+dx,y,top+0.43),(0.07,1,0.86),mats["metal"])
    for side in [-1,1]:
        cargo.box((-12.1,side*2.4,4.83),(2.1,0.9,0.12),mats["dark"])
        cargo.box((-12.1,side*2.4,4.94),(1.95,0.81,0.14),mats["canvas"])
        for x in [-12.95,-11.25]:
            for y in [side*1.97,side*2.83]:
                cargo.box((x,y,4.51),(0.09,0.09,0.58),mats["wood"][2])
    cargo.finish(root)
    lanterns=Geometry("Interior_Lanterns",groups["Deck"])
    for x in [-12,-4,10]:
        for side in [-1,1]:
            y=side*2.9
            z=5.8+sheer(x)
            lanterns.box((x,y,z),(0.2,0.2,0.27),mats.get("lamp",mats["glass"]))
            for dz in [-0.15,0.15]:
                lanterns.box((x,y,z+dz),(0.25,0.25,0.04),mats["gold"])
            for dx in [-0.105,0.105]:
                for dy in [-0.105,0.105]:
                    lanterns.rod((x+dx,y+dy,z-0.14),(x+dx,y+dy,z+0.14),0.016,mats["gold"],sides=6)
            lanterns.rod((x,y,z+0.17),(x,y,6.22+sheer(x)),0.018,mats["metal"],sides=6)
    lanterns.finish(root)
    access=Geometry("Deck_Access_Stairs",groups["Deck"])
    for x0,x1,z0,z1,y,breadth,count in [(10,13.1,6.45,8.97,0,3.6,14),(14,16.1,9,10.53,-1.8,2.1,9)]:
        for i in range(count):
            a,b=x0+(x1-x0)*i/count,x0+(x1-x0)*(i+1)/count
            top=z0+(z1-z0)*(i+1)/count
            access.box(((a+b)/2,y,top-0.055),(b-a+0.002,breadth,0.11),mats["deck"][i%3])
            access.box((a,y,top-(z1-z0)/count/2),(0.06,breadth,(z1-z0)/count),mats["wood"][1])
        for side in [-1,1]:
            access.rod((x0,y+side*(breadth/2+0.04),z0),(x1,y+side*(breadth/2+0.04),z1),
                       0.06,mats["dark"],sides=6)
    access.finish(root)


def square_sail(groups,root,mats,label,x,ztop,w,h,yaw):
    axis=Vector((-math.sin(yaw),math.cos(yaw),0))
    normal=Vector((-math.cos(yaw),-math.sin(yaw),0))
    def point(u,v):
        breadth=w*(1-0.17*v)
        bulge=1.8*math.sin(math.pi*u)*math.sin(math.pi*v)
        flutter=0.08*math.sin(u*math.tau*7+v*3)*math.sin(math.pi*v)
        p=Vector((x-0.19,0,ztop-v*h+0.55*v*(1-(2*u-1)**2)))
        return p+axis*((u-0.5)*breadth)+normal*(bulge+flutter)
    sail=Geometry(label,groups["Sails"])
    nu,nv=28,18
    verts=[point(i/nu,j/nv) for j in range(nv+1) for i in range(nu+1)]
    faces=[(j*(nu+1)+i,j*(nu+1)+i+1,(j+1)*(nu+1)+i+1,(j+1)*(nu+1)+i)
           for j in range(nv) for i in range(nu)]
    sail.part(verts,faces,mats["canvas"])
    obj=sail.finish(root,smooth=True)
    solid=obj.modifiers.new("Canvas thickness",factory_enum(obj.modifiers,"type","SOLIDIFY"))
    solid.thickness=0.018
    seams=Geometry(label+"_Boltropes_And_Seams",groups["Sails"])
    for fixed,vertical in [(0,True),(1,True),(0,False),(1,False)]:
        pts=[point(fixed,t/32) if vertical else point(t/32,fixed) for t in range(33)]
        seams.line(pts,0.035,mats["rope"],6)
    for i in range(1,14):
        seams.line([point(i/14,j/18)+normal*0.012 for j in range(19)],0.009,mats["seam"],4)
    for v in [0.38,0.7]:
        seams.line([point(i/28,v)+normal*0.015 for i in range(29)],0.012,mats["seam"],4)
        for u in [0.12+i*0.095 for i in range(9)]:
            p=point(u,v)
            seams.line([p,p+Vector((0,-0.03,-0.28))],0.015,mats["rope"],5)
    seams.finish(root)
    return point,axis


def triangular_sail(groups,root,mats,label,corners,bulge=0.8):
    a,b,c=map(Vector,corners)
    normal=(b-a).cross(c-a).normalized()
    if normal.y>0:
        normal=-normal
    def point(u,v):
        t=1-u-v
        return a*t+b*u+c*v+normal*(27*bulge*u*v*t)
    n=24
    verts,lookup=[],{}
    for j in range(n+1):
        for i in range(n-j+1):
            lookup[i,j]=len(verts)
            verts.append(point(i/n,j/n))
    faces=[]
    for j in range(n):
        for i in range(n-j):
            faces.append((lookup[i,j],lookup[i+1,j],lookup[i,j+1]))
            if i<n-j-1:
                faces.append((lookup[i+1,j],lookup[i+1,j+1],lookup[i,j+1]))
    sail=Geometry(label,groups["Sails"])
    sail.part(verts,faces,mats["canvas"])
    obj=sail.finish(root,smooth=True)
    mod=obj.modifiers.new("Canvas thickness",factory_enum(obj.modifiers,"type","SOLIDIFY"))
    mod.thickness=0.016
    seam=Geometry(label+"_Boltropes_And_Seams",groups["Sails"])
    for p,q in [(a,b),(b,c),(c,a)]:
        seam.line([p.lerp(q,i/24) for i in range(25)],0.035,mats["rope"],6)
    for j in range(1,11):
        v=j/12
        seam.line([point((1-v)*i/20,v)+normal*0.012 for i in range(21)],0.01,mats["seam"],4)
    seam.finish(root)


def rig(groups,root,mats):
    masts=[("Foremast",-10.3,32.0,[(15.8,12,6.5),(23.3,10,5.4),(29.2,7.3,3.9)]),
           ("Mainmast",1.0,36.0,[(17.2,14.3,7.5),(26,11.6,6.7),(33.1,8.2,4.9)]),
           ("Mizzenmast",11.3,27.5,[(18.7,8.0,5.2),(24.6,6.0,3.6)])]
    all_yards=[]
    for name,x,top,sails in masts:
        spar=Geometry(name+"_Spars_And_Tops",groups["Masts"])
        base=6.45+sheer(x)
        lower=top*0.52
        spar.rod((x,0,base),(x,0,lower+1),0.39,mats["mast"],0.26,14)
        spar.rod((x,0,lower),(x,0,top*0.8),0.255,mats["mast"],0.145,12)
        spar.rod((x,0,top*0.79),(x,0,top+1),0.15,mats["mast"],0.055,10)
        for z in [base+0.2,base+1,lower-0.5,lower,lower+0.5,top*0.8,top*0.8+0.5]:
            radius=0.405 if z<lower else 0.265 if z<top*0.8 else 0.16
            spar.rod((x,0,z),(x,0,z+0.1),radius,mats["metal"],sides=14)
        for z,r in [(lower,1.3),(top*0.8,0.8)]:
            spar.rod((x,0,z),(x,0,z+0.17),r,mats["dark"],sides=16)
            spar.ring((x,0,z+0.7),(0,0,1),r*0.94,0.035,mats["rope"])
            for i in range(12):
                a=i*math.tau/12
                p=(x+r*0.94*math.cos(a),r*0.94*math.sin(a))
                spar.rod((*p,z+0.15),(*p,z+0.7),0.025,mats["dark"],sides=6)
        rigging=Geometry(name+"_Shrouds_Ratlines_And_Running_Rig",groups["Rigging"])
        for side in [-1,1]:
            # Fan-shaped shrouds and the horizontal rope ladder rungs.
            feet=[Vector((x-1.3+i*0.62,side*(width(x)+0.35),base+0.3)) for i in range(6)]
            heads=[Vector((x-0.23+i*0.085,side*0.25,lower+0.2)) for i in range(6)]
            spar.box((x+0.25,side*(width(x)+0.1),base+0.18),(4.5,0.72,0.18),mats["dark"])
            for foot,head in zip(feet,heads):
                rigging.line(sag(foot,head,0.035),0.04,mats["standing"])
                rigging.ring(foot+Vector((0,0,0.25)),(0,1,0),0.15,0.035,mats["dark"],12)
            for i in range(1,30):
                t=i/31
                rigging.line([feet[0].lerp(heads[0],t),feet[-1].lerp(heads[-1],t)],0.018,mats["rope"],5)
            for i in range(3):
                foot=Vector((x-0.7+i*0.65,side*1.15,lower+0.2))
                head=Vector((x-0.16+i*0.16,side*0.12,top*0.8+0.2))
                rigging.line(sag(foot,head,0.025),0.026,mats["standing"])
            for i in range(1,20):
                t=i/21
                rigging.line([Vector((x-0.7,side*1.15,lower+0.2)).lerp(Vector((x-0.16,side*0.12,top*0.8+0.2)),t),
                              Vector((x+0.6,side*1.15,lower+0.2)).lerp(Vector((x+0.16,side*0.12,top*0.8+0.2)),t)],
                             0.014,mats["rope"],4)
            rigging.line(sag((x,0,top),(min(19,x+6),side*width(min(19,x+6))*0.94,7.1+sheer(min(19,x+6))),0.13),
                         0.031,mats["standing"])
        for level,(ztop,w,h) in enumerate(sails):
            yaw=math.radians(31-level*3)
            point,axis=square_sail(groups,root,mats,f"{name}_Sail_{level+1}",x,ztop,w,h,yaw)
            left=Vector((x,0,ztop))+axis*(-w*0.57)
            right=Vector((x,0,ztop))+axis*(w*0.57)
            spar.rod(left,right,0.13 if level==0 else 0.1,mats["mast"],sides=12)
            for p in [left,right]:
                rigging.line(sag(p,(x,0,min(top+0.3,ztop+4)),0.06),0.024,mats["rope"])
                side=1 if p.y>0 else -1
                rigging.line(sag(p,(min(19,x+6),side*width(min(19,x+6))*0.85,base+0.7),0.18),0.022,mats["rope"])
            for u in [0,1]:
                p=point(u,1)
                side=1 if p.y>0 else -1
                rigging.line(sag(p,(x+1.4,side*width(x)*0.85,base+0.7),0.16),0.025,mats["rope"])
            all_yards.append((x,ztop,w))
        spar.finish(root,smooth=True)
        rigging.finish(root)
    bow=Geometry("Bowsprit_And_Booms",groups["Masts"])
    bow.rod((-18,0,6.6),(-29,0,11),0.34,mats["mast"],0.18,14)
    bow.rod((-26,0,9.8),(-33,0,12.5),0.17,mats["mast"],0.065,12)
    for t in [i/9 for i in range(10)]:
        p=Vector((-18,0,6.6)).lerp(Vector((-29,0,11)),t)
        bow.ring(p,(-11,0,4.4),0.35-0.15*t,0.025,mats["rope"],12)
    bow.rod((11.3,0,11.8),(21,0,13.7),0.14,mats["mast"],0.075,12)
    bow.rod((11.3,0,23),(17.5,0,26.6),0.11,mats["mast"],0.055,10)
    bow.finish(root,smooth=True)
    stays=Geometry("Forestays_And_Connecting_Stays",groups["Rigging"])
    for p,z in [((-33,0,12.5),31.8),((-29,0,11),25.7),((-25,0,9.3),20.8)]:
        stays.line(sag(p,(-10.3,0,z),0.05),0.035,mats["standing"])
    for a,b in [((-10.3,0,32),(1,0,36)),((-10.3,0,25),(1,0,29)),
                ((1,0,36),(11.3,0,27.5)),((1,0,28),(11.3,0,21)),
                ((-32,0,12),(-20,0,2.3))]:
        stays.line(sag(a,b,0.12),0.038,mats["standing"])
    for side in [-1,1]:
        for x in [-26,-30,-33]:
            stays.line(sag((x,0,10.5+(abs(x)-26)*0.28),(-18,side*3.3,6.2),0.12),0.034,mats["standing"])
    stays.finish(root)
    triangular_sail(groups,root,mats,"Flying_Jib",[(-32,0,12.3),(-10.7,0,31.4),(-17.5,0,13.5)],1.0)
    triangular_sail(groups,root,mats,"Inner_Jib",[(-26.8,0,10.5),(-10.65,0,24.6),(-13,0,11.4)],0.85)
    triangular_sail(groups,root,mats,"Mizzen_Gaff_Sail",[(11.5,0,12),(11.5,0,23.1),(20.5,0,13.7)],0.8)
    flag=Geometry("Mainmast_Pennant",groups["Sails"])
    verts=[]
    for j in range(2):
        for i in range(17):
            u=i/16
            verts.append((1+u*4.3,-0.13+0.3*math.sin(u*math.tau*1.25),
                          36.6-j*(0.65*(1-u)+0.05)+0.18*math.sin(u*math.tau)))
    flag.part(verts,[(i,i+1,i+18,i+17) for i in range(16)],mats["paint"])
    flag.finish(root,smooth=True)


def staging(scene,groups,root,mats):
    stage=Geometry("Studio_Ground",groups["Studio"])
    stage.box((0,0,-0.4),(400,400,0.2),mats["ground"])
    stage.finish()
    world=bpy.data.worlds.new(PREFIX+"Studio_World")
    world.use_nodes=True
    bg=next(n for n in world.node_tree.nodes if n.type=="BACKGROUND")
    bg.inputs[0].default_value=(0.72,0.77,0.8,1)
    bg.inputs[1].default_value=0.45
    scene.world=world
    lights=[("Key",(-35,-42,60),75000,30,(1.0,0.89,0.72)),
            ("Fill",(15,-12,35),55000,25,(0.78,0.89,1.0)),
            ("Rim",(12,35,48),90000,26,(1.0,0.97,0.85))]
    for name,pos,power,size,color in lights:
        data=bpy.data.lights.new(PREFIX+name,factory_enum(bpy.data.lights,"type","AREA"))
        data.energy,data.size,data.color=power,size,color
        obj=bpy.data.objects.new(PREFIX+name,data)
        groups["Studio"].objects.link(obj)
        obj.location=pos
        obj.rotation_euler=(Vector((-3,0,14))-obj.location).to_track_quat("-Z","Y").to_euler()
    target=Vector((-4.5,0,17.0))
    cameras=[("Presentation",(-62,-95,46),68),
             ("Profile",(-4.5,-110,25),65),
             ("Deck_Detail",(40,-50,37),53),
             ("Bow_Detail",(-35,-32,16),16),
             ("Stern_Detail",(36,-32,20),18)]
    for name,pos,scale in cameras:
        data=bpy.data.cameras.new(PREFIX+name)
        data.type=enum_id(data,"type","ORTHO")
        data.ortho_scale=scale
        obj=bpy.data.objects.new(PREFIX+name,data)
        groups["Studio"].objects.link(obj)
        obj.location=pos
        focus={"Deck_Detail":Vector((6,0,13)),"Bow_Detail":Vector((-19.5,0,4.4)),
               "Stern_Detail":Vector((19.2,0,6.2))}.get(name,target)
        obj.rotation_euler=(focus-obj.location).to_track_quat("-Z","Y").to_euler()
    scene.camera=bpy.data.objects[PREFIX+"Presentation"]
    scene.render.resolution_x,scene.render.resolution_y=1600,1200
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format=enum_id(scene.render.image_settings,"file_format","PNG")
    scene.render.filepath=str(OUTPUT/"reference_frigate_preview.png")
    scene.render.film_transparent=False
    try:
        scene.render.engine="BLENDER_EEVEE"
    except TypeError as exc:
        raise RuntimeError(f"EEVEE is needed for the preview: {exc}") from exc
    transforms=[i.identifier for i in scene.view_settings.bl_rna.properties["view_transform"].enum_items]
    if "AgX" in transforms:
        scene.view_settings.view_transform="AgX"
    scene.view_settings.exposure=0.65
    if hasattr(scene,"eevee") and hasattr(scene.eevee,"taa_render_samples"):
        scene.eevee.taa_render_samples=48
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=="VIEW_3D":
                space=area.spaces.active
                space.clip_end=1000
                space.region_3d.view_distance=78
                space.region_3d.view_location=target
                space.region_3d.view_rotation=scene.camera.rotation_euler.to_quaternion()
                space.overlay.show_floor=False
                space.overlay.show_axis_x=False
                space.overlay.show_axis_y=False
                space.shading.type=enum_id(space.shading,"type","MATERIAL")


def interior_staging(groups):
    for x in [-12,-4,10]:
        for side in [-1,1]:
            name=f"Frigate_Interior_Light_{x}_{side}"
            obj=bpy.data.objects.get(name)
            if obj is None:
                data=bpy.data.lights.new(name,factory_enum(bpy.data.lights,"type","POINT"))
                obj=bpy.data.objects.new(name,data)
                groups["Studio"].objects.link(obj)
            obj.location=(x,side*2.9,5.8+sheer(x))
            obj.data.energy,obj.data.color,obj.data.shadow_soft_size=180,(1,0.76,0.43),0.12
    for name,position,target,scale in [
        ("Interior_Detail",(-14,-1.25,5.65),(7,0.6,5.22),None),
        ("Wheel_Detail",(15.65,-0.6,10.55),(WHEEL_X,0,9.65),None),
        ("Hatch_Detail",(12,-11,17),(5,0,6),16),
        ("Hull_Joins_Detail",(-8,-18,4.7),(-8,0,3.4),9),
    ]:
        obj=bpy.data.objects.get("Frigate_"+name)
        if obj is None:
            data=bpy.data.cameras.new("Frigate_"+name)
            obj=bpy.data.objects.new("Frigate_"+name,data)
            groups["Studio"].objects.link(obj)
        obj.data.type=enum_id(obj.data,"type","ORTHO" if scale else "PERSP")
        if scale:
            obj.data.ortho_scale=scale
        else:
            obj.data.lens=20
        obj.location=position
        obj.rotation_euler=(Vector(target)-obj.location).to_track_quat("-Z","Y").to_euler()


def build():
    if bpy.data.scenes.get(SCENE_NAME):
        raise RuntimeError("Reference Frigate already exists; keep the existing model intact.")
    OUTPUT.mkdir(parents=True,exist_ok=True)
    scene=bpy.data.scenes.new(SCENE_NAME)
    bpy.context.window.scene=scene
    scene.unit_settings.system=enum_id(scene.unit_settings,"system","METRIC")
    groups={}
    for name in ["Hull","Deck","Masts","Sails","Rigging","Studio"]:
        coll=bpy.data.collections.new(PREFIX+name)
        scene.collection.children.link(coll)
        groups[name]=coll
    root=bpy.data.objects.new("Reference_Frigate",None)
    groups["Hull"].objects.link(root)
    root["reference"]="Supplied sailing-ship sheet; large three-masted ship at upper centre"
    root["notes"]="Original modeled interpretation; bow is -X; z=0 at keel; metres"
    root["export_notes"]="Editable procedural materials in .blend; base colors in GLB/FBX"
    mats={
        "wood":[material(f"Oak_{i+1}",c,grain=(0.4,30,18)) for i,c in enumerate(
            [(0.3,0.16,0.07),(0.38,0.22,0.11),(0.26,0.13,0.055),(0.43,0.27,0.14)])],
        "deck":[material(f"Deck_{i+1}",c,grain=(0.5,35,10)) for i,c in enumerate(
            [(0.49,0.34,0.19),(0.57,0.42,0.25),(0.43,0.29,0.15)])],
        "bilge":material("Weathered_Underwater_Oak",(0.16,0.085,0.042),grain=(0.4,22,15)),
        "dark":material("Tarred_Timber",(0.045,0.033,0.025),grain=(0.4,25,12)),
        "paint":material("Aged_Green_Paint",(0.075,0.16,0.135),grain=(0.5,30,15)),
        "gold":material("Aged_Brass",(0.55,0.35,0.11),0.4,0.65),
        "metal":material("Dark_Iron",(0.07,0.085,0.09),0.38,0.8),
        "void":material("Gunport_Interior",(0.009,0.008,0.006),0.95),
        "mast":material("Spar_Pine",(0.3,0.185,0.083),grain=(22,22,0.35)),
        "canvas":material("Weathered_Linen",(0.73,0.665,0.50),0.87,grain=(12,12,12)),
        "rope":material("Hemp_Rope",(0.27,0.21,0.125),0.9),
        "standing":material("Tarred_Standing_Rigging",(0.07,0.055,0.035),0.9),
        "seam":material("Canvas_Stitching",(0.37,0.31,0.22),0.9),
        "glass":material("Stern_Window_Glass",(0.11,0.23,0.25),0.2,0.35),
        "lamp":material("Lantern_Glass",(0.9,0.5,0.12),0.32),
        "ground":material("Studio_Backdrop",(0.68,0.73,0.76),0.9),
    }
    hull(scene,groups,root,mats)
    cabins_and_rails(groups,root,mats)
    cannons(groups,root,mats)
    deck_fittings(groups,root,mats)
    ship_wheel(groups,root,mats)
    below_deck(groups,root,mats)
    rig(groups,root,mats)
    staging(scene,groups,root,mats)
    interior_staging(groups)
    for obj in scene.objects:
        obj.select_set(False)
    root.select_set(True)
    bpy.context.view_layer.objects.active=root
    meshes=[obj for obj in scene.objects if obj.type=="MESH" and obj.parent==root]
    root["mesh_objects"]=len(meshes)
    root["base_faces"]=sum(len(obj.data.polygons) for obj in meshes)
    root["interior_revision"]=2
    root["collision_revision"]=3
    bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT/"reference_frigate.blend"))
    print(f"BUILT {len(meshes)} editable mesh objects, {root['base_faces']} base faces")
    print(f"SAVED {OUTPUT / 'reference_frigate.blend'}")


if __name__=="__main__":
    build()
