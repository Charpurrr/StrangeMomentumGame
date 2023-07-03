extends Label

@onready var player = $".."

@warning_ignore("unused_parameter")
func _process(delta):
	text = str(
		"walljumps:", "\n", player.wall_jump_count,
		"\n",
		"dashes:", "\n", player.dash_count
		)
