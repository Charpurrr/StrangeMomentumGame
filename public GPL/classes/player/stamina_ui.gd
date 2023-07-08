extends Label

@onready var player = $".."

@warning_ignore("unused_parameter")
func _process(delta):
	text = str(
		"doublejump:", "\n", str(player.jumps > 0),
		"\n",
		"wall climbs:", "\n", player.wall_climb_count,
		"\n",
		"dashes:", "\n", player.dash_count,
		)
