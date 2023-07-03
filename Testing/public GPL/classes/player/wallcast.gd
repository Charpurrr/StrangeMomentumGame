extends Node2D

func is_colliding() -> bool:
	for child in get_children():
		if child.is_colliding():
			return true
	return false
