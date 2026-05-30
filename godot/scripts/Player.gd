extends KinematicBody

const SPEED := 7.0
const JUMP_IMPULSE := 10.0
const GRAVITY := -25.0
const TURN_SPEED := 12.0
const ANIM_BLEND := 0.15

var velocity := Vector3.ZERO
var camera_pivot: Spatial = null
var lock_target: Spatial = null

var _anim: AnimationPlayer = null
var _current_anim := ""

func _ready() -> void:
	_anim = _find_animation_player(self)

# Walk the subtree to find the AnimationPlayer regardless of FBX import structure.
func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var result := _find_animation_player(child)
		if result:
			return result
	return null

# Blender FBX exports sometimes prefix animation names with the armature name.
func _resolve_anim(name: String) -> String:
	if _anim.has_animation(name):
		return name
	for prefix in ["Armature|", "Liono|", "mixamorig:"]:
		if _anim.has_animation(prefix + name):
			return prefix + name
	return name

func _play(name: String) -> void:
	if _anim == null or _current_anim == name:
		return
	var resolved := _resolve_anim(name)
	if not _anim.has_animation(resolved):
		return
	_anim.play(resolved, ANIM_BLEND)
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
