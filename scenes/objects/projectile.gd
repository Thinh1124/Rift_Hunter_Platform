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
## Góc ảnh gốc; đổi dấu khi bắn trái để mũi đạn luôn hướng theo đường bay.
@export var sprite_rotation: float = 0.0
@export var launch_sfx: StringName = &"player_attack"
@export var impact_sfx: StringName = &"projectile_hit"

@onready var sprite: AnimatedSprite2D = %Sprite

var _life_left: float = 0.0
var _impact_played: bool = false


func _ready() -> void:
	super()
	_life_left = life
	sprite.flip_h = direction < 0
	sprite.rotation = sprite_rotation * float(direction)
	sprite.play(&"fly")
	AudioManager.play_sfx(launch_sfx)
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
	_play_impact()
	queue_free()


## Enemy Hurtbox tự trừ máu qua HitboxComponent này, đạn chỉ tự hủy.
func _on_area_entered(_area: Area2D) -> void:
	_play_impact()
	queue_free()


func _play_impact() -> void:
	if _impact_played:
		return
	_impact_played = true
	AudioManager.play_sfx(impact_sfx)


func _on_screen_exited() -> void:
	queue_free()
