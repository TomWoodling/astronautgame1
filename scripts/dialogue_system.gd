extends Node

signal dialogue_started(dialogue_data)
signal dialogue_ended
signal dialogue_advanced(next_text)

var current_dialogue: Array = []
var current_index: int = 0
var on_complete_callback: Callable

func start_dialogue(dialogue_data: Dictionary) -> void:
	current_dialogue = dialogue_data.dialogues
	current_index = 0
	on_complete_callback = dialogue_data.get("on_complete", Callable())
	
	if current_dialogue.size() > 0:
		dialogue_started.emit(dialogue_data)
		show_current_dialogue()

func advance_dialogue() -> void:
	current_index += 1
	if current_index < current_dialogue.size():
		show_current_dialogue()
	else:
		end_dialogue()

func show_current_dialogue() -> void:
	HUDManager.show_message(current_dialogue[current_index], "INFO")
	dialogue_advanced.emit(current_dialogue[current_index])

func end_dialogue() -> void:
	if on_complete_callback.is_valid():
		on_complete_callback.call()
	dialogue_ended.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and current_dialogue.size() > 0:
		advance_dialogue()
