extends Node2D
## Visual summon portal. Boss owns its timing and spawn lifecycle.

func _draw() -> void:
	draw_circle(Vector2.ZERO, 22.0, Color(0.3, 0.05, 0.45, 0.85))
	draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 32, Color(1, 0.35, 0.8), 3.0)
	draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 32, Color(0.7, 0.6, 1), 2.0)
