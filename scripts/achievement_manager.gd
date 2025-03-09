extends Node

signal achievement_unlocked(achievement_id)
signal achievement_progress_updated(achievement_id, current, total)  # Renamed signal

const ACHIEVEMENT_DATA = {
	"first_flight": {
		"name": "First Flight",
		"description": "Complete the tutorial",
		"icon": preload("res://assets/icons/achievement_first_flight.png"),
		"secret": false
	}
	# Add more achievements here
}

var unlocked_achievements: Dictionary = {}
var achievement_progress: Dictionary = {}

func _ready() -> void:
	load_achievements()

func unlock_achievement(achievement_id: String) -> void:
	if not ACHIEVEMENT_DATA.has(achievement_id) or unlocked_achievements.has(achievement_id):
		return
		
	unlocked_achievements[achievement_id] = Time.get_unix_time_from_system()
	achievement_unlocked.emit(achievement_id)
	HUDManager.show_message(
		"Achievement Unlocked: " + ACHIEVEMENT_DATA[achievement_id].name,
		"ACHIEVEMENT"
	)
	save_achievements()

func update_progress(achievement_id: String, current: int, total: int) -> void:
	if not ACHIEVEMENT_DATA.has(achievement_id) or unlocked_achievements.has(achievement_id):
		return
		
	achievement_progress[achievement_id] = {"current": current, "total": total}
	achievement_progress_updated.emit(achievement_id, current, total)  # Updated signal name
	
	if current >= total:
		unlock_achievement(achievement_id)

func save_achievements() -> void:
	var save_data = {
		"unlocked": unlocked_achievements,
		"progress": achievement_progress
	}
	var save_file = FileAccess.open("user://achievements.save", FileAccess.WRITE)
	save_file.store_string(JSON.stringify(save_data))

func load_achievements() -> void:
	if not FileAccess.file_exists("user://achievements.save"):
		return
		
	var save_file = FileAccess.open("user://achievements.save", FileAccess.READ)
	var save_data = JSON.parse_string(save_file.get_as_text())
	if save_data:
		unlocked_achievements = save_data.get("unlocked", {})
		achievement_progress = save_data.get("progress", {})
