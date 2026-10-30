"""Stylized low-poly relic models, built by script in Blender (interim art until Tripo versions).

Each relic is a few primitives in palette colors, joined into ONE mesh (RelicModels uses the
first part) and UV-mapped onto a small palette texture, so the whole relic needs one basecolor
image. Exports <out>/<RelicId>/<RelicId>.fbx plus <RelicId>.fbm/<RelicId>_basecolor.png (the
layout tools/models/upload_model.py expects) and a preview render <out>/<RelicId>.png.

Run: blender --background --factory-startup --python tools/models/blender/build_relics.py -- <out dir> [RelicId ...]
"""

import math
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Euler, Vector

SWATCH = 8  # px per palette cell
CELLS = 8   # cells per row

PALETTE = {}


def color_index(rgb):
    key = tuple(round(c, 3) for c in rgb)
    if key not in PALETTE:
        PALETTE[key] = len(PALETTE)
    return PALETTE[key]


def hexc(code):
    code = code.lstrip("#")
    return tuple(int(code[i:i + 2], 16) / 255 for i in (0, 2, 4))


# --------------------------------------------------------------------------- primitives
def _finish(obj, color, smooth=True, bevel=0.0):
    obj["swatch"] = color_index(hexc(color))
    if bevel > 0:
        mod = obj.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
    for poly in obj.data.polygons:
        poly.use_smooth = smooth
    return obj


def place(obj, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    obj.location = loc
    obj.rotation_euler = Euler([math.radians(a) for a in rot])
    obj.scale = scale
    return obj


def cylinder(color, r, depth, loc=(0, 0, 0), rot=(0, 0, 0), verts=16, r2=None, smooth=True, bevel=0.0):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=depth)
    return _finish(place(bpy.context.object, loc, rot), color, smooth, bevel)


def box(color, size, loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.02):
    bpy.ops.mesh.primitive_cube_add(size=1)
    return _finish(place(bpy.context.object, loc, rot, size), color, False, bevel)


def sphere(color, r, loc=(0, 0, 0), scale=(1, 1, 1), rot=(0, 0, 0), seg=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg // 2, radius=r)
    return _finish(place(bpy.context.object, loc, rot, scale), color)


def torus(color, major, minor, loc=(0, 0, 0), rot=(0, 0, 0), seg=24):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=seg, minor_segments=8)
    return _finish(place(bpy.context.object, loc, rot), color)


def blade(color, length, width, thickness, loc=(0, 0, 0), rot=(0, 0, 0)):
    """A leaf / diamond blade: flat diamond cross-section tapering to a point (+Z)."""
    mesh = bpy.data.meshes.new("blade")
    bm = bmesh.new()
    rings = [(0.0, 0.25), (0.25, 1.0), (0.6, 0.75), (1.0, 0.0)]
    layers = []
    for z, w in rings:
        hw, ht = width / 2 * w, thickness / 2 * max(w, 0.0)
        z *= length
        layers.append([bm.verts.new((hw, 0, z)), bm.verts.new((0, ht, z)), bm.verts.new((-hw, 0, z)), bm.verts.new((0, -ht, z))])
    for a, b in zip(layers, layers[1:]):
        for i in range(4):
            bm.faces.new((a[i], a[(i + 1) % 4], b[(i + 1) % 4], b[i]))
    bm.faces.new(list(reversed(layers[0])))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.to_mesh(mesh)
    obj = bpy.data.objects.new("blade", mesh)
    bpy.context.collection.objects.link(obj)
    return _finish(place(obj, loc, rot), color, smooth=False)


# --------------------------------------------------------------------------- relic recipes
def kunay():
    steel, edge, wrap, wrap2, ring = "#5d6470", "#c9d0da", "#2b2b33", "#8a1f2a", "#7a7f88"
    blade(steel, 1.6, 0.62, 0.12, loc=(0, 0, 0.55))
    blade(edge, 1.45, 0.42, 0.135, loc=(0, 0, 0.62))
    cylinder(wrap, 0.085, 0.95, loc=(0, 0, 0.08))
    for i in range(5):
        torus(wrap2, 0.09, 0.022, loc=(0, 0, -0.3 + i * 0.18))
    torus(ring, 0.2, 0.045, loc=(0, 0, -0.62), rot=(90, 0, 0))
    cylinder(ring, 0.12, 0.06, loc=(0, 0, 0.55), verts=8)


def seal_scroll():
    paper, rod, cap, seal, band = "#e9dcc0", "#5a3a22", "#c9a24a", "#7a1fbf", "#9b2335"
    cylinder(paper, 0.42, 1.5, rot=(0, 90, 0), verts=24)
    for x in (-0.86, 0.86):
        cylinder(rod, 0.12, 0.3, loc=(x, 0, 0), rot=(0, 90, 0))
        cylinder(cap, 0.2, 0.08, loc=(x * 1.12, 0, 0), rot=(0, 90, 0), verts=12, bevel=0.01)
    for x in (-0.5, 0.5):
        torus(band, 0.43, 0.03, loc=(x, 0, 0), rot=(0, 90, 0))
    # spiral seal on the front: rings of shrinking tori
    for i, r in enumerate((0.26, 0.18, 0.1)):
        torus(seal, r, 0.022, loc=(0, -0.42, 0), rot=(90, 0, 0))
    sphere(seal, 0.05, loc=(0, -0.43, 0))
    # loose paper flap hanging down
    box(paper, (0.9, 0.02, 0.5), loc=(0, -0.3, -0.45), rot=(-20, 0, 0), bevel=0.005)
    box(seal, (0.5, 0.025, 0.04), loc=(0, -0.33, -0.5), rot=(-20, 0, 0), bevel=0.0)


def senzo_bean():
    bean, bean2, cloth, cord = "#5fbf3a", "#9be060", "#b48a5a", "#6b4426"
    sphere(bean, 0.45, loc=(0, 0, 0.55), scale=(0.75, 0.6, 1.0), rot=(0, 25, 0))
    sphere(bean2, 0.2, loc=(-0.12, -0.2, 0.75), scale=(0.6, 0.4, 0.8), rot=(0, 25, 0))
    # pouch: squashed sphere with a gathered neck and cord
    sphere(cloth, 0.55, loc=(0.1, 0.25, -0.15), scale=(1.0, 0.9, 0.75), seg=12)
    cylinder(cloth, 0.22, 0.3, loc=(0.1, 0.25, 0.32), r2=0.32, verts=10)
    torus(cord, 0.22, 0.04, loc=(0.1, 0.25, 0.25))
    sphere(cord, 0.06, loc=(0.32, 0.12, 0.2))


RECIPES = {"Kunay": kunay, "SealScroll": seal_scroll, "SenzoBean": senzo_bean}


# --------------------------------------------------------------------------- build / export
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    PALETTE.clear()


def palette_image(name):
    size = SWATCH * CELLS
    img = bpy.data.images.new(name, size, size)
    pixels = [0.0] * (size * size * 4)
    for rgb, i in PALETTE.items():
        cx, cy = (i % CELLS) * SWATCH, (i // CELLS) * SWATCH
        for y in range(cy, cy + SWATCH):
            for x in range(cx, cx + SWATCH):
                o = (y * size + x) * 4
                pixels[o:o + 4] = [*rgb, 1.0]
    img.pixels = pixels
    return img


def join_with_palette(name):
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for obj in objs:
        bpy.context.view_layer.objects.active = obj
        for mod in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)
        swatch = obj["swatch"]
        u = ((swatch % CELLS) + 0.5) / CELLS
        v = ((swatch // CELLS) + 0.5) / CELLS
        uv = obj.data.uv_layers.get("UVMap") or obj.data.uv_layers.new(name="UVMap")
        for loop in uv.data:
            loop.uv = (u, v)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objs:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    relic = bpy.context.object
    relic.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    # center on the bounding box so RelicModels can place it
    bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
    relic.location = (0, 0, 0)
    return relic


def material(relic, img):
    mat = bpy.data.materials.new(relic.name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    bsdf = nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.6
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    relic.data.materials.append(mat)


def render(relic, path):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
    scene.render.resolution_x = scene.render.resolution_y = 512
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.05, 0.05, 0.07, 1)
    scene.world = world
    size = max(relic.dimensions)
    cam_data = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = Vector((size * 1.6, -size * 2.2, size * 0.9))
    cam.rotation_euler = (cam.location * -1).to_track_quat("-Z", "Y").to_euler()
    cam_data.lens = 50
    scene.camera = cam
    for loc, energy in (((3, -3, 4), 900), ((-4, -1, 2), 300), ((0, 4, 3), 500)):
        light = bpy.data.objects.new("l", bpy.data.lights.new("l", "POINT"))
        light.data.energy = energy * size
        light.location = Vector(loc) * size
        scene.collection.objects.link(light)
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def build(relic_id, out):
    reset()
    RECIPES[relic_id]()
    relic = join_with_palette(relic_id)
    folder = out / relic_id
    fbm = folder / f"{relic_id}.fbm"
    fbm.mkdir(parents=True, exist_ok=True)
    img = palette_image(f"{relic_id}_basecolor")
    img.filepath_raw = str(fbm / f"{relic_id}_basecolor.png")
    img.file_format = "PNG"
    img.save()
    material(relic, img)
    bpy.ops.object.select_all(action="DESELECT")
    relic.select_set(True)
    bpy.ops.export_scene.fbx(filepath=str(folder / f"{relic_id}.fbx"), use_selection=True,
                             apply_scale_options="FBX_SCALE_ALL", path_mode="STRIP")
    tris = sum(len(p.vertices) - 2 for p in relic.data.polygons)
    render(relic, out / f"{relic_id}.png")
    print(f"BUILT {relic_id}: {tris} tris, {len(PALETTE)} colors, dims {tuple(round(d, 2) for d in relic.dimensions)}")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    out = Path(argv[0])
    ids = argv[1:] or list(RECIPES)
    for relic_id in ids:
        build(relic_id, out)


main()
