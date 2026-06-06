import bpy

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

bpy.ops.import_scene.gltf(filepath="D:/Repo/liono/assets/models/liono.glb")

print("\n=== OBJECTS ===")
for obj in bpy.data.objects:
    print(f"  [{obj.type}] {obj.name!r}  loc={tuple(round(v,3) for v in obj.location)}  scale={tuple(round(v,4) for v in obj.scale)}  parent={obj.parent.name if obj.parent else None}")

print("\n=== ACTIONS ===")
for action in bpy.data.actions:
    print(f"  Action: {action.name!r}  fcurves={len(action.fcurves)}")
    for fc in action.fcurves[:5]:
        print(f"    {fc.data_path}[{fc.array_index}]")

print("\n=== ARMATURES ===")
for arm in bpy.data.armatures:
    print(f"  Armature data: {arm.name!r}  bones={[b.name for b in arm.bones]}")
