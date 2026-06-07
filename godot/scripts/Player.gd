extends KinematicBody

const SPEED := 7.0
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
		var lower := clip.to_lower()
		var one_shot := "jump" in lower or "start" in lower or "to-top" in lower
		_anim.get_animation(clip).loop = not one_shot

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
	if camera_pivot != null and input.length() > 0.05:
		var fwd := -camera_pivot.global_transform.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var right := camera_pivot.global_transform.basis.x
		right.y = 0.0
		right = right.normalized()
		move = fwd * -input.y + right * input.x
		var target_angle := atan2(move.x, move.z)
		if _visual:
			_visual.rotation.y = lerp_angle(_visual.rotation.y, target_angle, TURN_SPEED * delta)

	velocity.x = move.x * SPEED
	velocity.z = move.z * SPEED

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
	_play("Walk" if input.length() > 0.05 else "Idle")
