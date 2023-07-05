extends Area2D

@onready var player = $"../.."


func _physics_process(delta):
	get_parent().disabled = (has_overlapping_bodies() or player.vel.y < 0 
	or Input.get_axis("left", "right") == 0)

