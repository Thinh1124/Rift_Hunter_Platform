class_name Pickup
extends Area2D
## Parent scene for RiftShard and Shield. Each collection is applied once.
##
## mask = 2 (Player): Player phải chạm vào (dùng cơ thể, không cần bấm interact).

## Phát khi đã nhặt: kind, số lượng, node người chơi.
signal collected(kind: StringName, amount: int, by: Node)

## &"shard" | &"shield"
@export var kind: StringName = &"shard"
## Số lượng (trái cây/tim). Khiên luôn dùng GameManager.SHIELD_DURATION.
@export_range(1, 99, 1) var amount: int = 1
@export var value: int = 100
@export var bob_height: float = 3.0
@export var bob_speed: float = 3.0
## Cho đồ xoay (cần "spin" trong SpriteFrames).
@export var spin: bool = true
@export var sprite_frames: SpriteFrames
@export var sprite: AnimatedSprite2D

var _taken: bool = false
var _base_y: float = 0.0
var _bob_time: float = 0.0


func _ready() -> void:
	add_to_group(&"pickup")
	_base_y = position.y
	sprite = sprite if sprite != null else get_node_or_null(^"Sprite") as AnimatedSprite2D
	body_entered.connect(_on_body_entered)
	if sprite != null and sprite_frames != null:
		sprite.sprite_frames = sprite_frames
		if spin and sprite.sprite_frames.has_animation(&"spin"):
			sprite.play(&"spin")
		elif not sprite.sprite_frames.get_animation_names().is_empty():
			sprite.play(sprite.sprite_frames.get_animation_names()[0])


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _taken:
		return
	_bob_time += delta * bob_speed
	position.y = _base_y + sin(_bob_time) * bob_height


func _on_body_entered(body: Node2D) -> void:
	if _taken or not body.is_in_group(&"player"):
		return
	var player := body as Player
	if player == null or player.health == null or not player.health.is_alive():
		return
	_taken = true
	set_deferred(&"monitoring", false)
	match kind:
		&"shard":
			GameManager.add_score(value)
			GameManager.add_shards(amount)
		&"shield":
			player.add_shield(8.0)
	PickupFX.spawn(get_parent(), global_position)
	AudioManager.play_sfx(&"pickup")
	collected.emit(kind, amount, body)
	queue_free()
