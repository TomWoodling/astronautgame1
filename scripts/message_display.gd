extends HUDElement
class_name MessageDisplay

@onready var label: Label = $Label
@onready var panel: Panel = $Panel

var hide_timer: SceneTreeTimer

func display_message(message_data: Dictionary) -> void:
	if hide_timer:
		hide_timer.time_left = 0
		
	label.text = message_data.text
	label.add_theme_color_override("font_color", message_data.color)
	
	show_element()
	
	hide_timer = get_tree().create_timer(message_data.duration)
	hide_timer.timeout.connect(hide_element)
