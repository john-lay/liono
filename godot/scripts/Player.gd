extends KinematicBody

const SPEED := 7.0
const JUMP_IMPULSE := 10.0
const GRAVITY := -25.0
const TURN_SPEED := 12.0

var velocity := Vector3.ZERO
var camera_pivot: Spatial = null

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
		rotation.y = lerp_angle(rotation.y, atan2(move.x, move.z), TURN_SPEED * delta)

	velocity.x = move.x * SPEED
	velocity.z = move.z * SPEED

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_IMPULSE

	velocity = move_and_slide(velocity, Vector3.UP)
