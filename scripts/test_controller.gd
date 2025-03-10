extends Node

signal test_completed
signal test_failed(reason: String)

var config: Dictionary
var test_timer: Timer
var test_active: bool = false
var world_scene = preload("res://scenes/world.tscn")

func _ready() -> void:
	AchievementManager.achievement_unlocked.connect(_on_achievement_unlocked)

func load_test(test_id: String) -> bool:
	var file = FileAccess.open("res://tests/" + test_id + "_test.json", FileAccess.READ)
	if not file:
		test_failed.emit("Failed to load test configuration")
		return false
		
	var json = JSON.new()
	var parse_result = json.parse(file.get_as_text())
	file.close()
	
	if parse_result != OK:
		test_failed.emit("Failed to parse test configuration")
		return false
		
	config = json.data
	return true

func start_test() -> void:
	if not config:
		test_failed.emit("No test configuration loaded")
		return
	
	test_active = true
	
	# Show welcome message if configured
	if config.has("welcome_message"):
		var welcome = config.welcome_message
		if welcome.has("delay"):
			get_tree().create_timer(welcome.delay).timeout.connect(
				func(): HUDManager.show_message(welcome.text, welcome.type)
			)
		else:
			HUDManager.show_message(welcome.text, welcome.type)
	
	# Start test duration timer if specified
	if config.has("duration"):
		test_timer = Timer.new()
		add_child(test_timer)
		test_timer.wait_time = config.duration
		test_timer.timeout.connect(_on_test_timeout)
		test_timer.start()
	
	# Change to world scene with test configuration
	get_tree().change_scene_to_packed(world_scene)

func _on_achievement_unlocked(achievement_name: String) -> void:
	if not test_active or not config.has("completion_achievement"):
		return
		
	if achievement_name == config.completion_achievement:
		_complete_test()

func _complete_test() -> void:
	if test_active:
		test_completed.emit()
		test_active = false
		queue_free()

func _on_test_timeout() -> void:
	if test_active:
		if config.has("completion_achievement"):
			if not AchievementManager.has_achievement(config.completion_achievement):
				test_failed.emit("Test timed out without achieving objective")
				return
		_complete_test()
