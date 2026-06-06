import bpy

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

bpy.ops.import_scene.fbx(filepath="D:/Repo/liono/assets/models/FBX 2013/Idle.fbx")

print("\n=== OBJECTS ===")
for obj in bpy.data.objects:
    parent = obj.parent.name if obj.parent else "None"
    arm_mod = any(m.type == 'ARMATURE' for m in obj.modifiers)
    print(f"  [{obj.type}] {obj.name!r}  loc={tuple(round(v,3) for v in obj.location)}  scale={tuple(round(v,4) for v in obj.scale)}  parent={parent!r}  arm_mod={arm_mod}")
