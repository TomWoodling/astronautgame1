extends Node3D

func _ready() -> void:
	# After world setup is complete, notify GameManager
	var player = get_tree().get_first_node_in_group("player")
	if player:
		GameManager.world_ready(player)
