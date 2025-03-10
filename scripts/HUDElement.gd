extends Control
class_name HUDElement

var tween: Tween

func show_element() -> void:
	if tween:
		tween.kill()
	tween = create_tween()
	modulate.a = 0
	show()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)

func hide_element() -> void:
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): hide())
	
