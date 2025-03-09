extends Node3D

const CHUNK_SIZE: int = 100
const TERRAIN_HEIGHT_RANGE: Vector2 = Vector2(-5.0, 5.0)
const MIN_PLATFORMS_PER_CHUNK: int = 1
const MAX_PLATFORMS_PER_CHUNK: int = 3

# Terrain types with their properties
const TERRAIN_TYPES = {
	"flat": {
		"weight": 0.3,
		"height_variation": 1.0,
		"noise_scale": 0.1
	},
	"crater": {
		"weight": 0.2,
		"height_variation": 4.0,
		"noise_scale": 0.3,
		"crater_radius": Vector2(10.0, 30.0)
	},
	"ridge": {
		"weight": 0.2,
		"height_variation": 3.0,
		"noise_scale": 0.2,
		"ridge_direction": Vector2.RIGHT  # Randomized during generation
	},
	"valley": {
		"weight": 0.15,
		"height_variation": 5.0,
		"noise_scale": 0.25
	},
	"paved": {
		"weight": 0.15,
		"height_variation": 0.5,
		"noise_scale": 0.05
	}
}

# Platform configurations
const PLATFORM_TYPES = {
	"collection_point": {
		"weight": 0.4,
		"scene": preload("res://scenes/platforms/collection_platform.tscn"),
		"min_spacing": 20.0
	},
	"challenge_course": {
		"weight": 0.3,
		"scene": preload("res://scenes/platforms/challenge_platform.tscn"),
		"min_spacing": 40.0
	},
	"npc_station": {
		"weight": 0.3,
		"scene": preload("res://scenes/platforms/npc_platform.tscn"),
		"min_spacing": 30.0
	}
}

var noise: FastNoiseLite
var generated_chunks: Dictionary = {}
var current_chunk: Vector2
var player: Node3D

func _ready() -> void:
	setup_noise()
	spawn_player()
	check_chunks(player.global_position)

func _physics_process(_delta: float) -> void:
	if player and current_chunk != get_chunk_coords(player.global_position):
		check_chunks(player.global_position)

func setup_noise() -> void:
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.seed = randi()
	noise.frequency = 0.005

func get_chunk_coords(pos: Vector3) -> Vector2:
	return Vector2(
		floor(pos.x / CHUNK_SIZE),
		floor(pos.z / CHUNK_SIZE)
	)

func generate_chunk(chunk_coords: Vector2) -> void:
	if generated_chunks.has(chunk_coords):
		return
		
	var chunk = Node3D.new()
	chunk.name = "Chunk_%d_%d" % [chunk_coords.x, chunk_coords.y]
	
	# Calculate chunk world position
	var chunk_pos = Vector3(
		chunk_coords.x * CHUNK_SIZE,
		0,
		chunk_coords.y * CHUNK_SIZE
	)
	chunk.global_position = chunk_pos
	
	# Generate terrain mesh
	var terrain = generate_terrain_mesh(chunk_coords)
	chunk.add_child(terrain)
	
	# Generate platforms if not too close to other platforms
	generate_platforms(chunk, chunk_coords)
	
	# Special handling for tutorial area in starting chunk
	if chunk_coords == Vector2.ZERO:
		add_tutorial_area(chunk)
	
	add_child(chunk)
	generated_chunks[chunk_coords] = chunk

func generate_terrain_mesh(chunk_coords: Vector2) -> MeshInstance3D:
	var terrain_type = select_terrain_type()
	var st = SurfaceTool.new()
	var plane_mesh = PlaneMesh.new()
	
	# Configure the plane mesh
	plane_mesh.size = Vector2(CHUNK_SIZE, CHUNK_SIZE)
	plane_mesh.subdivide_width = 32
	plane_mesh.subdivide_depth = 32
	
	# Generate height data based on terrain type
	var vertices = []
	var config = TERRAIN_TYPES[terrain_type]
	
	# Create the mesh
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Add vertices with height data
	for v in plane_mesh.get_mesh_arrays()[Mesh.ARRAY_VERTEX]:
		var world_pos = v + Vector3(chunk_coords.x * CHUNK_SIZE, 0, chunk_coords.y * CHUNK_SIZE)
		var height = get_height_at_point(world_pos, terrain_type)
		vertices.append(Vector3(v.x, height, v.z))
	
	# Create triangles and calculate normals
	st.create_from(plane_mesh)
	st.generate_normals()
	
	# Create the terrain mesh instance
	var terrain = MeshInstance3D.new()
	terrain.mesh = st.commit()
	
	# Add collision shape
	var collision_shape = CollisionShape3D.new()
	collision_shape.shape = terrain.mesh.create_trimesh_shape()
	
	var static_body = StaticBody3D.new()
	static_body.add_child(collision_shape)
	terrain.add_child(static_body)
	
	return terrain

func get_height_at_point(world_pos: Vector3, terrain_type: String) -> float:
	var config = TERRAIN_TYPES[terrain_type]
	var base_height = noise.get_noise_2d(world_pos.x, world_pos.z)
	base_height *= config.height_variation
	
	match terrain_type:
		"crater":
			var crater_center = Vector2(world_pos.x, world_pos.z)
			var distance = crater_center.length()
			if distance < config.crater_radius.y:
				var crater_depth = smoothstep(config.crater_radius.y, config.crater_radius.x, distance)
				base_height -= crater_depth * config.height_variation
		"ridge":
			var ridge_value = sin(world_pos.dot(config.ridge_direction) * 0.1)
			base_height += ridge_value * config.height_variation
	
	return base_height

func generate_platforms(chunk: Node3D, chunk_coords: Vector2) -> void:
	var num_platforms = randi_range(MIN_PLATFORMS_PER_CHUNK, MAX_PLATFORMS_PER_CHUNK)
	var placed_platforms = []
	
	for _i in range(num_platforms):
		var platform_type = select_platform_type()
		var config = PLATFORM_TYPES[platform_type]
		
		# Try to find a valid position
		var max_attempts = 10
		var attempts = 0
		while attempts < max_attempts:
			var pos = Vector3(
				randf_range(0, CHUNK_SIZE),
				0,
				randf_range(0, CHUNK_SIZE)
			)
			
			# Check minimum spacing from other platforms
			var too_close = false
			for placed in placed_platforms:
				if pos.distance_to(placed) < config.min_spacing:
					too_close = true
					break
			
			if not too_close:
				var platform = config.scene.instantiate()
				platform.position = pos
				# Adjust Y position based on terrain height
				var world_pos = pos + Vector3(chunk_coords.x * CHUNK_SIZE, 0, chunk_coords.y * CHUNK_SIZE)
				platform.position.y = get_height_at_point(world_pos, "flat")
				chunk.add_child(platform)
				placed_platforms.append(pos)
				break
				
			attempts += 1

func select_terrain_type() -> String:
	var roll = randf()
	var cumulative = 0.0
	
	for type in TERRAIN_TYPES:
		cumulative += TERRAIN_TYPES[type].weight
		if roll <= cumulative:
			return type
	
	return "flat"

func select_platform_type() -> String:
	var roll = randf()
	var cumulative = 0.0
	
	for type in PLATFORM_TYPES:
		cumulative += PLATFORM_TYPES[type].weight
		if roll <= cumulative:
			return type
	
	return "collection_point"

func add_tutorial_area(chunk: Node3D) -> void:
	var tutorial_platform = preload("res://scenes/platforms/tutorial_platform.tscn").instantiate()
	tutorial_platform.position = Vector3(CHUNK_SIZE * 0.2, 0, CHUNK_SIZE * 0.2)
	tutorial_platform.position.y = get_height_at_point(tutorial_platform.position, "flat")
	chunk.add_child(tutorial_platform)

func spawn_player() -> void:
	player = preload("res://scenes/player.tscn").instantiate()
	add_child(player)
	player.global_position = Vector3(10, 5, 10)  # Slight offset from origin
	current_chunk = get_chunk_coords(Vector3.ZERO)

func check_chunks(player_pos: Vector3) -> void:
	current_chunk = get_chunk_coords(player_pos)
	
	# Generate surrounding chunks
	for x in range(-1, 2):
		for y in range(-1, 2):
			var check_coords = current_chunk + Vector2(x, y)
			if not generated_chunks.has(check_coords):
				generate_chunk(check_coords)
	
	# Clean up distant chunks
	var chunks_to_remove = []
	for coords in generated_chunks:
		if abs(coords.x - current_chunk.x) > 1 or abs(coords.y - current_chunk.y) > 1:
			chunks_to_remove.append(coords)
	
	for coords in chunks_to_remove:
		generated_chunks[coords].queue_free()
		generated_chunks.erase(coords)

func _exit_tree() -> void:
	for chunk in generated_chunks.values():
		if is_instance_valid(chunk):
			chunk.queue_free()
	generated_chunks.clear()
