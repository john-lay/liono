# Liono — N64-Style Action Adventure Demo

## Overview

A short playable demo in the style of Zelda: Ocarina of Time, built in Godot 3.x and exported as a WebGL app. The game features a single placeholder level with a third-person camera, Z-targeting, and full character animation.

---

## Technical Constraints

| Setting | Value |
|---|---|
| Engine | Godot 3.x |
| Renderer | GLES2 (WebGL 1.0 compatible) |
| Export target | HTML5 (web) |
| Resolution | 800 × 600 |
| Stretch mode | `2d` / keep aspect |
| Movement | Always run (no walk toggle) |

---

## Assets

**Model:** `assets/models/Liono.fbx` — rigged character mesh + skeleton

**Animations** (each a separate FBX):

| File | State |
|---|---|
| `Liono@Idle.fbx` | Standing still |
| `Liono@Walk.fbx` | Used for free-camera backwards/slow movement |
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

---

## Implementation Plan

### Phase 1 — Project Configuration

- Rename project to "Liono" in `project.godot`
- Set display resolution to 800 × 600, stretch mode `2d`, aspect `keep`
- Register all input actions listed above
- Create folder structure:
  ```
  godot/
    scenes/
    scripts/
    materials/
    levels/
  ```

---

### Phase 2 — Import & Rig the Player

- Import `Liono.fbx` as the base scene (mesh + skeleton); save as `scenes/Liono.tscn`
- Import each `Liono@*.fbx` — set import mode to **Animation only**, retargeting to Liono's skeleton
- Add an `AnimationPlayer` node and load all imported animation clips
- Build an `AnimationTree` with an `AnimationNodeStateMachine`:

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

- Wire AnimationTree parameters to exported script variables for runtime control

---

### Phase 3 — Player Scene & Controller

**Scene tree:**
```
KinematicBody (Player)
  MeshInstance (Liono mesh)
  Skeleton
  AnimationPlayer
  AnimationTree
  CollisionShape (CapsuleShape)
  RayCast (ground check / step detection)
```

**Script (`scripts/Player.gd`) behaviour:**
- Read input vector from `move_*` actions; normalise
- Rotate input vector relative to camera's Y-axis so movement is always camera-relative
- Apply gravity each physics frame; set vertical velocity to jump impulse on `jump` press when grounded
- Call `move_and_slide(velocity, Vector3.UP)` each frame
- Smoothly rotate the character mesh to face the movement direction (lerp on Y-axis)
- When Z-target is active: character faces the target; left/right input strafes; back input walks backwards
- Drive AnimationTree parameters from velocity magnitude and Z-target state

---

### Phase 4 — Third-Person Camera

**Scene tree (child of a `Position3D` that follows the player):**
```
Position3D (CameraRig — follows player position)
  Spatial (CameraPivot — rotated by mouse/stick input)
    SpringArm
      Camera
```

**Behaviour:**
- `CameraRig` position lerps toward player's global position each frame
- `CameraPivot` Y rotation updated by `cam_left` / `cam_right` input; X rotation clamped to roughly –10°..–50° (always looking slightly down)
- `SpringArm` length ~5 m; collision mask excludes player; Camera sits at the end
- **Z-targeting:** on `lock_on` press, cast a sphere overlap from the player, pick the nearest `Area` node in the `target` group
  - While locked: `CameraPivot` interpolates to keep both player and target visible
  - On re-press or target out-of-range: release lock and return camera to free mode
  - Dummy target is a plain `Spatial` node with an `Area` + small `MeshInstance` (glowing sphere placeholder) placed in the level

---

### Phase 5 — Placeholder Level

**Scene:** `levels/Level01.tscn`

**Floor:**
- Large `MeshInstance` (PlaneMesh, 40 × 40 m)
- `SpatialMaterial`: albedo = white, unshaded (`flags_unshaded = true`), albedo texture = a simple 1 m grey-line grid texture (generated via `ImageTexture` or imported PNG); UV scale tiled across the plane

**Placeholder geometry (CSGBox / MeshInstance):**
- 4 tall pillar boxes at corners
- A raised platform in one corner (2 steps of CSGBox)
- A simple ladder volume (thin CSGBox + trigger `Area`) on one platform face to test the climb chain
- One dummy Z-target `Area` floating at eye level near the centre

**Environment (`WorldEnvironment`):**
- Background: solid dark grey / very dark blue
- Ambient light: low, slightly warm
- Fog: enabled; start ~15 m, end ~40 m; colour matches background — recreates the N64 draw-distance haze

**Sky:** none (fog occludes it entirely)

---

### Phase 6 — Ladder Interaction

- `Area` node tagged `ladder` placed over the ladder mesh, sized to its climbable face
- When player overlaps the area and presses `move_forward`:
  - Snap player X/Z to ladder centre axis
  - Lock horizontal input; vertical input maps to climb speed
  - Play `Start-Climbing-Ladder` (one-shot), then loop `Climbing-Ladder`
  - When player reaches the top trigger (second small `Area`), play `Climbing-To-Top`, then re-enable normal movement
- Pressing `move_backward` while climbing dismounts back to ground

---

## Implementation Order

| Step | Phase | Why |
|---|---|---|
| 1 | Phase 1 | Inputs and folders are needed before any scene work |
| 2 | Phase 3 (movement only, no animation) | Get the character moving in 3D space first |
| 3 | Phase 4 (camera) | Movement is disorienting without a working camera |
| 4 | Phase 2 (import + AnimationTree) | Add visual fidelity once movement feels right |
| 5 | Phase 5 (level) | Give the character a world to explore |
| 6 | Phase 6 (ladder) | Interaction layer on top of a working foundation |

---

## Open Questions / Future Scope

- Combat system (sword swing, hit detection) — not in scope for this demo
- Sound effects / music — deferred
- UI / HUD (health hearts, target lock reticle) — can be added after Phase 6
- Multiple levels / doors — deferred
