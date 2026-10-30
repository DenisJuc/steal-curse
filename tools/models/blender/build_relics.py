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


def color_index(rgb, glow=False):
    key = tuple(round(c, 3) for c in rgb) + (glow,)
    if key not in PALETTE:
        PALETTE[key] = len(PALETTE)
    return PALETTE[key]


def hexc(code):
    code = code.lstrip("#")
    return tuple(int(code[i:i + 2], 16) / 255 for i in (0, 2, 4))


# --------------------------------------------------------------------------- primitives
def _finish(obj, color, smooth=True, bevel=0.0):
    # "!" suffix = glowing accent (goes into the emissive mask)
    glow = color.endswith("!")
    obj["swatch"] = color_index(hexc(color.rstrip("!")), glow)
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
# Style (reviewed): dark, desaturated body (charcoal, aged leather, bone) + ONE small saturated
# glowing accent ("!" colors) on the focal feature; chunky proportions that read at icon size.
CHAR, IRON, BONE, LEATHER, TAN, GOLD = "#2a2a31", "#7d8592", "#cbbfa4", "#4a3326", "#8f7a5c", "#b08a3a"


def kunay():
    blade("#9aa3b0", 1.6, 0.66, 0.16, loc=(0, 0, 0.55))
    blade("#ff3b4e!", 1.3, 0.16, 0.18, loc=(0, 0, 0.68))
    cylinder(CHAR, 0.1, 0.95, loc=(0, 0, 0.08))
    for i in range(5):
        torus("#6e1520", 0.105, 0.026, loc=(0, 0, -0.3 + i * 0.18))
    torus(IRON, 0.26, 0.06, loc=(0, 0, -0.68), rot=(90, 0, 0))
    cylinder(IRON, 0.13, 0.07, loc=(0, 0, 0.55), verts=8)


def seal_scroll():
    cylinder(TAN, 0.42, 1.5, rot=(0, 90, 0), verts=24)
    for x in (-0.86, 0.86):
        cylinder(LEATHER, 0.13, 0.3, loc=(x, 0, 0), rot=(0, 90, 0))
        cylinder(GOLD, 0.21, 0.09, loc=(x * 1.12, 0, 0), rot=(0, 90, 0), verts=12, bevel=0.01)
    for x in (-0.5, 0.5):
        torus("#5a1620", 0.43, 0.035, loc=(x, 0, 0), rot=(0, 90, 0))
    for r in (0.27, 0.19, 0.11):
        torus("#b24dff!", r, 0.026, loc=(0, -0.42, 0), rot=(90, 0, 0))
    sphere("#b24dff!", 0.055, loc=(0, -0.43, 0))


def senzo_bean():
    sphere("#2fd39a!", 0.42, loc=(0, 0, 0.6), scale=(0.62, 0.55, 1.15), rot=(0, 18, 0))
    sphere("#1f8f68", 0.43, loc=(0.03, 0.02, 0.6), scale=(0.6, 0.5, 1.1), rot=(0, 18, 0), seg=12)
    torus("#14583f", 0.24, 0.02, loc=(0.0, -0.2, 0.6), rot=(90, 90, 0))
    sphere(LEATHER, 0.4, loc=(0.05, 0.1, -0.25), scale=(1.0, 0.9, 0.7), seg=12)
    cylinder(LEATHER, 0.17, 0.22, loc=(0.05, 0.1, 0.08), r2=0.25, verts=10)
    torus(TAN, 0.17, 0.035, loc=(0.05, 0.1, 0.04))


def paladyns_necklace():
    for i in range(14):
        a = math.radians(i * 360 / 16 + 22.5)
        sphere(BONE, 0.09, loc=(math.cos(a) * 0.8, 0, math.sin(a) * 0.8 + 0.5), seg=10)
    box("#e8f4ff!", (0.14, 0.1, 0.62), loc=(0, 0, -0.62), bevel=0.02)
    box("#e8f4ff!", (0.42, 0.1, 0.14), loc=(0, 0, -0.5), bevel=0.02)
    torus(IRON, 0.07, 0.02, loc=(0, 0, -0.26), rot=(90, 0, 0))


def steal_ball():
    sphere(IRON, 0.6, seg=20)
    for lat in (-40, 0, 40):
        n = 8 if lat == 0 else 6
        for i in range(n):
            a, b = math.radians(i * 360 / n + lat), math.radians(lat)
            d = Vector((math.cos(b) * math.cos(a), math.cos(b) * math.sin(a), math.sin(b)))
            sphere(CHAR, 0.09, loc=tuple(d * 0.6), seg=8)
    torus("#3be0ff!", 0.62, 0.025, rot=(90, 0, 0), seg=32)


def quinsy_bangle():
    torus("#aeb6c2", 0.55, 0.06, rot=(90, 0, 0), seg=32)
    cylinder(IRON, 0.02, 0.25, loc=(0, 0, -0.66))
    for a in range(5):
        r = math.radians(a * 72 + 90)
        box("#7fe8ff!", (0.07, 0.05, 0.3), loc=(math.cos(r) * 0.13, 0, -0.95 + math.sin(r) * 0.13), rot=(0, -a * 72, 0), bevel=0.01)
    sphere("#7fe8ff!", 0.07, loc=(0, 0, -0.95))


def hoy_poy_capsule():
    cylinder(BONE, 0.32, 0.9, rot=(0, 90, 0), verts=20)
    for x in (-0.45, 0.45):
        sphere(BONE, 0.32, loc=(x, 0, 0), seg=16)
    torus(CHAR, 0.33, 0.03, rot=(0, 90, 0))
    cylinder("#ffb12e!", 0.1, 0.12, loc=(0, 0, 0.33), verts=12)
    box(CHAR, (0.3, 0.02, 0.12), loc=(-0.4, -0.31, 0.02), bevel=0.005)


def wistaria_poison_vial():
    cylinder("#b06cff!", 0.34, 0.75, verts=16)
    cylinder("#3a3046", 0.36, 0.12, loc=(0, 0, -0.4), verts=16)
    cylinder("#3a3046", 0.14, 0.35, loc=(0, 0, 0.52), r2=0.12, verts=12)
    cylinder(LEATHER, 0.15, 0.2, loc=(0, 0, 0.78), verts=10)
    cylinder("#3d5a2a", 0.025, 0.5, loc=(0.2, 0, 0.75), rot=(0, 25, 0))
    for i in range(4):
        sphere("#9a7ad1", 0.07, loc=(0.27 + i * 0.03, -0.05, 0.62 - i * 0.12), seg=8)


def foxx_mask():
    sphere(BONE, 0.6, loc=(0, 0, 0), scale=(0.85, 0.35, 1.0), seg=18)
    cylinder(BONE, 0.32, 0.6, loc=(0, -0.3, -0.25), rot=(80, 0, 0), r2=0.08, verts=12)
    for x in (-0.38, 0.38):
        cylinder(BONE, 0.17, 0.45, loc=(x, 0.0, 0.62), rot=(0, -x * 40, 0), r2=0.02, verts=4)
        cylinder("#e0283c", 0.1, 0.3, loc=(x * 0.98, -0.04, 0.6), rot=(0, -x * 40, 0), r2=0.01, verts=4)
    for x in (-0.22, 0.22):
        box("#ff2e4a!", (0.22, 0.05, 0.06), loc=(x, -0.2, 0.12), rot=(0, x * 60, 0), bevel=0.01)
    box("#9a1f2c", (0.04, 0.05, 0.4), loc=(0.18, -0.21, -0.12), rot=(0, 25, 0), bevel=0.005)


def huntar_license():
    box(CHAR, (1.0, 0.06, 1.4), bevel=0.04)
    box("#d9d2c2", (0.8, 0.07, 0.15), loc=(0, 0, -0.5), bevel=0.01)
    torus(GOLD, 0.28, 0.035, loc=(0, -0.04, 0.2), rot=(90, 0, 0))
    cylinder("#ff4f6d!", 0.12, 0.04, loc=(0, -0.05, 0.2), rot=(90, 0, 0), verts=6)
    for x in (-0.18, 0.18):
        box(GOLD, (0.05, 0.03, 0.22), loc=(x, -0.04, 0.2), rot=(0, x * 120, 0), bevel=0.0)


def akatsuko_ring():
    torus("#3b3540", 0.42, 0.09, rot=(90, 0, 0), seg=28)
    cylinder("#3b3540", 0.2, 0.12, loc=(0, 0, 0.5), verts=8)
    cylinder("#ff2e2e!", 0.15, 0.1, loc=(0, 0, 0.56), verts=8)
    box(CHAR, (0.04, 0.04, 0.18), loc=(0, 0, 0.62), bevel=0.0)


def black_nichiren_blade():
    box("#141418", (0.09, 0.03, 2.6), loc=(0.0, 0, 0.95), bevel=0.01)
    box("#5b7cff!", (0.02, 0.035, 2.4), loc=(0.04, 0, 0.92), bevel=0.0)
    box(IRON, (0.42, 0.42, 0.06), loc=(0, 0, -0.38), bevel=0.02)
    cylinder(CHAR, 0.075, 0.75, loc=(0, 0, -0.8), verts=8)
    for i in range(5):
        box("#2f3b6b", (0.17, 0.17, 0.05), loc=(0, 0, -0.5 - i * 0.13), rot=(0, 0, 45), bevel=0.0)


def magick_stone():
    cylinder("#58e0ff!", 0.42, 0.8, loc=(0, 0, 0.1), verts=6, r2=0.22, smooth=False)
    cylinder("#58e0ff!", 0.42, 0.4, loc=(0, 0, -0.5), verts=6, r2=0.04, smooth=False)
    cylinder("#2a2240", 0.3, 0.55, loc=(0.42, 0.1, -0.25), rot=(0, 30, 0), verts=5, r2=0.08, smooth=False)
    cylinder("#2a2240", 0.25, 0.45, loc=(-0.38, -0.05, -0.3), rot=(0, -35, 0), verts=5, r2=0.06, smooth=False)
    for i in range(3):
        a = math.radians(i * 120 + 30)
        box("#58e0ff!", (0.14, 0.02, 0.14), loc=(math.cos(a) * 0.7, math.sin(a) * 0.7, 0.45), rot=(0, 45, i * 120), bevel=0.0)


RECIPES = {
    "Kunay": kunay, "SealScroll": seal_scroll, "SenzoBean": senzo_bean,
    "PaladynsNecklace": paladyns_necklace, "StealBall": steal_ball, "QuinsyBangle": quinsy_bangle,
    "HoyPoyCapsule": hoy_poy_capsule, "WistariaPoisonVial": wistaria_poison_vial, "FoxxMask": foxx_mask,
    "HuntarLicense": huntar_license, "AkatsukoRing": akatsuko_ring, "BlackNichirenBlade": black_nichiren_blade,
    "MagickStone": magick_stone,
}


# --------------------------------------------------------------------------- build / export
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    PALETTE.clear()


def palette_image(name, emissive=False):
    size = SWATCH * CELLS
    img = bpy.data.images.new(name, size, size)
    pixels = [0.0] * (size * size * 4)
    for key, i in PALETTE.items():
        rgb, glow = key[:3], key[3]
        value = ([1.0, 1.0, 1.0] if glow else [0.0, 0.0, 0.0]) if emissive else list(rgb)
        cx, cy = (i % CELLS) * SWATCH, (i // CELLS) * SWATCH
        for y in range(cy, cy + SWATCH):
            for x in range(cx, cx + SWATCH):
                o = (y * size + x) * 4
                pixels[o:o + 4] = [*value, 1.0]
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


def material(relic, img, mask=None):
    mat = bpy.data.materials.new(relic.name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    bsdf = nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.6
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if mask is not None:
        # preview only: glow = basecolor * mask
        m = nodes.new("ShaderNodeTexImage")
        m.image = mask
        m.interpolation = "Closest"
        mix = nodes.new("ShaderNodeMixRGB")
        mix.blend_type = "MULTIPLY"
        mix.inputs["Fac"].default_value = 1
        mat.node_tree.links.new(tex.outputs["Color"], mix.inputs[1])
        mat.node_tree.links.new(m.outputs["Color"], mix.inputs[2])
        mat.node_tree.links.new(mix.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = 3.0
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
    mask = None
    if any(key[3] for key in PALETTE):
        mask = palette_image(f"{relic_id}_emissive", emissive=True)
        mask.filepath_raw = str(fbm / f"{relic_id}_emissive.png")
        mask.file_format = "PNG"
        mask.save()
    material(relic, img, mask)
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
