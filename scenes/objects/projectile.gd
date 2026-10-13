class_name Projectile
extends HitboxComponent
## Đạn ném của Player. Bay ngang theo hệ số `direction`, tự hủy sau `life` giây,
## hoặc ngay khi chạm World (tường) / Enemy, hoặc khi lọt khỏi màn hình.
##
## Sát thương KHÔNG do Projectile tự trừ: HitboxComponent chỉ là "vùng đánh",
## HealthComponent của đối phương (qua HurtboxComponent) tự nhận damage từ đây.

## px/s theo trục X.
@export var speed: float = 250.0
## Thời gian sống tối đa (giây).
@export var life: float = 1.5
## 1 = sang phải, -1 = sang trái. Player set khi spawn.
@export var direction: int = 1

@onready var sprite: Sprite2D = get_node_or_null(^"Sprite") as Sprite2D

var _life_left: float = 0.0


func _ready() -> void:
	super()
	_life_left = life
	sprite.flip_h = direction < 0
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	var notifier := get_node_or_null(^"VisibleOnScreenNotifier2D") as VisibleOnScreenNotifier2D
	if notifier != null:
		notifier.screen_exited.connect(_on_screen_exited)


func _physics_process(delta: float) -> void:
	global_position += Vector2(float(direction) * speed, 0.0) * delta
	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()


## mask = World(1) | Enemy(3): chạm tường hoặc quái là mất đạn.
func _on_body_entered(_body: Node2D) -> void:
	queue_free()


## Enemy Hurtbox tự trừ máu qua HitboxComponent này, đạn chỉ tự hủy.
func _on_area_entered(_area: Area2D) -> void:
	queue_free()


func _on_screen_exited() -> void:
	queue_free()