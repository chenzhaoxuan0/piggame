extends Node

# The game's real front door: boot STRAIGHT into the pigpen tutorial - no boot
# menu screen, no dimmed start menu over the world. The dream intro and the
# in-game start menu stay reachable (pause menu / level select / tests); this
# scene only stamps the hand-off flag and swaps to the level scene.

func _ready() -> void:
	var game: Node = get_node("/root/GameManager")
	if game != null:
		game.pending_boot = "farm"
	# Deferred on purpose: change_scene_to_file removes the current scene from
	# root right away, and inside _ready() root is still busy adding this very
	# node - a direct call logs "Parent node is busy adding/removing children"
	# on every single boot.
	get_tree().change_scene_to_file.call_deferred("res://scenes/levels/office_level_1.tscn")
