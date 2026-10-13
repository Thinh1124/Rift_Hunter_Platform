class_name EnemySpawner
extends Node2D
## Vùng kích hoạt quái: player bước vào TriggerZone -> thả `count` quái ngẫu nhiên
## trong bán kính `radius` quanh spawner, mỗi con kèm một puff khói nhỏ.
##
## once = true  -> chỉ đổ một lần rồi tắt TriggerZone.
## once = false -> mỗi lần player rời rồi vào lại đều đổ tiếp.
##
## Mặc định enemy_scene = SummonedPatrolEnemy. Enemy.tscn gốc dùng layer cũ:
## Hurtbox mask = bit Enemy trong khi ContactHitbox cũng nằm trên bit Enemy, nên
## quái tự đánh chết mình sau vài nhịp. SummonedPatrolEnemy đã sửa (mask 8 /
## layer 16). Chọn scene quái khác trong Inspector thì cần kiểm tra layer.

@export var enemy_scene: PackedScene
@export_range(1, 50, 1) var count: int = 1
@export_range(0.0, 512.0, 1.0) var radius: float = 48.0
@export var once: bool = true

@onready var trigger_zone: Area2D = $TriggerZone

var _spawned: int = 0
var _pending: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	trigger_zone.body_entered.connect(_on_trigger_body_entered)


func spawned_count() -> int:
	return _spawned


func _on_trigger_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"player"):
		return
	if _pending or (once and _spawned > 0):
		return
	# Area2D đang flush truy vấn vật lý khi phát body_entered: add_child ở đây sẽ
	# bị physics server từ chối, nên phải hoãn sang khung sau.
	_pending = true
	_spawn_batch.call_deferred()


func _spawn_batch() -> void:
	_pending = false
	if enemy_scene == null:
		push_warning("EnemySpawner: chưa gán enemy_scene.")
		return
	var parent := get_parent()
	if parent == null:
		push_warning("EnemySpawner: cần Node cha để gắn quái.")
		return
	for i in count:
		var at := global_position + _random_offset()
		var enemy := enemy_scene.instantiate()
		parent.add_child(enemy)
		enemy.global_position = at
		DustFX.spawn(parent, at)
	_spawned += count
	if once:
		trigger_zone.set_deferred(&"monitoring", false)


## Lấy điểm ngẫu nhiên đều trong hình tròn bán kính radius.
func _random_offset() -> Vector2:
	if radius <= 0.0:
		return Vector2.ZERO
	var angle := _rng.randf() * TAU
	return Vector2.from_angle(angle) * (_rng.randf() * radius)