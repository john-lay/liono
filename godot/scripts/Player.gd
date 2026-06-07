extends KinematicBody

const SPEED := 7.0
const LOCK_SPEED := 3.5
const JUMP_IMPULSE := 10.0
const GRAVITY := -25.0
const TURN_SPEED := 12.0

export var visual_y_offset: float = 0.0
export var hand_sword_pos := Vector3(0.0, 0.0, 0.0)
export var hand_sword_rot := Vector3(0.0, 0.0, 0.0)

var velocity := Vector3.ZERO
var camera_pivot: Spatial = null

var _anim: AnimationPlayer = null
var _current_anim := ""
var _visual: Spatial = null
var _is_jumping := false
var lock_target: Spatial = null
var _sword_holster: MeshInstance = null
var _hand_sword: Spatial = null
var _skeleton: Skeleton = null
var _hand_bone_idx := -1
var _is_attacking := false

func _ready() -> void:
	VisualServer.set_debug_generate_wireframes(true)
	var canvas := CanvasLayer.new()
	var cb := CheckBox.new()
	cb.text = "Wireframe"
	cb.rect_position = Vector2(8, 8)
	cb.connect("toggled", self, "_on_wireframe_toggled")
	canvas.add_child(cb)
	add_child(canvas)

	_visual = get_node_or_null("Liono") as Spatial
	if _visual:
		_visual.translation.y = visual_y_offset

	_anim = find_node("AnimationPlayer", true, false) as AnimationPlayer
	if _anim:
		_loop_all_clips()
		_anim.connect("animation_finished", self, "_on_animation_finished")
		_play("Idle")
	else:
		print("[Player] ERROR: no AnimationPlayer found")

	_sword_holster = find_node("Sword", true, false) as MeshInstance
	call_deferred("_setup_hand_sword")

func _setup_hand_sword() -> void:
	_skeleton = find_node("Skeleton", true, false) as Skeleton
	if not _skeleton:
		print("[Player] WARNING: no Skeleton found")
		return
	_hand_bone_idx = _skeleton.find_bone("mixamorig_RightHand")
	if _hand_bone_idx == -1:
		print("[Player] WARNING: RightHand bone not found")
		return
	var sword_scene := load("res://assets/models/Sword.glb") as PackedScene
	if sword_scene == null:
		print("[Player] WARNING: Sword.glb not found at res://assets/models/Sword.glb")
		return
	_hand_sword = sword_scene.instance()
	_hand_sword.visible = false
	add_child(_hand_sword)

func _on_animation_finished(anim_name: String) -> void:
	if "slash" in anim_name.to_lower():
		_is_attacking = false
		_current_anim = ""
		if _sword_holster:
			_sword_holster.visible = true
		if _hand_sword:
			_hand_sword.visible = false

func _loop_all_clips() -> void:
	for clip in _anim.get_animation_list():
		var lower = clip.to_lower()
		_anim.get_animation(clip).loop = not ("jump" in lower or "start" in lower or "to-top" in lower or "slash" in lower)

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

func _start_attack() -> void:
	_is_attacking = true
	_current_anim = ""
	if _sword_holster:
		_sword_holster.visible = false
	if _hand_sword:
		_hand_sword.visible = true
	_play("Slash")

func _on_wireframe_toggled(pressed: bool) -> void:
	get_viewport().debug_draw = Viewport.DEBUG_DRAW_WIREFRAME if pressed else Viewport.DEBUG_DRAW_DISABLED

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

	if Input.is_action_just_pressed("lock_on") and not _is_attacking:
		_toggle_lock()

	if Input.is_action_just_pressed("attack") and is_on_floor() and not _is_attacking and not _is_jumping:
		_start_attack()

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

	if Input.is_action_just_pressed("jump") and is_on_floor() and not _is_attacking:
		velocity.y = JUMP_IMPULSE

	velocity = move_and_slide(velocity, Vector3.UP)
	_update_animation(input)

	if _hand_sword != null and _skeleton != null and _hand_bone_idx >= 0:
		var bone_xform: Transform = _skeleton.global_transform * _skeleton.get_bone_global_pose(_hand_bone_idx)
		var rot := Basis()
		rot = rot.rotated(Vector3.RIGHT, deg2rad(hand_sword_rot.x))
		rot = rot.rotated(Vector3.UP, deg2rad(hand_sword_rot.y))
		rot = rot.rotated(Vector3.BACK, deg2rad(hand_sword_rot.z))
		_hand_sword.global_transform = bone_xform * Transform(rot, hand_sword_pos)

func _update_animation(input: Vector2) -> void:
	if is_on_floor():
		_is_jumping = false
	elif abs(velocity.y) > 2.0:
		_is_jumping = true
	if _is_attacking:
		return
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
