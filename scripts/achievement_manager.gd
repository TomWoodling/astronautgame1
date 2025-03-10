extends Node

signal achievement_unlocked(achievement_name: String)

var unlocked_achievements: Dictionary = {}

func unlock_achievement(achievement_name: String) -> void:
	if unlocked_achievements.has(achievement_name):
		return
		
	unlocked_achievements[achievement_name] = true
	achievement_unlocked.emit(achievement_name)
	HUDManager.show_message("Achievement Unlocked: " + achievement_name, "ACHIEVEMENT")

func has_achievement(achievement_name: String) -> bool:
	return unlocked_achievements.has(achievement_name)
