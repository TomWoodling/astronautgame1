extends Node

const ICON_PATHS = {
	"npc": preload("res://assets/icons/npc_icon.png"),
	"achievement": preload("res://assets/icons/achievement.png"),
	"hazard": preload("res://assets/icons/hazard.png")
}

func get_icon(type: String) -> Texture2D:
	return ICON_PATHS.get(type, ICON_PATHS.npc)  # Default to NPC icon if type not found
