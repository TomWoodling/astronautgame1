extends Node

func test_world_load():
	# 1. Load world scene
	var world_scene = preload("res://scenes/world.tscn").instantiate()
	add_child(world_scene)
	
	# 2. Verify initial chunk generation
	assert(world_scene.generated_chunks.has(Vector2.ZERO))
	
	# 3. Verify tutorial platform exists
	var tutorial_chunk = world_scene.generated_chunks[Vector2.ZERO]
	var tutorial_platform = tutorial_chunk.get_node("tutorial_platform")
	assert(tutorial_platform != null)

func test_first_flight_sequence():
	# 1. Check initial welcome message
	await get_tree().create_timer(1.0).timeout
	assert(last_message == "Welcome to Lunar Training Facility")
	
	# 2. Verify NPC POI is visible
	var poi_exists = false
	for poi in HUDManager.active_pois.values():
		if poi.type == "npc":
			poi_exists = true
	assert(poi_exists)
	
	# 3. Test NPC interaction
	var tutorial_platform = get_node("World/Chunk_0_0/tutorial_platform")
	var interaction_zone = tutorial_platform.get_node("InteractionZone")
	
	# Simulate player entering zone
	interaction_zone._on_body_entered(GameManager.player)
	assert(last_message == "Press E to interact")
	
	# Simulate interaction
	var event = InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	interaction_zone._unhandled_input(event)
	
	# 4. Verify dialogue progression
	assert(GameManager.dialogue_system.current_dialogue.size() > 0)
	
	# 5. Complete dialogue and check achievement
	while GameManager.dialogue_system.current_dialogue.size() > 0:
		GameManager.dialogue_system.advance_dialogue()
		await get_tree().create_timer(0.1).timeout
	
	assert(AchievementManager.unlocked_achievements.has("first_flight"))
