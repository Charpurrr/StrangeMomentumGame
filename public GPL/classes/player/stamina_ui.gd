extends Label

@onready var player = $".."

func _process(_delta):
	text = str(
		"doublejump:", "\n", str(player.jumps > 0),
		"\n",
		"wall climbs:", "\n", player.wall_climb_count,
		"\n",
		"dashes:", "\n", player.dash_count,
		)
