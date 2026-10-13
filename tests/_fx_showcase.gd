extends Node2D

func _ready() -> void:
	while true:
		DustFX.spawn(self, Vector2(200, 180))
		PickupFX.spawn(self, Vector2(420, 180))
		await get_tree().create_timer(0.09).timeout
