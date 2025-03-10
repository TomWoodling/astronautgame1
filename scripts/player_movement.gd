extends CharacterBody3D

@export_group("Astronaut Movement")
@export var walk_speed: float = 4.0
@export var run_multiplier: float = 1.75
@export var acceleration: float = 5.0
@export var friction: float = 2.0
@export var rotation_speed: float = 4.0
@export var rotation_acceleration: float = 8.0
@export var rotation_deceleration: float = 4.0

@export_group("Lunar Jump Parameters")
@export var jump_strength: float = 12.0
@export var jump_horizontal_force: float = 4.0
@export var air_damping: float = 0.25
@export var gravity: float = 5.0
@export var max_fall_speed: float = 15.0
@export var air_control: float = 0.6
@export var air_brake: float = 0.15
@export var landing_cushion: float = 2.0
const JUMP_DURATION: float = 0.6

# Node references
@onready var camera_rig: Node3D = $CameraRig
@onready var mesh: Node3D = $meshy_snaut

# Movement state
var move_direction: Vector3 = Vector3.ZERO
var camera_basis: Basis = Basis.IDENTITY
var target_basis: Basis = Basis.IDENTITY
var current_rotation_speed: float = 0.0
var was_in_air: bool = false
var landing_velocity: float = 0.0
var current_speed: float = 0.0

# Jump state
var jump_time: float = 0.0
var is_jumping: bool = false
var can_jump: bool = true

func _ready() -> void:
	assert(camera_rig != null, "Camera rig node not found!")
	assert(mesh != null, "Mesh node not found!")
	
	if camera_rig.has_signal("camera_rotated"):
		camera_rig.connect("camera_rotated", _on_camera_rotated)

func _on_camera_rotated(new_basis: Basis) -> void:
	camera_basis = new_basis

func _physics_process(delta: float) -> void:
	if not GameManager.can_player_move():
		return
		
	var on_floor = is_on_floor()
	
	# Handle landing and jump reset
	if was_in_air and on_floor:
		_handle_landing()
		can_jump = true
		is_jumping = false
		jump_time = 0.0
	was_in_air = !on_floor
	
	# Jump and gravity handling
	if Input.is_action_just_pressed("jump") and can_jump and on_floor:
		is_jumping = true
		can_jump = false
		jump_time = 0.0
		velocity.y = jump_strength * 0.5  # Initial boost
		_apply_jump_horizontal_momentum()
	
	if is_jumping:
		jump_time += delta
		if jump_time >= JUMP_DURATION:
			is_jumping = false
		else:
			var jump_curve = 1.0 - ease(jump_time / JUMP_DURATION, -1.8)
			velocity.y = jump_strength * jump_curve * 2.0
	elif !on_floor:
		landing_velocity = velocity.y
		velocity.y = move_toward(velocity.y, -max_fall_speed, gravity * delta)
	
	_handle_movement(delta, on_floor)
	move_and_slide()

func _handle_movement(delta: float, on_floor: bool) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var is_running = Input.is_action_pressed("run")
	
	# Movement direction calculation
	move_direction = Vector3.ZERO
	if input_dir != Vector2.ZERO:
		move_direction = _calculate_move_direction(input_dir)
		_handle_rotation(delta, on_floor)
	else:
		current_rotation_speed = move_toward(
			current_rotation_speed,
			0.0,
			rotation_deceleration * delta
		)
	
	# Apply rotation to mesh
	if current_rotation_speed > 0.0:
		var interpolation_factor = current_rotation_speed * delta
		var new_basis = mesh.transform.basis.slerp(target_basis, interpolation_factor)
		mesh.transform.basis = new_basis.orthonormalized()
	
	# Calculate and apply velocity
	var target_speed = walk_speed * (run_multiplier if is_running else 1.0)
	current_speed = move_toward(current_speed, target_speed, acceleration * delta)
	var target_velocity = move_direction * current_speed
	
	_apply_movement(target_velocity, delta, on_floor)

func _calculate_move_direction(input_dir: Vector2) -> Vector3:
	var forward = camera_basis.z
	forward.y = 0
	forward = forward.normalized()
	
	var right = camera_basis.x
	right.y = 0
	right = right.normalized()
	
	return (forward * input_dir.y + right * input_dir.x).normalized()

func _handle_rotation(delta: float, on_floor: bool) -> void:
	target_basis = Basis.looking_at(move_direction)
	var current_rotation_acceleration = rotation_acceleration
	if !on_floor:
		current_rotation_acceleration *= air_control
	
	current_rotation_speed = move_toward(
		current_rotation_speed,
		rotation_speed,
		current_rotation_acceleration * delta
	)

func _apply_movement(target_velocity: Vector3, delta: float, on_floor: bool) -> void:
	if !on_floor:
		var air_target_velocity = target_velocity * air_control
		if move_direction != Vector3.ZERO:
			velocity.x = move_toward(velocity.x, air_target_velocity.x, acceleration * air_control * delta)
			velocity.z = move_toward(velocity.z, air_target_velocity.z, acceleration * air_control * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, acceleration * air_brake * delta)
			velocity.z = move_toward(velocity.z, 0, acceleration * air_brake * delta)
	else:
		velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)

func _apply_jump_horizontal_momentum() -> void:
	if move_direction != Vector3.ZERO:
		var horizontal_jump = move_direction * jump_horizontal_force
		if Input.is_action_pressed("run"):
			horizontal_jump *= run_multiplier
		velocity.x = horizontal_jump.x * (1.0 - air_damping)
		velocity.z = horizontal_jump.z * (1.0 - air_damping)

func _handle_landing() -> void:
	var landing_intensity = abs(landing_velocity) / max_fall_speed
	velocity.y = velocity.y / landing_cushion
	
	velocity.x *= (1.0 - landing_intensity * 0.3)
	velocity.z *= (1.0 - landing_intensity * 0.3)
