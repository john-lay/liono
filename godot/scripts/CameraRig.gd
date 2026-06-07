extends Spatial

export var target_path: NodePath
export var follow_speed := 8.0
export var mouse_sensitivity := 0.15
export var joy_sensitivity := 90.0
export(float) var pitch_min := -50.0
export(float) var pitch_max := -5.0

var yaw := 180.0
var pitch := -25.0
var _player: KinematicBody = null

onready var pivot: Spatial = $CameraPivot

func _ready() -> void:
	if target_path:
		_player = get_node(target_path)
		_player.camera_pivot = pivot
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if _player == null or _player.lock_target == null:
			yaw -= event.relative.x * mouse_sensitivity
			pitch -= event.relative.y * mouse_sensitivity
			pitch = clamp(pitch, pitch_min, pitch_max)
	if event is InputEventKey and event.pressed and event.scancode == KEY_ESCAPE:
		var captured := Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if captured else Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	if _player:
		var target_pos := _player.global_transform.origin + Vector3(0.0, 1.5, 0.0)
		global_transform.origin = global_transform.origin.linear_interpolate(target_pos, follow_speed * delta)

	if _player != null and _player.lock_target != null:
		var to_target: Vector3 = _player.lock_target.global_transform.origin - _player.global_transform.origin
		to_target.y = 0.0
		if to_target.length() > 0.01:
			var target_yaw := rad2deg(atan2(-to_target.x, -to_target.z))
			yaw = rad2deg(lerp_angle(deg2rad(yaw), deg2rad(target_yaw), delta * 6.0))
	else:
		var joy_x := Input.get_action_strength("cam_right") - Input.get_action_strength("cam_left")
		var joy_y := Input.get_action_strength("cam_down") - Input.get_action_strength("cam_up")
		yaw -= joy_x * joy_sensitivity * delta
		pitch -= joy_y * joy_sensitivity * delta
		pitch = clamp(pitch, pitch_min, pitch_max)

	pivot.rotation_degrees.y = yaw
	pivot.rotation_degrees.x = pitch
