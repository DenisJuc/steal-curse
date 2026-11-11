# Cut stray geometry (a long ribbon, a chain loop) off an elongated model such as a sword: find the
# main axis by repeated PCA on the points nearest to it, then delete every vertex farther than
# <keep> (fraction of the model's size) from that axis. Writes a new GLB.
# usage: blender --background --python trim_to_axis.py -- <in.glb> <out.glb> [keep=0.09]
import sys

import bmesh
import bpy
import numpy as np

argv = sys.argv[sys.argv.index("--") + 1:]
src, dst = argv[0], argv[1]
keep = float(argv[2]) if len(argv) > 2 else 0.09

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
obj = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
bpy.context.view_layer.objects.active = obj
obj.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
me = obj.data
co = np.empty(len(me.vertices) * 3)
me.vertices.foreach_get("co", co)
co = co.reshape(-1, 3)
size = float(np.linalg.norm(co.max(0) - co.min(0)))

mask = np.ones(len(co), bool)
for radius in (0.35, 0.22, 0.15, keep):
    pts = co[mask]
    centre = pts.mean(0)
    _, vecs = np.linalg.eigh(np.cov((pts - centre).T))
    axis = vecs[:, 2]
    rel = co - centre
    dist = np.linalg.norm(rel - np.outer(rel @ axis, axis), axis=1)
    mask = dist < radius * size
print(f"[trim] keeping {mask.sum()} of {len(co)} verts (radius {keep} of size {size:.2f})")

bm = bmesh.new()
bm.from_mesh(me)
bm.verts.ensure_lookup_table()
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not mask[v.index]], context="VERTS")
# Leftover scraps of the cut-off geometry (ribbon pieces crossing the blade) end up as small
# separate islands once welded: drop every island under 10% of what is left.
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005 * size)
bm.verts.ensure_lookup_table()
seen, islands = set(), []
for v in bm.verts:
    if v.index in seen:
        continue
    stack, members = [v], []
    seen.add(v.index)
    while stack:
        x = stack.pop()
        members.append(x)
        for e in x.link_edges:
            o = e.other_vert(x)
            if o.index not in seen:
                seen.add(o.index)
                stack.append(o)
    islands.append(members)
total = len(bm.verts)
small = [v for isl in islands if len(isl) < 0.1 * total for v in isl]
print(f"[trim] island sizes {sorted(len(i) for i in islands)}; dropping {len(small)} verts in small ones")
bmesh.ops.delete(bm, geom=small, context="VERTS")
bm.to_mesh(me)
bm.free()
bpy.ops.export_scene.gltf(filepath=dst, use_selection=True, export_format="GLB")
