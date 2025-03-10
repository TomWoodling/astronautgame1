extends Node

signal dialogue_started(dialogue_data: Dictionary)
signal dialogue_ended

var current_dialogue: Array = []
var current_index: int = -1

func _ready() -> void:
	dialogue_ended.connect(GameManager._on_dialogue_ended)

func start_dialogue(data: Dictionary) -> void:
	if not data.has("dialogues") or data.dialogues.is_empty():
		return
		
	current_dialogue = data.dialogues
	current_index = 0
	dialogue_started.emit(data)
	HUDManager.show_message(current_dialogue[current_index])

func advance_dialogue() -> void:
	if current_index < 0:
		return
		
	current_index += 1
	if current_index < current_dialogue.size():
		HUDManager.show_message(current_dialogue[current_index])
	else:
		end_dialogue()

func end_dialogue() -> void:
	current_index = -1
	current_dialogue.clear()
	dialogue_ended.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and current_index >= 0:
		advance_dialogue()
