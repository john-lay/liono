import bpy

# ── Clean scene ───────────────────────────────────────────────────────────────
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

# ── Import FBX ────────────────────────────────────────────────────────────────
bpy.ops.import_scene.fbx(
    filepath="D:/Repo/liono/assets/models/FBX 2013/Idle.fbx",
    use_anim=True,
    use_manual_orientation=True,
    axis_forward='-Z',
    axis_up='Y',
)

arm_obj   = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
mesh_objs = [o for o in bpy.data.objects if o.type == 'MESH']
print(f"Armature '{arm_obj.name}'  scale={tuple(round(v,4) for v in arm_obj.scale)}")
for m in mesh_objs:
    print(f"  Mesh '{m.name}'  loc={tuple(round(v,3) for v in m.location)}  scale={tuple(round(v,4) for v in m.scale)}")

# ── Apply scale on armature + all children ────────────────────────────────────
# Selecting parent+children together lets Blender compensate child local
# positions automatically, so world positions are maintained.
bpy.ops.object.select_all(action='DESELECT')
arm_obj.select_set(True)
for m in mesh_objs:
    m.select_set(True)
bpy.context.view_layer.objects.active = arm_obj
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

bpy.context.view_layer.update()
print(f"After apply — Armature scale: {tuple(round(v,4) for v in arm_obj.scale)}")

# ── Center character in Blender XY = Godot XZ ────────────────────────────────
# Mixamo rigs may have the armature origin offset from the skeleton's XY centre.
# Moving the armature object to the bone-bbox centre before applying location
# ensures the rotation pivot (origin) sits at the character's true XZ centre.
bpy.context.view_layer.update()
bone_world = [arm_obj.matrix_world @ pb.head for pb in arm_obj.pose.bones]
cx = (min(p.x for p in bone_world) + max(p.x for p in bone_world)) / 2.0
cy = (min(p.y for p in bone_world) + max(p.y for p in bone_world)) / 2.0
arm_obj.location.x -= cx
arm_obj.location.y -= cy
print(f"XY skeleton centre: ({round(cx,4)}, {round(cy,4)}) → centering armature")
bpy.context.view_layer.update()

# ── Lift rig so toes land at Z=0 ─────────────────────────────────────────────
# Recalculate after XY shift, then move only the armature object upward.
# Applying location on the armature alone bakes the offset into the bone rest
# positions without disturbing the mesh children's local positions.
min_toe_z = min(
    (arm_obj.matrix_world @ pb.head).z
    for pb in arm_obj.pose.bones if 'Toe_End' in pb.name
)
print(f"Min toe world Z = {round(min_toe_z, 4)}  →  lifting armature by {round(-min_toe_z, 4)}")
arm_obj.location.z -= min_toe_z
bpy.context.view_layer.update()

# Apply all three axes at once (XY centering + Z lift) on armature only.
bpy.ops.object.select_all(action='DESELECT')
arm_obj.select_set(True)
bpy.context.view_layer.objects.active = arm_obj
bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)

# Verify
bpy.context.view_layer.update()
print("Key bone world Z after lift:")
for pb in arm_obj.pose.bones:
    if any(k in pb.name for k in ['Hips', 'HeadTop', 'Toe_End']):
        wz = (arm_obj.matrix_world @ pb.head).z
        print(f"  {pb.name}: Z={round(wz, 4)}")

# ── Strip Hips location tracks (removes root motion jump) ────────────────────
for action in bpy.data.actions:
    hips_loc = [fc for fc in action.fcurves
                if 'mixamorig:Hips' in fc.data_path and 'location' in fc.data_path]
    for fc in hips_loc:
        action.fcurves.remove(fc)
    print(f"Stripped {len(hips_loc)} Hips location tracks from '{action.name}'")
    action.name = 'Idle'

# ── Assign PNG textures ───────────────────────────────────────────────────────
tex_dir = "D:/Repo/liono/assets/textures/"
tex_map = [
    ('body',  'liono_texture.png'),
    ('hair',  'liono-hair_texture.png'),
    ('eye',   'liono-eye_texture.png'),
    ('teeth', 'liono-eye_texture.png'),
    ('claw',  'liono-clawshield_texture.png'),
    ('sword', 'liono-sword_texture.png'),
]
for mat in bpy.data.materials:
    ml = mat.name.lower()
    tex_file = next((f for k, f in tex_map if k in ml), None)
    if not tex_file:
        print(f"  No texture match for '{mat.name}' — skipping")
        continue
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    bsdf = nt.nodes.new('ShaderNodeBsdfPrincipled')
    out  = nt.nodes.new('ShaderNodeOutputMaterial')
    tex  = nt.nodes.new('ShaderNodeTexImage')
    tex.image = bpy.data.images.load(tex_dir + tex_file)
    nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    nt.links.new(bsdf.outputs['BSDF'], out.inputs['Surface'])
    print(f"  {mat.name} → {tex_file}")

# ── Export GLB ────────────────────────────────────────────────────────────────
import os
out_path = "D:/Repo/liono/godot/assets/models/liono.glb"
os.makedirs(os.path.dirname(out_path), exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=out_path,
    export_format='GLB',
    export_animations=True,
    export_skins=True,
    export_image_format='AUTO',
    export_apply=False,
)
print(f"\nExported → {out_path}")
