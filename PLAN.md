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
| Phase 2 — Animations | ⏸️ Paused | Capsule placeholder in use; model export issues unresolved |
| Phase 3 — Player movement | ✅ Done | WASD + gravity + jump working |
| Phase 4 — Camera | ✅ Done | Orbit camera; SpringArm not yet added |
| Phase 5 — Level | 🔶 Partial | Floor + lighting balanced; geometry not yet added |
| Phase 6 — Ladder | ❌ Not started | |

---

## Open Issues

### Issue 1 — Model export (PAUSED)

Animation work is paused. `godot/assets/` has been cleared. Player uses a capsule `MeshInstance` placeholder. No animation code in `Player.gd`.

**Root cause of previous stretching:** Unapplied Blender armature transform. The armature object had a `0.01` scale at the object level (cm scale from Mixamo), never baked via `Ctrl+A → Apply All Transforms`. Godot's FBX importer couldn't propagate this correctly through the bone hierarchy, causing vertex stretching. GLB handled the scale without corrupting skinning but still imported at 100× size.

**Additional GLB issues observed:**
- Model origin not at feet — large Y offset on import
- Idle animation had root motion on the Hips bone (Blender Y = Godot Z), causing the character to jump along Z during playback

**Proper fix before re-importing:**
1. In Blender: select Armature → `Ctrl+A → Apply All Transforms`, verify Scale = `(1,1,1)` in N panel
2. Set armature origin to feet: `Shift+S → Cursor to World Origin`, then `Object → Set Origin → Origin to 3D Cursor`
3. In the idle action: open Graph Editor, select Hips bone, delete Y Location keyframes (root motion)
4. Re-export via mixamo2gltf.com with Textures → `Automatic` (embedded)
5. Re-add `MeshInstance` → AnimationPlayer wiring in `Player.gd` (see animation state machine below)

---

### Issue 2 — Camera has no wall-clipping protection

---

### Issue 3 — Camera has no wall-clipping protection

**Status:** Low priority for now. The current camera (plain `Camera` node offset 5 m along +Z from the pivot) works but will clip through walls when geometry is added in Phase 5.

**Fix when needed:** Wrap the Camera in a `SpringArm` node inside `CameraRig/CameraPivot`. Set `SpringArm.spring_length = 5.0` and make `Camera` a child with no extra offset. The SpringArm handles collision automatically.

---

## Assets

**Model:** `assets/models/Liono.blend` — Blender source (FBX + GLB exports pending fix; see Issue 1)  
**Placeholder:** capsule `MeshInstance` inline in `Player.tscn` (no external asset)

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
  assets/                 — empty; model assets cleared pending Blender fix (see Issue 1)
  scenes/
    Player.tscn           — KinematicBody + CapsuleShape + CapsuleMesh placeholder
  scripts/
    Player.gd             — movement, gravity, jump (no animation code)
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

### Phase 2 — Import & Rig the Player ⏸️

**Current state:** capsule placeholder. No model or animation code. Unblocked once Blender export is fixed (see Issue 1).

**Planned design when model is ready:**
- Single `liono.glb` (all animations) instanced as child of Player
- `AnimationPlayer` found via `find_node`; clip lookup by keyword (`_find_anim`) so suffix changes on re-export don't break it
- Direct `AnimationPlayer.play()` calls — no AnimationTree state machine needed yet

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
  Visual (MeshInstance — CapsuleMesh r=0.35 h=1.0, offset y=0.85)
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
| 4 | Phase 2 — Animations | ⚠️ Blocked |
| 5 | Phase 5 — Level geometry | 🔶 Partial |
| 6 | Phase 6 — Ladder | ❌ |

---

## Out of Scope for This Demo

- Combat system (sword swing, hit detection)
- Sound effects / music
- UI / HUD (health hearts, lock-on reticle)
- Multiple levels / doors
