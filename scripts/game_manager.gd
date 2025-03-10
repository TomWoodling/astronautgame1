extends Node

signal game_state_changed(new_state: String)
signal interaction_started(zone: InteractionZone)
signal interaction_ended
signal test_completed
signal test_failed(reason: String)

enum GameState {LOADING, PLAYING, DIALOGUE, PAUSED, TEST}
var current_state: GameState = GameState.LOADING
var player: Node3D
var test_controller: Node

func _ready() -> void:
	current_state = GameState.LOADING

func start_test(test_id: String) -> bool:
	if test_controller:
		test_controller.queue_free()
	
	test_controller = preload("res://scripts/test_controller.gd").new()
	add_child(test_controller)
	
	if test_controller.load_test(test_id):
		current_state = GameState.TEST
		test_controller.test_completed.connect(_on_test_completed)
		test_controller.test_failed.connect(_on_test_failed)
		test_controller.start_test()  # Critical: Start the test after loading
		return true
	return false

func _on_test_completed() -> void:
	current_state = GameState.PLAYING
	test_completed.emit()
	if test_controller:
		test_controller.queue_free()
		test_controller = null

func _on_test_failed(reason: String) -> void:
	current_state = GameState.PLAYING
	test_failed.emit(reason)
	if test_controller:
		test_controller.queue_free()
		test_controller = null

func start_interaction(zone: InteractionZone) -> void:
	if current_state != GameState.PLAYING and current_state != GameState.TEST:
		return
		
	interaction_started.emit(zone)
	match zone.interaction_type:
		"dialogue":
			current_state = GameState.DIALOGUE
			DialogueSystem.start_dialogue(zone.interaction_data)

func end_interaction() -> void:
	if current_state == GameState.DIALOGUE:
		current_state = GameState.PLAYING
	interaction_ended.emit()

func _on_dialogue_ended() -> void:
	if current_state == GameState.DIALOGUE:
		end_interaction()

func can_player_move() -> bool:
	return current_state == GameState.PLAYING or current_state == GameState.TEST
