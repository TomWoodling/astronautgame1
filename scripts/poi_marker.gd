extends HUDElement
class_name POIMarker

@onready var icon: TextureRect = $Icon
@onready var label: Label = $Label

var target_node: Node3D
var screen_size: Vector2
var margin: float = 50.0

func _ready() -> void:
	screen_size = get_viewport().get_visible_rect().size
	set_process(false)

func setup(poi_data: Dictionary) -> void:
	target_node = poi_data.node
	icon.texture = poi_data.icon
	label.text = poi_data.get("label", "")
	show_element()
	set_process(true)

func _process(_delta: float) -> void:
	if not is_instance_valid(target_node):
		queue_free()
		return
	
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
	
	var target_pos = target_node.global_position
	var screen_pos = camera.unproject_position(target_pos)
	
	# Check if target is behind camera
	var to_camera = camera.global_position - target_pos
	var is_behind = to_camera.dot(camera.global_transform.basis.z) > 0
	
	if is_behind:
		screen_pos = -screen_pos
	
	# Clamp to screen edges with margin
	var final_pos = Vector2(
		clamp(screen_pos.x, margin, screen_size.x - margin),
		clamp(screen_pos.y, margin, screen_size.y - margin)
	)
	
	global_position = final_pos
	
	# Rotate icon to point towards target when at screen edge
	if final_pos != screen_pos:
		icon.rotation = (screen_pos - final_pos).angle()
		# Add 90 degrees (PI/2) if your icon's default orientation is pointing up
		icon.rotation += PI/2
	else:
		icon.rotation = 0

func update_label(new_label: String) -> void:
	label.text = new_label
