import bpy, os

FBX_DIR  = "D:/Repo/liono/assets/models/FBX 2013/"
TEX_DIR  = "D:/Repo/liono/assets/textures/"
OUT_PATH = "D:/Repo/liono/godot/assets/models/liono.glb"

# ── Clean scene ───────────────────────────────────────────────────────────────
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

# ── Import base FBX (mesh + skeleton + Idle animation) ───────────────────────
bpy.ops.import_scene.fbx(
    filepath=FBX_DIR + "Idle.fbx",
    use_anim=True,
    use_manual_orientation=True,
    axis_forward='-Z',
    axis_up='Y',
)

arm_obj   = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
mesh_objs = [o for o in bpy.data.objects if o.type == 'MESH']
print(f"Armature '{arm_obj.name}'  scale={tuple(round(v,4) for v in arm_obj.scale)}")

# ── Apply rotation + scale on armature + all children ────────────────────────
bpy.ops.object.select_all(action='DESELECT')
arm_obj.select_set(True)
for m in mesh_objs:
    m.select_set(True)
bpy.context.view_layer.objects.active = arm_obj
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
bpy.context.view_layer.update()

# ── Center character in Blender XY = Godot XZ ────────────────────────────────
bone_world = [arm_obj.matrix_world @ pb.head for pb in arm_obj.pose.bones]
cx = (min(p.x for p in bone_world) + max(p.x for p in bone_world)) / 2.0
cy = (min(p.y for p in bone_world) + max(p.y for p in bone_world)) / 2.0
arm_obj.location.x -= cx
arm_obj.location.y -= cy
print(f"XY skeleton centre: ({round(cx,4)}, {round(cy,4)}) → centering armature")
bpy.context.view_layer.update()

# ── Lift rig so toes land at Z=0 ─────────────────────────────────────────────
min_toe_z = min(
    (arm_obj.matrix_world @ pb.head).z
    for pb in arm_obj.pose.bones if 'Toe_End' in pb.name
)
print(f"Min toe world Z = {round(min_toe_z, 4)}  →  lifting armature by {round(-min_toe_z, 4)}")
arm_obj.location.z -= min_toe_z
bpy.context.view_layer.update()

# Apply all three axes at once (XY centering + Z lift) on armature only
bpy.ops.object.select_all(action='DESELECT')
arm_obj.select_set(True)
bpy.context.view_layer.objects.active = arm_obj
bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
bpy.context.view_layer.update()

# ── Strip + rename Idle action ────────────────────────────────────────────────
def strip_root_motion(action):
    hips_loc = [fc for fc in action.fcurves
                if 'mixamorig:Hips' in fc.data_path and 'location' in fc.data_path]
    for fc in hips_loc:
        action.fcurves.remove(fc)
    return len(hips_loc)

idle_action = arm_obj.animation_data.action
n = strip_root_motion(idle_action)
idle_action.name = 'Idle'
idle_action.use_fake_user = True
print(f"Idle: stripped {n} Hips location tracks")

# ── Import additional animation FBX files ────────────────────────────────────
# Only the action is needed from each — mesh/armature are discarded after.
# FCurves are in bone-local space so they are unaffected by the armature's
# world transform; only root-motion stripping is required.
EXTRA_ANIMS = [
    ("Walking.fbx",              "Walk"),
    ("Walk Backwards.fbx",       "Walk-Backwards"),
    ("Left Turn.fbx",            "Left-Turn"),
    ("Right Turn.fbx",           "Right-Turn"),
    ("Jumping.fbx",              "Jump"),
    ("Start Climbing Ladder.fbx","Start-Climbing-Ladder"),
    ("Climbing Ladder.fbx",      "Climbing-Ladder"),
]

for fbx_file, action_name in EXTRA_ANIMS:
    before = set(bpy.data.objects.keys())
    bpy.ops.import_scene.fbx(
        filepath=FBX_DIR + fbx_file,
        use_anim=True,
        use_manual_orientation=True,
        axis_forward='-Z',
        axis_up='Y',
    )
    new_objs = [o for o in bpy.data.objects if o.name not in before]
    new_arm  = next((o for o in new_objs if o.type == 'ARMATURE'), None)

    if new_arm is None or not new_arm.animation_data or not new_arm.animation_data.action:
        print(f"ERROR: no armature/action found in {fbx_file}")
        bpy.ops.object.select_all(action='DESELECT')
        for o in new_objs:
            o.select_set(True)
        bpy.ops.object.delete(use_global=False)
        continue

    action = new_arm.animation_data.action
    n = strip_root_motion(action)
    action.name = action_name
    action.use_fake_user = True  # keep alive after secondary armature is deleted
    print(f"{action_name}: stripped {n} Hips location tracks  ({fbx_file})")

    # Delete secondary armature + meshes (action survives via fake user)
    bpy.ops.object.select_all(action='DESELECT')
    for o in new_objs:
        o.select_set(True)
    bpy.ops.object.delete(use_global=False)

# ── Push all actions into NLA tracks on main armature ────────────────────────
# The glTF exporter converts each NLA strip into a separate animation clip.
arm_obj.animation_data_create()
arm_obj.animation_data.action = None  # clear active action to avoid double-export
for action in bpy.data.actions:
    track = arm_obj.animation_data.nla_tracks.new()
    track.name = action.name
    strip = track.strips.new(action.name, int(action.frame_range[0]), action)
    strip.name = action.name
    print(f"NLA: '{action.name}'  frames {int(action.frame_range[0])}–{int(action.frame_range[1])}")

# ── Assign PNG textures ───────────────────────────────────────────────────────
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
        continue
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    bsdf = nt.nodes.new('ShaderNodeBsdfPrincipled')
    out  = nt.nodes.new('ShaderNodeOutputMaterial')
    tex  = nt.nodes.new('ShaderNodeTexImage')
    tex.image = bpy.data.images.load(TEX_DIR + tex_file)
    nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    nt.links.new(bsdf.outputs['BSDF'], out.inputs['Surface'])
    print(f"  {mat.name} → {tex_file}")

# ── Export GLB ────────────────────────────────────────────────────────────────
os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=OUT_PATH,
    export_format='GLB',
    export_animations=True,
    export_nla_strips=True,   # each NLA strip → one glTF animation clip
    export_skins=True,
    export_image_format='AUTO',
    export_apply=False,
)
print(f"\nExported → {OUT_PATH}")
