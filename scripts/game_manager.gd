extends Node

var dialogue_system: Node

signal game_state_changed(new_state, old_state)
signal interaction_started(interaction_data)
signal interaction_ended(interaction_data)

enum GameState {
	PLAYING,
	DIALOGUE,
	CUTSCENE,
	PAUSED,
	MENU
}

var current_state: GameState = GameState.PLAYING:
	set(value):
		var old_state = current_state
		current_state = value
		game_state_changed.emit(current_state, old_state)

var player: Node3D
var current_interaction_target: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	dialogue_system = preload("res://scripts/dialogue_system.gd").new()
	add_child(dialogue_system)

func register_player(p_node: Node3D) -> void:
	player = p_node

func can_player_move() -> bool:
	return current_state == GameState.PLAYING

func start_interaction(target: Node, interaction_type: String, data: Dictionary = {}) -> void:
	if current_state != GameState.PLAYING:
		return
		
	match type:
		"dialogue":
			dialogue_system.start_dialogue(data)
	current_interaction_target = target
	current_state = GameState.DIALOGUE if interaction_type == "dialogue" else GameState.CUTSCENE
	interaction_started.emit({
		"target": target,
		"type": interaction_type,
		"data": data
	})

func end_interaction() -> void:
	var previous_target = current_interaction_target
	current_interaction_target = null
	current_state = GameState.PLAYING
	interaction_ended.emit({
		"target": previous_target
	})
