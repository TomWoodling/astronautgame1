extends Node

signal poi_added(poi_data)
signal poi_removed(poi_id)
signal message_displayed(message_data)

const MESSAGE_TYPES = {
	"INFO": {"color": Color.WHITE, "duration": 3.0},
	"ALERT": {"color": Color.RED, "duration": 5.0},
	"ACHIEVEMENT": {"color": Color.YELLOW, "duration": 4.0}
}

# Points of Interest tracking
var active_pois: Dictionary = {}
var poi_counter: int = 0

# Reference to UI elements (set via scene tree)
var message_container: Control
var poi_container: Control
var status_container: Control

func _ready() -> void:
	# Ensure UI elements exist
	await get_tree().create_timer(0.1).timeout
	message_container = get_tree().get_first_node_in_group("ui_messages")
	poi_container = get_tree().get_first_node_in_group("ui_pois")
	status_container = get_tree().get_first_node_in_group("ui_status")

func add_poi(node: Node3D, poi_type: String, icon: Texture, priority: int = 0) -> int:
	poi_counter += 1
	var poi_data = {
		"id": poi_counter,
		"node": node,
		"type": poi_type,
		"icon": icon,
		"priority": priority
	}
	active_pois[poi_counter] = poi_data
	poi_added.emit(poi_data)
	return poi_counter

func remove_poi(poi_id: int) -> void:
	if active_pois.has(poi_id):
		var poi_data = active_pois[poi_id]
		active_pois.erase(poi_id)
		poi_removed.emit(poi_id)

func show_message(text: String, type: String = "INFO") -> void:
	var config = MESSAGE_TYPES[type]
	message_displayed.emit({
		"text": text,
		"color": config.color,
		"duration": config.duration
	})

func update_status(key: String, value: Variant) -> void:
	if status_container:
		status_container.update_value(key, value)
