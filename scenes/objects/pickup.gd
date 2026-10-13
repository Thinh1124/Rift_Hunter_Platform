class_name Pickup
extends Area2D
## Đồ nhặt dùng chung cho cả Trái cây / Tim / Khiên - chỉ đổi `kind` trong Inspector.
## Player KHÔNG biết Fruit/Heart: nó chỉ nhận lệnh heal() / add_shield() từ
## GameManager.apply_pickup().
##
## mask = 2 (Player): Player phải chạm vào (dùng cơ thể, không cần bấm interact).

## Phát khi đã nhặt: kind, số lượng, node người chơi.
signal collected(kind: StringName, amount: int, by: Node)

## &"fruit" | &"heart" | &"shield"
@export var kind: StringName = &"fruit"
## Số lượng (trái cây/tim). Khiên luôn dùng GameManager.SHIELD_DURATION.
@export_range(1, 99, 1) var amount: int = 1
## Cho đồ xoay (cần "spin" trong SpriteFrames).
@export var spin: bool = true
@export var sprite_frames: SpriteFrames
@export var sprite: AnimatedSprite2D

var _taken: bool = false


func _ready() -> void:
	add_to_group(&"pickup")
	body_entered.connect(_on_body_entered)
	if sprite != null and sprite_frames != null:
		sprite.sprite_frames = sprite_frames
		if spin and sprite.sprite_frames.has_animation(&"spin"):
			sprite.play(&"spin")
		elif not sprite.sprite_frames.get_animation_names().is_empty():
			sprite.play(sprite.sprite_frames.get_animation_names()[0])


func _on_body_entered(body: Node2D) -> void:
	if _taken:
		return
	_taken = true
	set_deferred(&"monitoring", false)
	GameManager.apply_pickup(kind, amount, body)
	PickupFX.spawn(get_parent(), global_position)
	collected.emit(kind, amount, body)
	queue_free()