# Liono — N64-Style Action Adventure Demo

## Overview

A short playable demo in the style of Zelda: Ocarina of Time, built in Godot 3.x and exported as a WebGL app. The game features a single placeholder level with a third-person camera, Z-targeting, and full character animation.

---

## Technical Constraints

| Setting | Value |
|---|---|
| Engine | Godot 3.x (confirmed 3.4+ from `physical_scancode` field in project.godot) |
| Renderer | GLES2 (WebGL 1.0 compatible) |
| Export target | HTML5 (web) |
| Resolution | 800 × 600 |
| Stretch mode | `2d` / keep aspect |
| Movement | Always run (no walk toggle) |

---

## Current Status

| Phase | Status | Notes |
|---|---|---|
| Phase 1 — Config | ✅ Done | project.godot, input actions, folder structure |
| Phase 2 — Animations | ⚠️ Blocked | See open issues #1 below |
| Phase 3 — Player movement | ✅ Done | WASD + gravity + jump working |
| Phase 4 — Camera | ✅ Done | Orbit camera; SpringArm not yet added |
| Phase 5 — Level | 🔶 Partial | Floor + lighting done; geometry/fog not tuned |
| Phase 6 — Ladder | ❌ Not started | |

---

## Open Issues

### Issue 1 — Animation stretching and flickering (BLOCKER)

**Symptom:** Running the game shows Liono with all meshes stretched and flickering. No animation state visibly playing.

**Root cause (working hypothesis):** Loading `Animation` resources from separate `@*.fbx` imported scenes and adding them to the `AnimationPlayer` inside `Liono@Idle.fbx` fails because the bone track `NodePath`s in the loaded animations do not resolve correctly against the `Liono@Idle.fbx` skeleton. Specifically, the `AnimationPlayer.root_node` in each source scene may differ, making the copied tracks target non-existent nodes.

**What has been tried:**
- Loading animations via `_load_clip()` in `Player.gd` `_ready()` — broken
- Adding `.duplicate(true)` to avoid sharing the resource object across freed instances — still broken
- Both approaches used `find_node("AnimationPlayer", true, false)` inside each temporarily instanced `@*.fbx` scene

**Debug step needed:** Run the game and paste the Output panel content. The `[Player] '...' tracks:` lines will show the actual bone path prefix (e.g. `Armature/Skeleton:` vs `Skeleton:`). A mismatch between the base scene and loaded clips explains the stretching.

**Recommended next fix (in order of preference):**
1. **Re-export from Blender** — Open `assets/models/Liono.blend` and export one single `Liono.fbx` with all NLA tracks/actions baked in. Godot imports everything into one AnimationPlayer automatically. This is the cleanest solution and eliminates the multi-file problem entirely.
2. **Remap track paths at load time** — If re-export is not possible, read the track paths from the Output panel, compare them between `@Idle.fbx` and another clip, and remap them in `_load_clip()` using `anim.track_set_path(i, remapped_path)`.
3. **One instance per animation (swap-and-hide)** — Instance each `@*.fbx` as a child of Player, make all invisible, show only the active one each frame. Avoids AnimationPlayer merging entirely but is expensive.

---

### Issue 2 — Legs partially in the ground

**Symptom:** Liono's feet appear slightly below the floor surface.

**Cause:** The FBX model's visual origin may not be at foot level. The `KinematicBody` settles with its origin at y = 0 (floor level), and the Liono mesh node has no y offset.

**Fix:** In the Godot editor Inspector, select the `Player` node in the running scene, find `visual_y_offset` (an export var in `Player.gd`) and drag it up until the feet sit on the floor. Once the correct value is found, hard-code it into `Player.gd` as the default.

---

### Issue 3 — Camera has no wall-clipping protection

**Status:** Low priority for now. The current camera (plain `Camera` node offset 5 m along +Z from the pivot) works but will clip through walls when geometry is added in Phase 5.

**Fix when needed:** Wrap the Camera in a `SpringArm` node inside `CameraRig/CameraPivot`. Set `SpringArm.spring_length = 5.0` and make `Camera` a child with no extra offset. The SpringArm handles collision automatically.

---

## Assets

**Model:** `assets/models/Liono.fbx` — rigged character mesh + skeleton  
**Blender source:** `assets/models/Liono.blend`

**Animations** (each a separate FBX — all also copied to `godot/assets/models/`):

| File | State |
|---|---|
| `Liono@Idle.fbx` | Standing still |
| `Liono@Walk.fbx` | Unused in free-cam mode; kept for Z-target walking |
| `Liono@Run.fbx` | Default forward movement |
| `Liono@Jump.fbx` | One-shot airborne |
| `Liono@Walk-Backwards.fbx` | Z-target locked, moving back |
| `Liono@Left-Turn.fbx` | Z-target locked, strafing left |
| `Liono@Right-Turn.fbx` | Z-target locked, strafing right |
| `Liono@Start-Climbing-Ladder.fbx` | Transition onto ladder |
| `Liono@Climbing-Ladder.fbx` | Looping climb |
| `Liono@Climbing-To-Top.fbx` | Dismount at top |

---

## Input Mapping

| Action | Keyboard | Controller |
|---|---|---|
| `move_forward` | W | Left stick up |
| `move_backward` | S | Left stick down |
| `move_left` | A | Left stick left |
| `move_right` | D | Left stick right |
| `jump` | Space | A / Cross |
| `lock_on` | Tab | R / R3 |
| `cam_up` | Mouse Y- | Right stick up |
| `cam_down` | Mouse Y+ | Right stick down |
| `cam_left` | Mouse X- | Right stick left |
| `cam_right` | Mouse X+ | Right stick right |

Mouse captured on start; **Escape** toggles capture.

---

## File Map

```
godot/
  project.godot           — display, input actions, main scene
  assets/models/          — all FBX files (Liono.fbx + Liono@*.fbx)
  scenes/
    Player.tscn           — KinematicBody + CapsuleShape + Liono@Idle.fbx instance
  scripts/
    Player.gd             — movement, gravity, jump, animation loading + playback
    CameraRig.gd          — orbit camera, mouse/gamepad, Escape to uncapture
    GridFloor.gd          — procedural 64×64 checkerboard grid texture at runtime
  levels/
    Level01.tscn          — floor, lighting, WorldEnvironment (fog), Player + CameraRig
```

---

## Implementation Plan Detail

### Phase 1 — Project Configuration ✅

- project.godot: name, 800×600 display, stretch mode `2d`, aspect `keep`
- All input actions registered with keyboard + controller bindings
- Folder structure created

---

### Phase 2 — Import & Rig the Player ⚠️

**Intended design:**
- Visual base: instance `Liono@Idle.fbx` (guaranteed AnimationPlayer)
- Other clips loaded at runtime in `Player.gd _ready()` from each `@*.fbx`
- Loop flags set per-clip in code (`LOOPING` constant array)
- Animation driven by `_update_animation()` from velocity + lock-on state

**Current blocker:** See Issue 1 above.

**AnimationTree state machine (intended, not yet implemented):**
```
[Idle] <---> [Run]
               |
             [Jump]  (one-shot, returns to Idle/Run)

[Z-Target active]
  [Idle] <---> [Walk-Backwards]
           <---> [Left-Turn]
           <---> [Right-Turn]

[Climb]
  [Start-Climbing-Ladder] --> [Climbing-Ladder] --> [Climbing-To-Top] --> [Idle]
```

---

### Phase 3 — Player Scene & Controller ✅

**Scene tree (current):**
```
KinematicBody (Player)
  CollisionShape (CapsuleShape r=0.35 h=1.0, offset y=0.85)
  Liono (instance of Liono@Idle.fbx)
```

**Script behaviour:**
- Camera-relative WASD movement (fwd/right extracted from CameraPivot basis, y projected away)
- `TURN_SPEED = 12` lerp on Y rotation to face movement direction
- Gravity `−25`, jump impulse `+10`, `move_and_slide(velocity, UP)`
- Z-target active: character faces target, input becomes strafe/back
- `visual_y_offset` export var to tune model feet position in Inspector

---

### Phase 4 — Third-Person Camera ✅

**Scene tree (current, inside Level01.tscn):**
```
CameraRig (Spatial + CameraRig.gd)
  CameraPivot (Spatial)
    Camera  (transform offset 5 m along +Z)
```

**Behaviour:**
- `CameraRig` lerps to `player.origin + (0, 1.5, 0)` each physics frame
- Mouse X/Y → yaw/pitch on `CameraPivot`; pitch clamped −50°..−5°
- Right stick → `cam_left/right/up/down` actions at 90°/s
- Escape key toggles mouse capture

**Still needed:**
- SpringArm for wall-clip protection (Issue 3)
- Z-target camera behaviour (interpolate to frame player + target)

---

### Phase 5 — Placeholder Level 🔶

**Done:**
- 40 × 40 m floor with procedural grid texture (white/grey checker, grey grid lines)
- `DirectionalLight` (energy 1.4, rotation −55°/45°/0°)
- `WorldEnvironment`: background `#2E2E40`, ambient white at 1.0, fog 20–50 m

**Still needed:**
- 4 corner pillars (CSGBox)
- 1 raised platform with 2 steps (CSGBox)
- 1 simple ladder surface (CSGBox + Area trigger) for Phase 6
- 1 dummy Z-target Area (glowing sphere placeholder) near centre

---

### Phase 6 — Ladder Interaction ❌

- `Area` node tagged `ladder` placed over ladder mesh
- On overlap + `move_forward`: snap player to ladder axis, lock horizontal input
- Play `Start-Climbing-Ladder` (one-shot) → loop `Climbing-Ladder`
- Second `Area` at top triggers `Climbing-To-Top` → restore normal movement
- `move_backward` while on ladder = dismount

---

## Implementation Order (original)

| Step | Phase | Status |
|---|---|---|
| 1 | Phase 1 — Config | ✅ |
| 2 | Phase 3 — Movement | ✅ |
| 3 | Phase 4 — Camera | ✅ |
| 4 | Phase 2 — Animations | ⚠️ Blocked |
| 5 | Phase 5 — Level geometry | 🔶 Partial |
| 6 | Phase 6 — Ladder | ❌ |

---

## Out of Scope for This Demo

- Combat system (sword swing, hit detection)
- Sound effects / music
- UI / HUD (health hearts, lock-on reticle)
- Multiple levels / doors
