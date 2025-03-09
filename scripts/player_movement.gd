extends CharacterBody3D

@export_group("Astronaut Movement")
@export var walk_speed: float = 4.0
@export var run_multiplier: float = 1.75  # Multiplies speed when running
@export var acceleration: float = 5.0
@export var friction: float = 2.0
@export var rotation_speed: float = 4.0
@export var rotation_acceleration: float = 8.0
@export var rotation_deceleration: float = 4.0

@export_group("Lunar Jump Parameters")
@export var jump_force: float = 8.0
@export var jump_horizontal_force: float = 4.0  # Consistent horizontal jump force
@export var air_damping: float = 0.25  # Smooths out initial jump velocity
@export var gravity: float = 5.0
@export var max_fall_speed: float = 15.0
@export var air_control: float = 0.6  # Increased for better air steering
@export var air_brake: float = 0.15  # How much you can slow down in air
@export var landing_cushion: float = 2.0

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
var current_speed: float = 0.0  # Track actual speed for smooth transitions

func _ready() -> void:
	assert(camera_rig != null, "Camera rig node not found!")
	assert(mesh != null, "Mesh node not found!")
	
	if camera_rig.has_signal("camera_rotated"):
		camera_rig.connect("camera_rotated", _on_camera_rotated)

func _on_camera_rotated(new_basis: Basis) -> void:
	camera_basis = new_basis

func _physics_process(delta: float) -> void:
	var on_floor = is_on_floor()
	
	if was_in_air and on_floor:
		_handle_landing()
	was_in_air = !on_floor
	
	# Gravity and vertical movement with damping
	if !on_floor:
		landing_velocity = velocity.y
		velocity.y = move_toward(velocity.y, -max_fall_speed, gravity * delta)
	
	# Input handling
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var is_running = Input.is_action_pressed("run")
	
	# Movement direction calculation
	move_direction = Vector3.ZERO
	if input_dir != Vector2.ZERO:
		var forward = camera_basis.z
		forward.y = 0
		forward = forward.normalized()
		
		var right = camera_basis.x
		right.y = 0
		right = right.normalized()
		
		move_direction = (forward * input_dir.y + right * input_dir.x).normalized()
		
		# Character rotation
		target_basis = Basis.looking_at(move_direction)
		
		var current_rotation_acceleration = rotation_acceleration
		if !on_floor:
			current_rotation_acceleration *= air_control
		
		current_rotation_speed = move_toward(
			current_rotation_speed,
			rotation_speed,
			current_rotation_acceleration * delta
		)
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
	
	# Calculate target speed with running
	var target_speed = walk_speed * (run_multiplier if is_running else 1.0)
	current_speed = move_toward(current_speed, target_speed, acceleration * delta)
	
	# Jump handling with consistent force
	if Input.is_action_just_pressed("jump") and on_floor:
		velocity.y = jump_force
		
		# Apply consistent horizontal jump force in move_direction
		if move_direction != Vector3.ZERO:
			var jump_direction = move_direction
			var horizontal_jump = jump_direction * jump_horizontal_force
			if is_running:
				horizontal_jump *= run_multiplier
			
			# Apply horizontal jump force with initial damping
			velocity.x = horizontal_jump.x * (1.0 - air_damping)
			velocity.z = horizontal_jump.z * (1.0 - air_damping)
	
	# Calculate target velocity
	var target_velocity = move_direction * current_speed
	
	# Air movement
	if !on_floor:
		var air_target_velocity = target_velocity * air_control
		
		# Allow some air control but maintain momentum
		if move_direction != Vector3.ZERO:
			# Accelerate in air
			velocity.x = move_toward(velocity.x, air_target_velocity.x, acceleration * air_control * delta)
			velocity.z = move_toward(velocity.z, air_target_velocity.z, acceleration * air_control * delta)
		else:
			# Apply air brake when no input
			velocity.x = move_toward(velocity.x, 0, acceleration * air_brake * delta)
			velocity.z = move_toward(velocity.z, 0, acceleration * air_brake * delta)
	else:
		# Ground movement
		velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)
	
	move_and_slide()

func _handle_landing() -> void:
	var landing_intensity = abs(landing_velocity) / max_fall_speed
	velocity.y = velocity.y / landing_cushion
	
	# Maintain some horizontal momentum on landing
	velocity.x *= (1.0 - landing_intensity * 0.3)
	velocity.z *= (1.0 - landing_intensity * 0.3)
