import bpy

print("\n=== OBJECTS ===")
for obj in bpy.data.objects:
    print(f"  [{obj.type}] {obj.name}  loc={tuple(round(v,3) for v in obj.location)}  rot={tuple(round(v,3) for v in obj.rotation_euler)}  scale={tuple(round(v,3) for v in obj.scale)}")

print("\n=== ARMATURES ===")
for obj in bpy.data.objects:
    if obj.type == 'ARMATURE':
        print(f"  Armature object: {obj.name}")
        for bone in obj.data.bones:
            if bone.parent is None:
                print(f"    Root bone: {bone.name}")
        print(f"  All bones: {[b.name for b in obj.data.bones]}")

print("\n=== ACTIONS ===")
for action in bpy.data.actions:
    print(f"\n  Action: {action.name}")
    for fc in action.fcurves:
        print(f"    FCurve: {fc.data_path}[{fc.array_index}]  keyframes={len(fc.keyframe_points)}")
