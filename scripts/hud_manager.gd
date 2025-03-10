extends Node

signal poi_added(poi_data: Dictionary)
signal poi_removed(poi_id: int)

const MESSAGE_TYPES = {
	"INFO": {"color": Color.WHITE, "duration": 3.0},
	"ALERT": {"color": Color.RED, "duration": 5.0},
	"ACHIEVEMENT": {"color": Color.YELLOW, "duration": 4.0}
}

var active_pois: Dictionary = {}
var poi_counter: int = 0
var poi_scene = preload("res://scenes/ui/poi_marker.tscn")

@onready var message_container = get_tree().get_first_node_in_group("ui_messages")
@onready var poi_container = get_tree().get_first_node_in_group("ui_pois")

func show_message(text: String, type: String = "INFO") -> void:
	if not message_container:
		return
		
	var config = MESSAGE_TYPES.get(type, MESSAGE_TYPES.INFO)
	message_container.display_message({
		"text": text,
		"color": config.color,
		"duration": config.duration
	})

func add_poi(node: Node3D, poi_type: String, icon: Texture) -> int:
	if not poi_container:
		return -1
		
	poi_counter += 1
	var marker = poi_scene.instantiate()
	poi_container.add_child(marker)
	
	var poi_data = {
		"id": poi_counter,
		"node": node,
		"type": poi_type,
		"icon": icon
	}
	
	marker.setup(poi_data)
	active_pois[poi_counter] = poi_data
	return poi_counter

func remove_poi(poi_id: int) -> void:
	if active_pois.has(poi_id):
		active_pois.erase(poi_id)
		poi_removed.emit(poi_id)
