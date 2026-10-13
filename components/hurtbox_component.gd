class_name HurtboxComponent
extends Area2D
## Vùng nhận sát thương. Khi area_entered chạm HitboxComponent -> truyền sát thương
## cho HealthComponent được gán.
## Nhớ chỉnh collision_mask để trùng layer của HitboxComponent đối phương.

signal hit_received(hitbox: HitboxComponent)

@export var health: HealthComponent
## > 0 = sau mỗi lần trúng đòn, chặn thêm đòn trong N giây.
@export_range(0.0, 5.0, 0.01) var one_shot_per_hit_time: float = 0.0
## Nhân lực đẩy lên người bị đánh (chưa áp dụng, để cho Enemy/Player xử lý).
@export var knockback_resist: float = 0.0

var _last_hit_msec: int = -1


func _ready() -> void:
	if health == null:
		health = get_parent().find_child(^"HealthComponent", true, false) as HealthComponent
	if health == null:
		push_warning("HurtboxComponent (%s) chưa gán HealthComponent." % name)
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	var hitbox := area as HitboxComponent
	if hitbox == null or not hitbox.is_active():
		return
	# invincible / đã chết -> không coi là trúng đòn, không phát hit_received.
	if health == null or health.invincible or not health.is_alive():
		return
	if not _can_receive_hit():
		return
	_mark_hit()
	health.take_damage(hitbox.damage, hitbox.global_position)
	hit_received.emit(hitbox)


func _can_receive_hit() -> bool:
	if one_shot_per_hit_time <= 0.0:
		return true
	if _last_hit_msec < 0:
		return true
	var elapsed: float = float(Time.get_ticks_msec() - _last_hit_msec) / 1000.0
	return elapsed >= one_shot_per_hit_time


func _mark_hit() -> void:
	_last_hit_msec = Time.get_ticks_msec()


func reset_hit_cooldown() -> void:
	_last_hit_msec = -1
