import bpy

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

bpy.ops.import_scene.fbx(filepath="D:/Repo/liono/assets/models/FBX 2013/Idle.fbx", use_anim=True)

arm_obj   = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
mesh_objs = [o for o in bpy.data.objects if o.type == 'MESH']

# Apply rotation + scale (same as export script)
bpy.ops.object.select_all(action='DESELECT')
arm_obj.select_set(True)
for m in mesh_objs:
    m.select_set(True)
bpy.context.view_layer.objects.active = arm_obj
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

# Print bone world positions in rest pose
bpy.context.view_layer.update()
print("\n=== BONE WORLD POSITIONS (rest pose, after transform apply) ===")
for bone in arm_obj.pose.bones:
    head_world = arm_obj.matrix_world @ bone.head
    print(f"  {bone.name}  head_world_Z={round(head_world.z, 4)}")

print("\n=== ARMATURE ===")
print(f"  loc={tuple(round(v,4) for v in arm_obj.location)}  scale={tuple(round(v,4) for v in arm_obj.scale)}")
