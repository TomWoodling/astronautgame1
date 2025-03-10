extends Node

signal game_state_changed(new_state: String)
signal interaction_started(zone: InteractionZone)
signal interaction_ended
signal player_ready(player: Node3D)  # New signal

enum GameState {LOADING, PLAYING, DIALOGUE, PAUSED}
var current_state: GameState = GameState.LOADING
var player: Node3D
var test_controller: Node

func _ready() -> void:
	current_state = GameState.PLAYING

func start_interaction(zone: InteractionZone) -> void:
	if current_state != GameState.PLAYING:
		return
		
	interaction_started.emit(zone)
	match zone.interaction_type:
		"dialogue":
			current_state = GameState.DIALOGUE
			DialogueSystem.start_dialogue(zone.interaction_data)

func end_interaction() -> void:
	current_state = GameState.PLAYING
	interaction_ended.emit()

func _on_dialogue_ended() -> void:
	if current_state == GameState.DIALOGUE:
		end_interaction()

# Running tests
func start_test(test_id: String) -> void:
	if not player:
		push_error("Cannot start test: Player not registered")
		return
		
	if test_controller:
		test_controller.queue_free()
	
	test_controller = preload("res://scripts/test_controller.gd").new()
	add_child(test_controller)
	
	if test_controller.load_test(test_id):
		test_controller.test_completed.connect(_on_test_completed)
		test_controller.test_failed.connect(_on_test_failed)
		test_controller.start_test()
	else:
		push_error("Failed to load test: " + test_id)

func _on_test_completed() -> void:
	print("Test completed successfully!")
	
func _on_test_failed(reason: String) -> void:
	push_error("Test failed: " + reason)

func register_player(p_node: Node3D) -> void:
	player = p_node
	player_ready.emit(player)
	current_state = GameState.PLAYING
