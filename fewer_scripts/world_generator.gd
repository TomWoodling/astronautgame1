extends Node3D

const CHUNK_SIZE: int = 100
const TERRAIN_HEIGHT_RANGE: Vector2 = Vector2(-5.0, 5.0)
const MIN_PLATFORMS_PER_CHUNK: int = 1
const MAX_PLATFORMS_PER_CHUNK: int = 3

# Platform configurations
const PLATFORM_TYPES = {
	"collection": {
		"weight": 0.4,
		"size": Vector3(3, 0.1, 3),
		"color": Color(0.2, 0.8, 0.2),  # Green for collectibles
		"min_spacing": 20.0,
		"interaction": {
			"type": "collection",
			"auto_interact": true,
			"one_shot": true,
			"data": {
				"item_type": "lunar_sample"
			}
		}
	},
	"challenge": {
		"weight": 0.3,
		"size": Vector3(5, 0.1, 5),
		"color": Color(0.8, 0.4, 0.0),  # Orange for challenges
		"min_spacing": 40.0,
		"interaction": {
			"type": "challenge",
			"auto_interact": false,
			"one_shot": false,
			"data": {
				"challenge_type": "parkour",
				"difficulty": 1
			}
		}
	},
	"npc": {
		"weight": 0.3,
		"size": Vector3(4, 0.1, 4),
		"color": Color(0.2, 0.2, 0.8),  # Blue for NPCs
		"min_spacing": 30.0,
		"interaction": {
			"type": "dialogue",
			"auto_interact": false,
			"one_shot": true,
			"data": {
				"dialogue_id": "random_astronaut",
				"dialogues": [
					"Have you collected any lunar samples yet?",
					"The view of Earth from here is spectacular!",
					"Watch your oxygen levels out there."
				]
			}
		}
	}
}

# Terrain generation parameters
const NOISE_PARAMS = {
	"frequency": 0.005,
	"terrain_scale": 10.0,
	"detail_scale": 2.0
}

var noise: FastNoiseLite
var generated_chunks: Dictionary = {}
var current_chunk: Vector2
var player: Node3D

@onready var base_platform: PackedScene = preload("res://scenes/platforms/base_platform.tscn")

func _ready() -> void:
	setup_noise()
	# Wait for scene to be ready before initializing
	await get_tree().process_frame
	initialize_world()

func _physics_process(_delta: float) -> void:
	if not player:
		return
		
	var player_chunk = get_chunk_coords(player.global_position)
	if current_chunk != player_chunk:
		check_chunks(player.global_position)

func initialize_world() -> void:
	# Find and setup player
	player = get_tree().get_first_node_in_group("player")
	if not player:
		push_error("Player node not found in world scene")
		return
		
	# Remove holding area if it exists
	var holding_area = get_tree().get_first_node_in_group("holding_area")
	if holding_area and holding_area is CSGBox3D:
		holding_area.queue_free()
	
	# Position player and initialize chunks
	player.position = Vector3(10, 5, 10)
	current_chunk = get_chunk_coords(Vector3.ZERO)
	check_chunks(player.global_position)
	
	# Show welcome message
	await get_tree().create_timer(0.5).timeout
	HUDManager.show_message("Welcome to Lunar Training Facility", "INFO")

func setup_noise() -> void:
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.seed = randi()
	noise.frequency = NOISE_PARAMS.frequency

func get_chunk_coords(pos: Vector3) -> Vector2:
	return Vector2(
		floor(pos.x / CHUNK_SIZE),
		floor(pos.z / CHUNK_SIZE)
	)

func generate_chunk(chunk_coords: Vector2) -> void:
	if generated_chunks.has(chunk_coords):
		return
		
	var chunk := Node3D.new()
	chunk.name = "Chunk_%d_%d" % [chunk_coords.x, chunk_coords.y]
	add_child(chunk)
	
	# Set local position for chunk
	chunk.position = Vector3(
		chunk_coords.x * CHUNK_SIZE,
		0,
		chunk_coords.y * CHUNK_SIZE
	)
	
	# Generate terrain mesh
	var terrain := generate_terrain_mesh(chunk_coords)
	if terrain:
		chunk.add_child(terrain)
	
	# Generate platforms
	generate_platforms(chunk, chunk_coords)
	
	# Special handling for tutorial area in starting chunk
	if chunk_coords == Vector2.ZERO:
		add_tutorial_platform(chunk)
	
	generated_chunks[chunk_coords] = chunk

func generate_terrain_mesh(chunk_coords: Vector2) -> MeshInstance3D:
	var st := SurfaceTool.new()
	var plane_mesh := PlaneMesh.new()
	
	plane_mesh.size = Vector2(CHUNK_SIZE, CHUNK_SIZE)
	plane_mesh.subdivide_width = 32
	plane_mesh.subdivide_depth = 32
	
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var mesh_arrays := plane_mesh.get_mesh_arrays()
	var vertices: PackedVector3Array = mesh_arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = mesh_arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = mesh_arrays[Mesh.ARRAY_INDEX]
	
	# Modify vertices with height data
	for i in vertices.size():
		var vertex := vertices[i]
		var world_pos := vertex + Vector3(chunk_coords.x * CHUNK_SIZE, 0, chunk_coords.y * CHUNK_SIZE)
		# Create a new Vector3 with the modified height
		var modified_vertex := Vector3(
			vertex.x,
			get_height_at_point(world_pos),
			vertex.z
		)
		st.add_vertex(modified_vertex)
		st.add_uv(uvs[i])
	
	# Add indices to create triangles
	for i in range(0, indices.size(), 3):
		st.add_index(indices[i])
		st.add_index(indices[i + 1])
		st.add_index(indices[i + 2])
	
	st.generate_normals()
	
	var terrain := MeshInstance3D.new()
	terrain.mesh = st.commit()
	
	# Add collision
	var static_body := StaticBody3D.new()
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = terrain.mesh.create_trimesh_shape()
	static_body.add_child(collision_shape)
	terrain.add_child(static_body)
	
	return terrain

func get_height_at_point(world_pos: Vector3) -> float:
	var base_height := noise.get_noise_2d(world_pos.x, world_pos.z)
	var detail := noise.get_noise_2d(world_pos.x * 2.0, world_pos.z * 2.0)
	
	return (base_height * NOISE_PARAMS.terrain_scale + 
			detail * NOISE_PARAMS.detail_scale)

func select_platform_type() -> String:
	var roll := randf()
	var cumulative := 0.0
	
	for type in PLATFORM_TYPES:
		cumulative += PLATFORM_TYPES[type].weight
		if roll <= cumulative:
			return type
	
	return PLATFORM_TYPES.keys()[0]

func create_platform(type: String, position: Vector3) -> Node3D:
	var config = PLATFORM_TYPES[type]
	var platform := base_platform.instantiate()
	
	# Configure platform mesh
	var mesh_instance := platform.get_node("MeshInstance3D")
	var mesh := mesh_instance.mesh as BoxMesh
	mesh.size = config.size
	
	# Update material
	var material := StandardMaterial3D.new()
	material.albedo_color = config.color
	mesh.material = material
	
	# Update collision shape
	var collision := platform.get_node("CollisionShape3D")
	var shape := collision.shape as BoxShape3D
	shape.size = config.size
	
	# Configure interaction zone
	var interaction := platform.get_node("InteractionZone")
	var interaction_config = config.interaction
	interaction.interaction_type = interaction_config.type
	interaction.auto_interact = interaction_config.auto_interact
	interaction.one_shot = interaction_config.one_shot
	interaction.interaction_data = interaction_config.data
	
	# Update interaction zone collision
	var interaction_collision := interaction.get_node("CollisionShape3D")
	var interaction_shape := interaction_collision.shape as BoxShape3D
	interaction_shape.size = Vector3(config.size.x, config.size.y + 0.5, config.size.z)
	interaction_collision.position.y = config.size.y + 0.25
	
	# Add POI based on platform type
	match type:
		"npc":
			HUDManager.add_poi(platform, "npc", POIIcons.get_icon("npc"))
		"collection", "challenge":
			if not AchievementManager.has_achievement(interaction_config.data.get("achievement_id", "")):
				HUDManager.add_poi(platform, "achievement", POIIcons.get_icon("achievement"))
	
	platform.position = position
	return platform

func generate_platforms(chunk: Node3D, chunk_coords: Vector2) -> void:
	var num_platforms := randi_range(MIN_PLATFORMS_PER_CHUNK, MAX_PLATFORMS_PER_CHUNK)
	var placed_platforms: Array[Vector3] = []
	
	for _i in range(num_platforms):
		var platform_type := select_platform_type()
		var config = PLATFORM_TYPES[platform_type]
		
		var max_attempts := 10
		var attempts := 0
		while attempts < max_attempts:
			var pos := Vector3(
				randf_range(0, CHUNK_SIZE),
				0,
				randf_range(0, CHUNK_SIZE)
			)
			
			if is_valid_platform_position(pos, placed_platforms, config.min_spacing):
				var world_pos := pos + Vector3(chunk_coords.x * CHUNK_SIZE, 0, chunk_coords.y * CHUNK_SIZE)
				pos.y = get_height_at_point(world_pos) + config.size.y * 0.5
				
				var platform := create_platform(platform_type, pos)
				chunk.add_child(platform)
				placed_platforms.append(pos)
				break
				
			attempts += 1

func is_valid_platform_position(pos: Vector3, placed_platforms: Array[Vector3], min_spacing: float) -> bool:
	for placed in placed_platforms:
		if pos.distance_to(placed) < min_spacing:
			return false
	return true

func add_tutorial_platform(chunk: Node3D) -> void:
	var tutorial_pos := Vector3(CHUNK_SIZE * 0.2, 0, CHUNK_SIZE * 0.2)
	tutorial_pos.y = get_height_at_point(tutorial_pos) + 0.05
	
	var platform := create_platform("npc", tutorial_pos)
	var interaction := platform.get_node("InteractionZone")
	interaction.interaction_data = {
		"dialogue_id": "tutorial",
		"on_complete": func(): AchievementManager.unlock_achievement("first_flight"),
		"dialogues": [
			"Welcome to lunar training, rookie! Ready for your first mission?",
			"Remember: In space, momentum is your friend. Use your thrusters wisely.",
			"Try moving around with [WASD] and your thrusters with [SPACE]."
		]
	}
	chunk.add_child(platform)

func check_chunks(player_pos: Vector3) -> void:
	current_chunk = get_chunk_coords(player_pos)
	
	# Generate surrounding chunks
	for x in range(-1, 2):
		for y in range(-1, 2):
			var check_coords := current_chunk + Vector2(x, y)
			if not generated_chunks.has(check_coords):
				generate_chunk(check_coords)
	
	# Clean up distant chunks
	var chunks_to_remove: Array[Vector2] = []
	for coords in generated_chunks:
		if abs(coords.x - current_chunk.x) > 1 or abs(coords.y - current_chunk.y) > 1:
			chunks_to_remove.append(coords)
	
	for coords in chunks_to_remove:
		if generated_chunks[coords].is_inside_tree():
			generated_chunks[coords].queue_free()
		generated_chunks.erase(coords)

func _exit_tree() -> void:
	for chunk in generated_chunks.values():
		if is_instance_valid(chunk) and chunk.is_inside_tree():
			chunk.queue_free()
	generated_chunks.clear()

func create_test_platform(position: Vector3, type: String, interaction_data: Dictionary) -> void:
	var platform := create_platform(type, position)
	if platform:
		var interaction_zone := platform.get_node("InteractionZone")
		if interaction_zone:
			interaction_zone.interaction_data = interaction_data
