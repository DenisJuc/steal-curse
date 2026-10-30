"""Shrink a Tripo GLB export (~700k faces, 4k textures) into an upload-ready FBX + .fbm maps.

blender --background --python tools/models/blender/prep_tripo_glb.py -- <in.glb> <out_dir> <RelicId> [target_tris]
Writes <out_dir>/<RelicId>.fbx and <out_dir>/<RelicId>.fbm/<RelicId>_{basecolor,normal,metallic,roughness}.png,
the layout tools/models/upload_model.py reads. Textures are cut to 1024 (the SurfaceAppearance cap); glTF's packed
metallicRoughness map is split into the two maps Roblox takes (G = roughness, B = metallic).
"""

import sys
from pathlib import Path

import bpy
import numpy as np

argv = sys.argv[sys.argv.index("--") + 1:]
src, out_dir, relic = Path(argv[0]), Path(argv[1]), argv[2]
target = int(argv[3]) if len(argv) > 3 else 9000
SIZE = 1024

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(src))
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

before = sum(len(p.vertices) - 2 for p in obj.data.polygons)
if before > target:
    mod = obj.modifiers.new("dec", "DECIMATE")
    mod.ratio = target / before
    bpy.ops.object.modifier_apply(modifier=mod.name)
after = sum(len(p.vertices) - 2 for p in obj.data.polygons)

fbm = out_dir / f"{relic}.fbm"
fbm.mkdir(parents=True, exist_ok=True)


def save(pixels, w, h, name, channels=4):
    img = bpy.data.images.new(name, w, h, alpha=True)
    img.pixels.foreach_set(pixels.ravel())
    img.scale(SIZE, SIZE)
    # save_render writes a generated image to disk; image.save() silently does nothing for one
    bpy.context.scene.render.image_settings.file_format = "PNG"
    bpy.context.scene.view_settings.view_transform = "Standard"
    img.save_render(str((fbm / f"{relic}_{name}.png").resolve()))


def image_of(socket):
    for link in socket.links:
        node = link.from_node
        while node.type != "TEX_IMAGE" and node.inputs:
            linked = [i for i in node.inputs if i.is_linked]
            if not linked:
                break
            node = linked[0].links[0].from_node
        if node.type == "TEX_IMAGE":
            return node.image
    return None


mat = obj.data.materials[0]
bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
written = []
for socket_name, tag in (("Base Color", "basecolor"), ("Normal", "normal")):
    img = image_of(bsdf.inputs[socket_name])
    if img:
        px = np.empty(img.size[0] * img.size[1] * 4, dtype=np.float32)
        img.pixels.foreach_get(px)
        save(px, img.size[0], img.size[1], tag)
        written.append(tag)
mr = image_of(bsdf.inputs["Roughness"]) or image_of(bsdf.inputs["Metallic"])
if mr:
    px = np.empty(mr.size[0] * mr.size[1] * 4, dtype=np.float32)
    mr.pixels.foreach_get(px)
    px = px.reshape(-1, 4)
    for tag, ch in (("roughness", 1), ("metallic", 2)):
        grey = np.repeat(px[:, ch:ch + 1], 4, axis=1)
        grey[:, 3] = 1.0
        save(grey, mr.size[0], mr.size[1], tag)
        written.append(tag)

dims = obj.dimensions
bpy.ops.export_scene.fbx(filepath=str(out_dir / f"{relic}.fbx"), use_selection=True, path_mode="STRIP",
                         embed_textures=False, axis_forward="-Z", axis_up="Y", apply_scale_options="FBX_SCALE_ALL")
print(f"[prep] {relic}: {before} -> {after} tris, maps={written}, dims={tuple(round(d, 2) for d in dims)}")
