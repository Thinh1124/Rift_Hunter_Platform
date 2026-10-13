class_name HealthComponent
extends Node
## Máu dùng chung cho Player / Enemy / Boss.

signal health_changed(cur: int, max: int)
signal damaged(amount: int, from_pos: Vector2)
signal died

@export_range(1, 999, 1) var max_health: int = 3
## Máu hiện tại. Được reset() nạp lại từ max_health khi vào scene.
var current: int = 0
## true = take_damage() bị bỏ qua.
@export var invincible: bool = false


func _ready() -> void:
	reset()


func reset() -> void:
	current = max_health
	invincible = false
	health_changed.emit(current, max_health)


## Trừ máu. Bỏ qua nếu đang bất tử, đã chết, hoặc amount <= 0.
func take_damage(amount: int, from_pos: Vector2 = Vector2.ZERO) -> void:
	if invincible or current <= 0 or amount <= 0:
		return
	current = maxi(current - amount, 0)
	damaged.emit(amount, from_pos)
	health_changed.emit(current, max_health)
	if current <= 0:
		died.emit()


func heal(amount: int) -> void:
	if amount <= 0 or current <= 0:
		return
	var healed_amount: int = mini(amount, max_health - current)
	if healed_amount <= 0:
		return
	current += healed_amount
	health_changed.emit(current, max_health)


func is_alive() -> bool:
	return current > 0


func health_ratio() -> float:
	if max_health <= 0:
		return 0.0
	return clampf(float(current) / float(max_health), 0.0, 1.0)