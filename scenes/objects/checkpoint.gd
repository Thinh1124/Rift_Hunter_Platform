class_name Checkpoint
extends Area2D
## Cờ checkpoint: player chạm lần đầu -> cờ bay, lưu điểm hồi sinh.
##
## layer = 7 (Interactable), mask = 2 (Player): chỉ cần chạm, không bấm interact.
## Chỉ kích hoạt 1 lần/nv; đi qua lần sau không phát lại.
##
## Đặt node tại đúng chỗ muốn hồi sinh (giống PlayerSpawn), cờ vẽ lệch lên trên.

## Phát đúng 1 lần khi cờ chuyển sang trạng thái đã chạm.
signal reached(pos: Vector2)

const ANIM_LOCKED: StringName = &"off"
const ANIM_WAVING: StringName = &"on"

## res://assets/frames/checkpoint_off_frames.tres - cờ chưa chạm.
@export var frames_locked: SpriteFrames
## res://assets/frames/checkpoint_on_frames.tres - cờ đang bay.
@export var frames_waving: SpriteFrames
## Tên trong res://assets/audio/sfx/ (AudioManager nạp theo tên file).
@export var sfx: StringName = &"checkpoint"

@onready var sprite: AnimatedSprite2D = $Sprite

var _reached: bool = false


func _ready() -> void:
	add_to_group(&"checkpoint")
	body_entered.connect(_on_body_entered)
	_apply_frames(frames_locked, ANIM_LOCKED)


func _on_body_entered(body: Node2D) -> void:
	if _reached or not body.is_in_group(&"player"):
		return
	var player := body as Player
	if player == null or player.health == null or not player.health.is_alive():
		return
	_reached = true
	set_deferred(&"monitoring", false)
	_apply_frames(frames_waving, ANIM_WAVING)
	var pos := respawn_point()
	GameManager.last_checkpoint = pos
	EventBus.checkpoint_reached.emit(pos)
	PickupFX.spawn(get_parent(), global_position)
	AudioManager.play_sfx(sfx)
	reached.emit(pos)


## Điểm hồi sinh = vị trí node. Lệch 1px nếu trùng gốc toạ độ vì
## Player.respawn_position() coi Vector2.ZERO là "chưa có checkpoint".
func respawn_point() -> Vector2:
	var pos := global_position
	if pos == Vector2.ZERO:
		pos += Vector2(0, -1)
	return pos


func is_reached() -> bool:
	return _reached


func _apply_frames(frames: SpriteFrames, anim: StringName) -> void:
	if frames == null or not frames.has_animation(anim):
		return
	sprite.sprite_frames = frames
	sprite.play(anim)
