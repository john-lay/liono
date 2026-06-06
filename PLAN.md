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
| Phase 2 — Animations | 🔶 Partial | 8 clips in GLB; Climbing-To-Top FBX not yet sourced |
| Phase 3 — Player movement | ✅ Done | WASD + gravity + jump; visual rotates independently of physics body |
| Phase 4 — Camera | ✅ Done | Orbit camera; SpringArm not yet added |
| Phase 5 — Level | 🔶 Partial | Floor + lighting balanced; geometry not yet added |
| Phase 6 — Ladder | ❌ Not started | |

---

## Open Issues

### Issue 1 — Climbing-To-Top animation missing

8 of 9 planned clips are in `liono.glb`. The final clip, `Climbing-To-Top` (ladder dismount), has not yet been sourced from Mixamo. Once the FBX is placed in `assets/models/FBX 2013/`, add it to `EXTRA_ANIMS` in `export_glb.py` and re-run the export.

---

### Issue 2 — Camera has no wall-clipping protection

**Status:** Low priority for now. The current camera (plain `Camera` node offset 5 m along +Z from the pivot) works but will clip through walls when geometry is added in Phase 5.

**Fix when needed:** Wrap the Camera in a `SpringArm` node inside `CameraRig/CameraPivot`. Set `SpringArm.spring_length = 5.0` and make `Camera` a child with no extra offset. The SpringArm handles collision automatically.

---

## Assets

**Model:** `assets/models/Liono.blend` — Blender source  
**Export script:** `tools/export_glb.py` — headless Blender pipeline (run via CLI, see below)  
**GLB output:** `godot/assets/models/liono.glb` — embedded textures, 8 animation clips

**Animations in liono.glb (keyword matched by Player.gd `_find_anim`):**

| Keyword | Use | Status |
|---|---|---|
| `Idle` | Standing still | ✅ |
| `Walk` | Free movement | ✅ |
| `Walk-Backwards` | Z-target back | ✅ |
| `Left-Turn` | Z-target strafe left | ✅ |
| `Right-Turn` | Z-target strafe right | ✅ |
| `Jump` | One-shot airborne | ✅ |
| `Start-Climbing-Ladder` | Ladder entry (one-shot) | ✅ |
| `Climbing-Ladder` | Ladder loop | ✅ |
| `Climbing-To-Top` | Ladder dismount (one-shot) | ❌ FBX missing |

**To re-export the GLB:**
```
"D:\Program Files\Blender Foundation\Blender 2.91\blender.exe" --background --python D:/Repo/liono/tools/export_glb.py
```

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
  project.godot               — display, input actions, main scene
  assets/models/liono.glb     — exported character model (textures embedded, Idle animation)
  scenes/
    Player.tscn               — KinematicBody + CapsuleShape + liono.glb instance
  scripts/
    Player.gd                 — movement, gravity, jump, animation state, visual rotation
    CameraRig.gd              — orbit camera, mouse/gamepad, Escape to uncapture
    GridFloor.gd              — procedural 64×64 checkerboard grid texture at runtime
  levels/
    Level01.tscn              — floor, lighting, WorldEnvironment (fog), Player + CameraRig
assets/
  models/Liono.blend          — Blender source
  models/FBX 2013/           — Mixamo source FBX animations (8 clips; Climbing-To-Top missing)
  textures/                   — PNG texture maps (body, hair, eye, claw, sword)
tools/
  export_glb.py               — headless Blender export pipeline
```

---

## Implementation Plan Detail

### Phase 1 — Project Configuration ✅

- project.godot: name, 800×600 display, stretch mode `2d`, aspect `keep`
- All input actions registered with keyboard + controller bindings
- Folder structure created

---

### Phase 2 — Import & Rig the Player 🔶

**Current state:** `liono.glb` in-game with 8 animation clips. Climbing-To-Top FBX not yet sourced (see Issue 1).

**Pipeline:** headless Blender Python script (`tools/export_glb.py`) handles all transforms:
- Imports Idle.fbx as base mesh + skeleton; imports remaining FBXs for actions only
- Applies armature scale (0.01, cm→m) and FBX rotation correction
- Centers character in XZ using skeleton bone bounding box (was 3.2 m off-centre, causing visual orbit)
- Lifts rig so toes sit at Y = 0
- Strips Hips location FCurves from all actions (removes Mixamo root-motion jump)
- Pushes all actions into NLA tracks; exports via `export_nla_strips=True`
- Assigns PNG textures via Principled BSDF nodes
- Exports to `godot/assets/models/liono.glb`

**Design:**
- Single `liono.glb` (all animations) instanced as "Liono" child of Player
- `AnimationPlayer` found via `find_node`; clip lookup via `_find_anim` — exact match preferred, substring fallback
- All clips loop except Jump and any one-shot transitions (glTF carries no loop flag; set at runtime)
- `_is_jumping` latch holds Jump state through velocity apex dead zone; clears on `is_on_floor()`
- Visual child (`_visual`) rotates independently of the KinematicBody (avoids arc caused by offset origin)
- `visual_y_offset = 0.5` set in Level01.tscn inspector to tune feet-to-floor alignment

**State machine (for later, if needed):**
```
[Idle] <---> [Walk]
               |
             [Jump]  (one-shot, returns to Idle/Walk)

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
  Liono (liono.glb instance — visual only, no physics)
```

**Script behaviour:**
- Camera-relative WASD movement (fwd/right extracted from CameraPivot basis, y projected away)
- `TURN_SPEED = 12` lerp on Y rotation to face movement direction
- Gravity `−25`, jump impulse `+10`, `move_and_slide(velocity, UP)`
- Z-target active: character faces target, input becomes strafe/back

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
| 4 | Phase 2 — Animations | 🔶 Partial |
| 5 | Phase 5 — Level geometry | 🔶 Partial |
| 6 | Phase 6 — Ladder | ❌ |

---

## Out of Scope for This Demo

- Combat system (sword swing, hit detection)
- Sound effects / music
- UI / HUD (health hearts, lock-on reticle)
- Multiple levels / doors
