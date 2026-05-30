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
| Phase 2 — Animations | ⚠️ Blocked | FBX re-exports still stretch/flicker; T-pose only for now |
| Phase 3 — Player movement | ✅ Done | WASD + gravity + jump working |
| Phase 4 — Camera | ✅ Done | Orbit camera; SpringArm not yet added |
| Phase 5 — Level | 🔶 Partial | Floor + lighting balanced; geometry not yet added |
| Phase 6 — Ladder | ❌ Not started | |

---

## Open Issues

### Issue 1 — GLB scale + textures (IN PROGRESS)

FBX abandoned. Switched to GLB via **https://mixamo2gltf.com/** — combines Mixamo animations into a single GLB with all actions. Animations load correctly in Godot.

**Current workaround in `Player.gd`:** `visual.scale = Vector3(0.01, 0.01, 0.01)` — the GLB is exported at centimetre scale (unapplied Blender armature transform).

**Textures:** messed up in current export — GLB likely missing embedded textures.

**Proper fix (re-export from mixamo2gltf):**
1. In Blender: select Armature → `Ctrl+A → Apply All Transforms` before exporting, so scale is baked
2. GLB export: set Textures → `Automatic` (embed) to include textures in the `.glb`
3. Once fixed: remove `visual.scale` hack and re-tune `visual_y_offset`

**GLB structure (Godot 3 import):**
```
liono.glb
  Node2 (Spatial) — armature root; has z-offset 6.534 zeroed in code
    Skeleton
  AnimationPlayer — clip names: LionoIdle_3, LionoRun_7, LionoJump_4, etc.
```
Animation lookup uses keyword matching (`_find_anim`) so `"Idle"` → `"LionoIdle_3"` — robust to suffix changes on re-export.

---

### Issue 2 — Legs partially in the ground

**Status: RESOLVED.** `visual_y_offset` tuned to `0.5` in `Player.gd`.

---

### Issue 3 — Camera has no wall-clipping protection

**Status:** Low priority for now. The current camera (plain `Camera` node offset 5 m along +Z from the pivot) works but will clip through walls when geometry is added in Phase 5.

**Fix when needed:** Wrap the Camera in a `SpringArm` node inside `CameraRig/CameraPivot`. Set `SpringArm.spring_length = 5.0` and make `Camera` a child with no extra offset. The SpringArm handles collision automatically.

---

## Assets

**Model:** `assets/models/liono.glb` — all animations combined via https://mixamo2gltf.com/  
**Blender source:** `assets/models/Liono.blend`

**Animations (all in liono.glb):**

| Keyword | GLB clip name | Use |
|---|---|---|
| `Idle` | `LionoIdle_3` | Standing still |
| `Walk` | `LionoWalk_9` | Z-target walking |
| `Walking` | `LionoWalking_11` | Free-cam walk (if needed) |
| `Run` | `LionoRun_7` | Default movement |
| `Jump` | `LionoJump_4` | One-shot airborne |
| `Walk-Backwards` | `LionoWalk-Backwards_10` | Z-target back |
| `Left-Turn` | `LionoLeft-Turn_5` | Z-target strafe left |
| `Right-Turn` | `LionoRight-Turn_6` | Z-target strafe right |
| `Start-Climbing-Ladder` | `LionoStart-Climbing-Ladder_8` | Ladder entry |
| `Climbing-Ladder` | `LionoClimbing-Ladder_1` | Ladder loop |
| `Climbing-To-Top` | `LionoClimbing-To-Top_2` | Ladder dismount |

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

**Current design (swap-and-hide):**
- `Liono@Idle.fbx` instanced in scene tree as "Liono" — the Idle visual
- All other `@*.fbx` files instanced programmatically in `_ready()`, hidden
- `_play(name)` hides current node, shows new node, calls `ap.play(raw)` on it
- Loop flags set per-clip; Jump is one-shot; Idle/Run/Climbing loop
- Animation driven by `_update_animation()` from velocity + lock-on state

**No AnimationTree state machine yet — direct play() calls only.**
**State machine (for later, if needed):**
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
