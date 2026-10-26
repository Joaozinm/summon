class_name Tombstone
extends Node2D
## Grey headstone from primitives, left where a unit fell (code-drawn by design; not part of the
## art delivery).


func _draw() -> void:
	var stone := Color("7d828a")
	var dark := Color("3f4248")
	draw_circle(Vector2(0, -10), 11.0, dark)
	draw_rect(Rect2(-11, -10, 22, 22), dark)
	draw_circle(Vector2(0, -10), 9.0, stone)
	draw_rect(Rect2(-9, -10, 18, 20), stone)
	draw_line(Vector2(0, -15), Vector2(0, 4), dark, 2.0)
	draw_line(Vector2(-5, -9), Vector2(5, -9), dark, 2.0)
	draw_rect(Rect2(-16, 11, 32, 4), Color(0, 0, 0, 0.35))
