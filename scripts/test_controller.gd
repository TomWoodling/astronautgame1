extends Node

signal test_completed
signal test_failed(reason: String)

var config: Dictionary
var test_timer: Timer
var test_active: bool = false

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
	
	# Setup initial conditions
	var initial = config.get("initial_setup", {})
	
	# Spawn player at specified position
	if initial.has("player_position"):
		var pos = initial.player_position
		GameManager.player.global_position = Vector3(pos.x, pos.y, pos.z)
	
	# Show welcome message after delay
	if initial.has("welcome_message"):
		var welcome = initial.welcome_message
		get_tree().create_timer(welcome.delay).timeout.connect(
			func(): HUDManager.show_message(welcome.text, welcome.type)
		)
	
	# Setup tutorial platform
	if config.has("tutorial_platform"):
		_setup_tutorial_platform()
	
	# Start test duration timer
	test_timer = Timer.new()
	add_child(test_timer)
	test_timer.wait_time = config.duration
	test_timer.timeout.connect(_on_test_timeout)
	test_timer.start()

func _setup_tutorial_platform() -> void:
	var platform_data = config.tutorial_platform
	var pos = platform_data.position
	
	# Create platform through world generator
	var world = get_tree().get_first_node_in_group("world")
	if world:
		world.create_test_platform(
			Vector3(pos.x, pos.y, pos.z),
			platform_data.type,
			platform_data.interaction_data
		)

func _on_test_timeout() -> void:
	if test_active:
		test_completed.emit()
		test_active = false
		queue_free()

func _ready() -> void:
	# Connect to achievement signal to check for test completion
	AchievementManager.achievement_unlocked.connect(_on_achievement_unlocked)

func _on_achievement_unlocked(achievement_name: String) -> void:
	if not test_active:
		return
		
	if achievement_name == config.tutorial_platform.interaction_data.on_complete.achievement:
		var message = config.tutorial_platform.interaction_data.on_complete.message
		HUDManager.show_message(message, "ACHIEVEMENT")
