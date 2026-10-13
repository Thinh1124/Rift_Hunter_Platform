class_name ExitGate
extends Area2D
## Cổng ra: khóa cho tới khi đóng hết cổng quái, rồi player chạm là hoàn thành ải.
##
## Locked -> EventBus.gates_changed(remaining <= 0 hoặc total == 0) -> Opening -> Open.
##   total == 0 (ải không có MonsterGate nào) -> mở ngay.
## Chạm khi đang Locked/Opening: bỏ qua. Open: phát level_completed đúng 1 lần.

enum ExitState { LOCKED, OPENING, OPEN }

const ANIM_LOCKED: StringName = &"locked"
const ANIM_OPENING: StringName = &"opening"
const ANIM_OPEN: StringName = &"open"
const GLOW_SIZE: int = 64

signal completed

@export var requires_all_gates: bool = true
## Cần đủ 3 anim locked/opening/open. Bỏ trống -> dựng hình cổng ra.
@export var frames: SpriteFrames
## Ánh sáng quanh cổng khi mở. Bỏ trống -> dựng vòng sáng vàng.
@export var glow_texture: Texture2D
@export var open_sfx: StringName = &"pickup"

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var glow: Sprite2D = $Glow
@onready var audio: AudioStreamPlayer2D = $AudioStreamPlayer2D

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
	sprite.sprite_frames = frames if frames != null and frames.has_animation(ANIM_LOCKED) else _build_frames()
	glow.texture = glow_texture if glow_texture != null else _make_glow_texture()
	glow.visible = false
	body_entered.connect(_on_body_entered)
	sprite.animation_finished.connect(_on_animation_finished)
	EventBus.gates_changed.connect(_on_gates_changed)
	EventBus.shards_changed.connect(_on_shards_changed)
	if not requires_all_gates:
		_unlock()
	elif GameManager.shards_complete():
		_unlock()
	else:
		_enter(ExitState.LOCKED)


func _on_gates_changed(remaining: int, total: int) -> void:
	if state != ExitState.LOCKED or not requires_all_gates:
		return
	if total <= 0 or remaining <= 0:
		_unlock()


## Đủ mảnh Rift -> mở cánh cổng. Người chơi phải đánh quái gom đủ mảnh rồi
## mới chạm cổng mới qua được màn.
func _on_shards_changed(collected: int, required: int) -> void:
	if state != ExitState.LOCKED or not requires_all_gates:
		return
	if required > 0 and collected >= required:
		_unlock()


func _unlock() -> void:
	if state != ExitState.LOCKED:
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
	if _completed or state != ExitState.OPEN or not body.is_in_group(&"player"):
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


# --- Hình dựng sẵn (thay bằng SpriteFrames thật qua @export frames) --------

func _build_frames() -> SpriteFrames:
	var built := SpriteFrames.new()
	built.remove_animation(&"default")
	built.add_animation(ANIM_LOCKED)
	built.set_animation_speed(ANIM_LOCKED, 6.0)
	built.set_animation_loop(ANIM_LOCKED, true)
	built.add_animation(ANIM_OPENING)
	built.set_animation_speed(ANIM_OPENING, 10.0)
	built.set_animation_loop(ANIM_OPENING, false)
	built.add_animation(ANIM_OPEN)
	built.set_animation_speed(ANIM_OPEN, 8.0)
	built.set_animation_loop(ANIM_OPEN, true)
	for i in 4:
		built.add_frame(ANIM_LOCKED, _gate_texture(0.55))
	for i in 4:
		var t := float(i) / 4.0
		built.add_frame(ANIM_OPENING, _gate_texture(lerpf(0.20, 0.90, t)))
	for i in 4:
		var pulse := float(i) / 4.0
		built.add_frame(ANIM_OPEN, _gate_texture(0.86 + 0.04 * sin(pulse * TAU)))
	return built


## Khung 48x48 kiểu RIFT: hai cánh đá trái/phải ôm lấy một khe nứt dọc.
## open_ratio 0 = cánh khép kín khe, 1 = cánh rút hết, khe nứt sáng lóa.
func _gate_texture(open_ratio: float) -> ImageTexture:
	var size := 48
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var t := clampf(open_ratio, 0.0, 1.0)
	var stone := Color(0.30, 0.26, 0.40).lerp(Color(0.55, 0.45, 0.75), t)
	var stone_hi := stone.lightened(0.28)
	var rift := Color(0.35, 0.80, 0.98).lerp(Color(0.85, 0.98, 1.0), t)

	# Khoảng cách mép trong của hai cánh: 0 -> khép, 1 -> rút hẳn ra ngoài.
	var inner := lerpf(21.0, 6.0, t)
	var cx := float(size) * 0.5
	var top := 5
	var bottom := size - 3
	for y in range(top, bottom):
		for x in range(4, size - 4):
			var p := Vector2(x + 0.5, y + 0.5)
			var d_left := absf(p.x - cx)
			# Mép trong hai cánh.
			if d_left >= inner:
				image.set_pixel(x, y, stone_hi if (x % 4) < 2 else stone)
			# Khe nứt: sáng dần, chỉ hiện khi cánh đã rút.
			elif t > 0.0:
				var glow: float = (1.0 - d_left / maxf(inner, 1.0)) * 0.85 + 0.15
				image.set_pixel(x, y, Color(rift.r, rift.g, rift.b, clampf(glow, 0.0, 1.0)))
	# Vạch sáng chạy dọc mép khe -> cảm giác "rung" của rift.
	for y in range(top, bottom, 3):
		for x in range(int(cx - inner) + 1, int(cx - inner) + 2):
			if x >= 4 and x < size - 4:
				image.set_pixel(x, y, rift.lightened(0.4))
	return ImageTexture.create_from_image(image)


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