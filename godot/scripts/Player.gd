extends KinematicBody

const SPEED := 7.0
const JUMP_IMPULSE := 10.0
const GRAVITY := -25.0
const TURN_SPEED := 12.0
const ANIM_BLEND := 0.15

# Adjust in the Inspector if the model floats or sinks into the floor.
export var visual_y_offset: float = 0.0

var velocity := Vector3.ZERO
var camera_pivot: Spatial = null
var lock_target: Spatial = null

var _anim: AnimationPlayer = null
var _current_anim := ""

# Clips that should loop continuously.
const LOOPING := ["Idle", "Walk", "Run", "Walk-Backwards", "Left-Turn", "Right-Turn", "Climbing-Ladder"]

# Each remaining animation loaded from its own FBX at startup.
const CLIP_FILES := {
	"Walk":                  "res://assets/models/Liono@Walk.fbx",
	"Run":                   "res://assets/models/Liono@Run.fbx",
	"Jump":                  "res://assets/models/Liono@Jump.fbx",
	"Walk-Backwards":        "res://assets/models/Liono@Walk-Backwards.fbx",
	"Left-Turn":             "res://assets/models/Liono@Left-Turn.fbx",
	"Right-Turn":            "res://assets/models/Liono@Right-Turn.fbx",
	"Start-Climbing-Ladder": "res://assets/models/Liono@Start-Climbing-Ladder.fbx",
	"Climbing-Ladder":       "res://assets/models/Liono@Climbing-Ladder.fbx",
	"Climbing-To-Top":       "res://assets/models/Liono@Climbing-To-Top.fbx",
}

func _ready() -> void:
	var visual := get_node_or_null("Liono") as Spatial
	if visual:
		visual.translation.y = visual_y_offset

	# The visual is Liono@Idle.fbx which already contains an AnimationPlayer.
	_anim = find_node("AnimationPlayer", true, false) as AnimationPlayer
	if not _anim:
		print("[Player] ERROR: no AnimationPlayer found")
		return

	print("[Player] AnimationPlayer at: ", _anim.get_path())
	print("[Player] Base clips: ", _anim.get_animation_list())

	# Normalise the existing clip to the logical name "Idle".
	_ensure_named("Idle")

	# Load every other clip from its own FBX file.
	for logical_name in CLIP_FILES:
		_load_clip(logical_name, CLIP_FILES[logical_name])

	# Apply loop flags.
	for clip in _anim.get_animation_list():
		var anim := _anim.get_animation(clip)
		anim.loop = clip in LOOPING

	print("[Player] Ready. Clips: ", _anim.get_animation_list())
	_play("Idle")

# If the AnimationPlayer already has the clip under a different raw name, rename it.
func _ensure_named(desired: String) -> void:
	if _anim.has_animation(desired):
		return
	for raw in _anim.get_animation_list():
		if raw == "RESET":
			continue
		var anim := _anim.get_animation(raw)
		_anim.add_animation(desired, anim)
		_anim.remove_animation(raw)
		print("[Player] Renamed '", raw, "' -> '", desired, "'")
		return

# Load the first non-RESET animation from a FBX scene and store it under a logical name.
func _load_clip(desired: String, path: String) -> void:
	var scene: PackedScene = load(path) as PackedScene
	if not scene:
		print("[Player] Could not load: ", path)
		return
	var inst := scene.instance()
	var ap := inst.find_node("AnimationPlayer", true, false) as AnimationPlayer
	if not ap:
		print("[Player] No AnimationPlayer in: ", path)
		inst.free()
		return
	for raw in ap.get_animation_list():
		if raw == "RESET":
			continue
		var anim := ap.get_animation(raw)
		if _anim.has_animation(desired):
			_anim.remove_animation(desired)
		_anim.add_animation(desired, anim)
		print("[Player] Loaded '", raw, "' as '", desired, "'")
		break
	inst.free()

func _play(name: String) -> void:
	if _anim == null or _current_anim == name:
		return
	if not _anim.has_animation(name):
		return
	_anim.play(name, ANIM_BLEND)
	_current_anim = name

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	var input := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward")
	)
	if input.length() > 1.0:
		input = input.normalized()

	var move := Vector3.ZERO

	if lock_target != null:
		var to_target := lock_target.global_transform.origin - global_transform.origin
		to_target.y = 0.0
		if to_target.length() > 0.1:
			rotation.y = lerp_angle(rotation.y, atan2(to_target.x, to_target.z), TURN_SPEED * delta)
		move = -global_transform.basis.z * -input.y + global_transform.basis.x * input.x
	elif camera_pivot != null and input.length() > 0.05:
		var fwd := -camera_pivot.global_transform.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var right := camera_pivot.global_transform.basis.x
		right.y = 0.0
		right = right.normalized()
		move = fwd * -input.y + right * input.x
		rotation.y = lerp_angle(rotation.y, atan2(move.x, move.z), TURN_SPEED * delta)

	velocity.x = move.x * SPEED
	velocity.z = move.z * SPEED

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_IMPULSE

	velocity = move_and_slide(velocity, Vector3.UP)
	_update_animation(input)

func _update_animation(input: Vector2) -> void:
	if not is_on_floor():
		_play("Jump")
		return
	if lock_target != null:
		if input.length() < 0.05:
			_play("Idle")
		elif input.y < -0.3:
			_play("Walk-Backwards")
		elif input.x < -0.3:
			_play("Left-Turn")
		elif input.x > 0.3:
			_play("Right-Turn")
		else:
			_play("Idle")
	else:
		_play("Run" if input.length() > 0.05 else "Idle")
