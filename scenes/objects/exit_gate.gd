class_name ExitGate
extends Area2D
## Cổng ra: bắt buộc thu đủ GameManager.SHARDS_REQUIRED shard mới kích hoạt.
## Chạm khi đang Locked/Opening: bỏ qua. Open: phát level_completed đúng 1 lần.

enum ExitState { LOCKED, OPENING, OPEN }

const ANIM_LOCKED: StringName = &"locked"
const ANIM_OPENING: StringName = &"opening"
const ANIM_OPEN: StringName = &"open"
const GLOW_SIZE: int = 64
const DEFAULT_FRAMES: SpriteFrames = preload("res://assets/frames/gate.tres")

signal completed

## Cần đủ 3 anim locked/opening/open. Bỏ trống -> dùng assets/Gate/93.png.
@export var frames: SpriteFrames = DEFAULT_FRAMES
## Ánh sáng quanh cổng khi mở. Bỏ trống -> dựng vòng sáng vàng.
@export var glow_texture: Texture2D
@export var open_sfx: StringName = &"gate_open"

@onready var sprite: AnimatedSprite2D = %Sprite
@onready var glow: Sprite2D = %Glow
@onready var audio: AudioStreamPlayer2D = %AudioStreamPlayer2D

var state: ExitState = ExitState.LOCKED

var _completed: bool = false
var _open_elapsed: float = 0.0


func _process(delta: float) -> void:
	# Chống kẹt nếu animation_finished không về (ví dụ anim bị thay lúc chạy).
	if state == ExitState.OPENING:
		_open_elapsed += delta
		if not sprite.is_playing() or _open_elapsed >= 2.0:
			_enter(ExitState.OPEN)


func _ready() -> void:
	sprite.sprite_frames = frames if _has_gate_animations(frames) else DEFAULT_FRAMES
	glow.texture = glow_texture if glow_texture != null else _make_glow_texture()
	glow.visible = false
	body_entered.connect(_on_body_entered)
	sprite.animation_finished.connect(_on_animation_finished)
	EventBus.shards_changed.connect(_on_shards_changed)
	if GameManager.shards_complete():
		_unlock()
	else:
		_enter(ExitState.LOCKED)


## Đủ mảnh Rift -> mở cánh cổng. Người chơi phải đánh quái gom đủ mảnh rồi
## mới chạm cổng mới qua được màn.
func _on_shards_changed(_collected: int, _required: int) -> void:
	if _completed:
		return
	if GameManager.shards_complete():
		_unlock()
	elif state != ExitState.LOCKED:
		_enter(ExitState.LOCKED)


func _unlock() -> void:
	if state != ExitState.LOCKED or not GameManager.shards_complete():
		return
	_enter(ExitState.OPENING)
	_play_open_sfx()


func _enter(next: ExitState) -> void:
	state = next
	match next:
		ExitState.LOCKED:
			glow.visible = false
			sprite.modulate = Color(0.55, 0.55, 0.6, 1.0)
			_play(ANIM_LOCKED)
		ExitState.OPENING:
			_open_elapsed = 0.0
			sprite.modulate = Color.WHITE
			glow.visible = true
			_play(ANIM_OPENING)
		ExitState.OPEN:
			glow.visible = true
			_play(ANIM_OPEN)
			# Player có thể đã đứng sẵn trong vùng lúc cổng mở -> không có
			# body_entered mới, nên phải quét lại thân xác đang chạm.
			_try_complete_inside.call_deferred()


func _on_animation_finished() -> void:
	if state == ExitState.OPENING:
		_enter(ExitState.OPEN)


func _try_complete_inside() -> void:
	if state != ExitState.OPEN or _completed:
		return
	for body in get_overlapping_bodies():
		_try_complete(body)
		if _completed:
			return


func _on_body_entered(body: Node2D) -> void:
	_try_complete(body)


func _try_complete(body: Node2D) -> void:
	if _completed or state != ExitState.OPEN or not GameManager.shards_complete() or not body.is_in_group(&"player"):
		return
	var player := body as Player
	if player == null or player.health == null or not player.health.is_alive():
		return
	_completed = true
	set_deferred(&"monitoring", false)
	EventBus.level_completed.emit()
	completed.emit()


func is_completed() -> bool:
	return _completed


func _play(anim: StringName) -> void:
	if sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)


func _play_open_sfx() -> void:
	if audio != null and audio.stream != null:
		audio.play()
	else:
		AudioManager.play_sfx(open_sfx)


# --- SpriteFrames và ánh sáng -------------------------------------------

func _has_gate_animations(candidate: SpriteFrames) -> bool:
	return candidate != null and candidate.has_animation(ANIM_LOCKED) \
		and candidate.has_animation(ANIM_OPENING) and candidate.has_animation(ANIM_OPEN)


func _make_glow_texture() -> ImageTexture:
	var image := Image.create(GLOW_SIZE, GLOW_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := Vector2(GLOW_SIZE * 0.5, GLOW_SIZE * 0.5)
	var outer := GLOW_SIZE * 0.5
	for y in GLOW_SIZE:
		for x in GLOW_SIZE:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(center) / outer
			if d <= 1.0:
				image.set_pixel(x, y, Color(1.0, 0.93, 0.65, 0.40 * (1.0 - d)))
	return ImageTexture.create_from_image(image)
