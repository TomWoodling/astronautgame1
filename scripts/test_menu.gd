extends CanvasLayer

func _ready() -> void:
	GameManager.test_completed.connect(_on_test_completed)
	GameManager.test_failed.connect(_on_test_failed)

func _on_button_pressed() -> void:
	if GameManager.start_test("first_flight"):
		hide()
	else:
		HUDManager.show_message("Failed to start test", "ALERT")

func _on_test_completed() -> void:
	show()

func _on_test_failed(reason: String) -> void:
	HUDManager.show_message("Test failed: " + reason, "ALERT")
	show()
