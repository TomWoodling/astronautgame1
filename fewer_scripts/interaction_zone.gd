extends Area3D
class_name InteractionZone

@export var interaction_type: String = "dialogue"
@export var auto_interact: bool = false
@export var one_shot: bool = false
@export var interaction_data: Dictionary

var has_interacted: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body != GameManager.player or (one_shot and has_interacted):
		return
		
	if auto_interact:
		trigger_interaction()
	else:
		HUDManager.show_message("Press E to interact")

func _on_body_exited(_body: Node3D) -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		var overlapping = get_overlapping_bodies()
		if overlapping.has(GameManager.player):
			trigger_interaction()

func trigger_interaction() -> void:
	has_interacted = true
	GameManager.start_interaction(self)
