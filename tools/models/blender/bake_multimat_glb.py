# Merge a multi-material GLB (e.g. a Sketchfab download) into ONE mesh with ONE base-colour texture,
# so the normal Tripo pipeline (prep_tripo_glb.py -> upload_model.py, which only reads material 0)
# can take it. Bakes every material's colour into a fresh 1024 atlas on a new UV map.
# usage: blender --background --python bake_multimat_glb.py -- <in.glb> <out.glb>
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
src, dst = argv[0], argv[1]
SIZE = 1024

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# Joined meshes can carry differently named UV maps; make every material read the first map
# explicitly, then add the bake target map.
src_uv = obj.data.uv_layers[0].name
for mat in obj.data.materials:
    nt = mat.node_tree
    for node in list(nt.nodes):
        if node.type == "TEX_IMAGE" and not node.inputs["Vector"].is_linked:
            uv = nt.nodes.new("ShaderNodeUVMap")
            uv.uv_map = src_uv
            nt.links.new(uv.outputs["UV"], node.inputs["Vector"])
bake_uv = obj.data.uv_layers.new(name="BakeUV")
obj.data.uv_layers.active = bake_uv
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(island_margin=0.003)
bpy.ops.object.mode_set(mode="OBJECT")

atlas = bpy.data.images.new("atlas", SIZE, SIZE, alpha=False)
for mat in obj.data.materials:
    nt = mat.node_tree
    target = nt.nodes.new("ShaderNodeTexImage")
    target.image = atlas
    uv = nt.nodes.new("ShaderNodeUVMap")
    uv.uv_map = "BakeUV"
    nt.links.new(uv.outputs["UV"], target.inputs["Vector"])
    nt.nodes.active = target

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 4
scene.render.bake.use_pass_direct = False
scene.render.bake.use_pass_indirect = False
scene.render.bake.margin = 4
bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"})

# Replace all materials with one that uses the atlas on BakeUV, drop the old UV map.
for i in range(len(obj.data.uv_layers) - 1, -1, -1):
    if obj.data.uv_layers[i].name != "BakeUV":
        obj.data.uv_layers.remove(obj.data.uv_layers[i])
mat = bpy.data.materials.new("Baked")
mat.use_nodes = True
bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
tex.image = atlas
mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.6
obj.data.materials.clear()
obj.data.materials.append(mat)
atlas.pack()
bpy.ops.export_scene.gltf(filepath=dst, use_selection=True, export_format="GLB")
tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
print(f"[bake] {src} -> {dst}: {tris} tris, 1 material, atlas {SIZE}")
