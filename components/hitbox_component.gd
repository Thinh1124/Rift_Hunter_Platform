class_name HitboxComponent
extends Area2D
## Vùng gây sát thương. Không tự gây damage - HurtboxComponent bên nhận sẽ xử lý.

@export var damage: int = 1
@export var knockback: Vector2 = Vector2(150, -150)
## Opt in to this hitbox's knockback instead of Player's default hit response.
@export var apply_knockback: bool = false
## false = tắt CollisionShape (không va chạm, không gây đòn).
@export var active: bool = true


func _ready() -> void:
	set_active(active, true)


## Bật/tắt toàn bộ CollisionShape con bằng call_deferred (an toàn khi gọi trong _physics_process).
func set_active(value: bool, force: bool = false) -> void:
	if active == value and not force:
		return
	active = value
	for child in get_children():
		var shape := child as CollisionShape2D
		if shape != null:
			shape.set_deferred(&"disabled", not value)


func is_active() -> bool:
	return active
