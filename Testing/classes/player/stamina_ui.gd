extends Label

@onready var player = $".."

@warning_ignore("unused_parameter")
func _process(delta):
	text = str("sta:", "\n", player.stamina_count)
