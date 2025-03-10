extends Node

signal ui_ready
signal poi_added(poi_data: Dictionary)
signal poi_removed(poi_id: int)
signal message_displayed(message_data: Dictionary)

const MESSAGE_TYPES = {
	"INFO": {"color": Color.WHITE, "duration": 3.0},
	"ALERT": {"color": Color.RED, "duration": 5.0},
	"ACHIEVEMENT": {"color": Color.YELLOW, "duration": 4.0}
}

var message_container: Control
var poi_container: Control
var active_pois: Dictionary = {}
var poi_counter: int = 0
var is_ready: bool = false
var poi_scene = preload("res://scenes/ui/poi_marker.tscn")

func _ready() -> void:
	# Don't use get_tree() immediately, wait for scene tree
	call_deferred("_setup_ui")

func _setup_ui() -> void:
	message_container = get_tree().get_first_node_in_group("ui_messages")
	poi_container = get_tree().get_first_node_in_group("ui_pois")
	
	if message_container and poi_container:
		is_ready = true
		ui_ready.emit()
	else:
		push_warning("HUD containers not found in scene tree")

func show_message(text: String, type: String = "INFO") -> void:
	if not is_ready:
		push_warning("Attempted to show message before HUD was ready")
		return
		
	var config = MESSAGE_TYPES.get(type, MESSAGE_TYPES.INFO)
	var message_data = {
		"text": text,
		"color": config.color,
		"duration": config.duration
	}
	
	message_container.display_message(message_data)
	message_displayed.emit(message_data)

func add_poi(node: Node3D, poi_type: String, icon: Texture2D, label: String = "") -> int:
	if not is_ready:
		push_warning("Attempted to add POI before HUD was ready")
		return -1
	
	if not poi_container or not node or not icon:
		push_warning("Invalid POI parameters")
		return -1
		
	poi_counter += 1
	
	var marker = poi_scene.instantiate()
	poi_container.add_child(marker)
	
	var poi_data = {
		"id": poi_counter,
		"node": node,
		"type": poi_type,
		"icon": icon,
		"label": label
	}
	
	marker.setup(poi_data)
	active_pois[poi_counter] = poi_data
	poi_added.emit(poi_data)
	
	return poi_counter

func remove_poi(poi_id: int) -> void:
	if not active_pois.has(poi_id):
		return
		
	var poi_data = active_pois[poi_id]
	var marker = poi_container.get_node_or_null(str(poi_id))
	if marker:
		marker.queue_free()
	
	active_pois.erase(poi_id)
	poi_removed.emit(poi_id)

func update_poi_label(poi_id: int, new_label: String) -> void:
	if not active_pois.has(poi_id):
		return
		
	var marker = poi_container.get_node_or_null(str(poi_id))
	if marker:
		marker.update_label(new_label)
		active_pois[poi_id].label = new_label

func clear_all_pois() -> void:
	for poi_id in active_pois.keys():
		remove_poi(poi_id)
	active_pois.clear()
	poi_counter = 0

func get_poi_data(poi_id: int) -> Dictionary:
	return active_pois.get(poi_id, {})

func has_poi(poi_id: int) -> bool:
	return active_pois.has(poi_id)

func get_pois_by_type(poi_type: String) -> Array:
	return active_pois.values().filter(func(poi): return poi.type == poi_type)

# System status checks
func is_poi_system_ready() -> bool:
	return is_ready and poi_container != null

func is_message_system_ready() -> bool:
	return is_ready and message_container != null
