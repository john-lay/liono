extends KinematicBody

const SPEED := 7.0
const LOCK_SPEED := 3.5
const JUMP_IMPULSE := 10.0
const GRAVITY := -25.0
const TURN_SPEED := 12.0

export var visual_y_offset: float = 0.0

var velocity := Vector3.ZERO
var camera_pivot: Spatial = null

var _anim: AnimationPlayer = null
var _current_anim := ""
var _visual: Spatial = null
var _is_jumping := false
var lock_target: Spatial = null

func _ready() -> void:
	_visual = get_node_or_null("Liono") as Spatial
	if _visual:
		_visual.translation.y = visual_y_offset

	_anim = find_node("AnimationPlayer", true, false) as AnimationPlayer
	if _anim:
		_loop_all_clips()
		_play("Idle")
	else:
		print("[Player] ERROR: no AnimationPlayer found")

func _loop_all_clips() -> void:
	for clip in _anim.get_animation_list():
		var lower = clip.to_lower()
		_anim.get_animation(clip).loop = not ("jump" in lower or "start" in lower or "to-top" in lower)

func _find_anim(keyword: String) -> String:
	if _anim == null:
		return ""
	var kw := keyword.to_lower()
	var partial := ""
	for anim_name in _anim.get_animation_list():
		if anim_name.to_lower() == kw:
			return anim_name
		if partial == "" and kw in anim_name.to_lower():
			partial = anim_name
	return partial

func _play(keyword: String) -> void:
	if _anim == null or _current_anim == keyword:
		return
	var anim_name := _find_anim(keyword)
	if anim_name == "":
		return
	_anim.play(anim_name)
	_current_anim = keyword

func _toggle_lock() -> void:
	if lock_target != null:
		lock_target = null
		return
	var best_dist := 15.0
	for node in get_tree().get_nodes_in_group("z_target"):
		var d = global_transform.origin.distance_to(node.global_transform.origin)
		if d < best_dist:
			best_dist = d
			lock_target = node

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if Input.is_action_just_pressed("lock_on"):
		_toggle_lock()

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
		if to_target.length() > 0.01:
			var fwd := to_target.normalized()
			var right := fwd.cross(Vector3.UP).normalized()
			move = fwd * -input.y + right * input.x
			if _visual:
				_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(fwd.x, fwd.z), TURN_SPEED * delta)
	elif camera_pivot != null and input.length() > 0.05:
		var fwd := -camera_pivot.global_transform.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var right := camera_pivot.global_transform.basis.x
		right.y = 0.0
		right = right.normalized()
		move = fwd * -input.y + right * input.x
		if _visual:
			_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(move.x, move.z), TURN_SPEED * delta)

	var speed := LOCK_SPEED if lock_target != null else SPEED
	velocity.x = move.x * speed
	velocity.z = move.z * speed

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_IMPULSE

	velocity = move_and_slide(velocity, Vector3.UP)
	_update_animation(input)

func _update_animation(input: Vector2) -> void:
	if is_on_floor():
		_is_jumping = false
	elif abs(velocity.y) > 2.0:
		_is_jumping = true
	if _is_jumping:
		_play("Jump")
		return
	if lock_target != null:
		_update_locked_animation(input)
		return
	_play("Walk" if input.length() > 0.05 else "Idle")

func _update_locked_animation(input: Vector2) -> void:
	if input.length() <= 0.05:
		_play("Idle")
	elif input.y > 0.05:
		_play("Walk-Backwards")
	elif input.x < -0.05:
		_play("Left-Turn-Lock")
	elif input.x > 0.05:
		_play("Right-Turn-Lock")
	else:
		_play("Walk-Lock")
