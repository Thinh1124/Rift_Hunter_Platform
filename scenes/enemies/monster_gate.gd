class_name MonsterGate
extends Node2D
## Cổng quái: tự sinh quái cho tới khi người chơi giữ interact đóng cổng.
##
##   Open    -> SpawnTimer mỗi spawn_interval sinh 1 quái tại SpawnPoint,
##              chỉ khi số quái còn sống của cổng này < max_alive.
##   Closing -> player trong InteractZone + giữ interact; CloseBar chạy theo
##              close_time. Thả nút hoặc rời vùng -> reset về 0, quay lại Open.
##   Closed  -> dừng spawn, anim closed, phát Smoke + gate_closed(gate_id).
##
## Đóng cổng KHÔNG xóa quái đã sinh ra, chỉ ngừng sinh thêm.
## Quái tự đi đứng/phóng/đánh, không tự về bảo vệ cổng (xem Enemy).

enum GateState { INACTIVE, OPEN, CLOSING, CLOSED }

const ANIM_OPEN: StringName = &"open_idle"
const ANIM_CLOSING: StringName = &"closing"
const ANIM_CLOSED: StringName = &"closed"
const INTERACT_ACTION: StringName = &"interact"
const FRAME_SIZE: int = 48

## Phát khi cổng đóng xong (1 lần cho mỗi lần activate).
signal closed(gate_id: StringName)

@export var gate_id: StringName = &"gate"
@export var spawn_scene: PackedScene
@export_range(0.25, 30.0, 0.25) var spawn_interval: float = 4.0
@export_range(1, 20, 1) var max_alive: int = 3
@export_range(0.25, 20.0, 0.1) var close_time: float = 2.0
@export var is_boss_gate: bool = false
## false -> vào thẳng GateState.INACTIVE (ẩn), chờ activate().
@export var start_active: bool = true
## Cần đủ 3 anim open_idle/closing/closed. Bỏ trống -> dựng hình cổng tím.
@export var frames: SpriteFrames
@export var close_sfx: StringName = &"pickup"

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var interact_zone: Area2D = $InteractZone
@onready var spawn_point: Marker2D = $SpawnPoint
@onready var spawn_timer: Timer = $SpawnTimer
@onready var close_bar: ProgressBar = $CloseBar
@onready var hint_icon: Label = $HintIcon
@onready var smoke: CPUParticles2D = $Smoke
@onready var open_glow: CPUParticles2D = $OpenGlow
@onready var audio: AudioStreamPlayer2D = $AudioStreamPlayer2D

var state: GateState = GateState.INACTIVE

var _spawned: Array[WeakRef] = []
var _close_progress: float = 0.0
var _players_inside: int = 0
var _wobble_tween: Tween


func _ready() -> void:
	add_to_group(&"gate")
	sprite.sprite_frames = frames if frames != null and frames.has_animation(ANIM_OPEN) else _build_frames()
	close_bar.max_value = 1.0
	close_bar.value = 0.0
	close_bar.hide()
	hint_icon.hide()
	smoke.emitting = false
	open_glow.emitting = false
	interact_zone.body_entered.connect(_on_zone_body_entered)
	interact_zone.body_exited.connect(_on_zone_body_exited)
	spawn_timer.wait_time = maxf(spawn_interval, 0.05)
	spawn_timer.timeout.connect(_on_spawn_timer)
	if start_active:
		activate()
	else:
		_enter(GateState.INACTIVE)


## Bật cổng đang chờ (dùng cho BigGate sau khi hạ boss).
func activate() -> void:
	if state == GateState.CLOSED:
		return
	show()
	_enter(GateState.OPEN)
	spawn_timer.start()


func alive_count() -> int:
	_prune_spawned()
	return _spawned.size()


func _physics_process(delta: float) -> void:
	_update_hint()
	match state:
		GateState.OPEN:
			if _is_closing_input():
				_enter(GateState.CLOSING)
		GateState.CLOSING:
			if not _is_closing_input():
				_enter(GateState.OPEN)
			else:
				_close_progress += delta / maxf(close_time, 0.05)
				close_bar.value = clampf(_close_progress, 0.0, 1.0)
				if _close_progress >= 1.0:
					_enter(GateState.CLOSED)


func _enter(next: GateState) -> void:
	state = next
	match next:
		GateState.INACTIVE:
			spawn_timer.stop()
			open_glow.emitting = false
			smoke.emitting = false
			_reset_bar()
			hide()
		GateState.OPEN:
			_reset_bar()
			_play(ANIM_OPEN)
			open_glow.emitting = true
		GateState.CLOSING:
			_close_progress = 0.0
			_play(ANIM_CLOSING)
			close_bar.value = 0.0
			close_bar.show()
		GateState.CLOSED:
			spawn_timer.stop()
			open_glow.emitting = false
			_play(ANIM_CLOSED)
			_reset_bar()
			hint_icon.hide()
			_players_inside_reset()
			interact_zone.set_deferred(&"monitoring", false)
			smoke.restart()
			_play_close_sfx()
			closed.emit(gate_id)
			_on_closed()


## Điểm móc cho lớp con. MonsterGate phát gate_closed, BigGate phát
## level_completed thay cho gate_closed.
func _on_closed() -> void:
	EventBus.gate_closed.emit(gate_id)


func _reset_bar() -> void:
	_close_progress = 0.0
	close_bar.value = 0.0
	close_bar.hide()


func _play(anim: StringName) -> void:
	if sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)


# --- Sinh quái -------------------------------------------------------------

func _on_spawn_timer() -> void:
	if spawn_scene == null or alive_count() >= max_alive:
		return
	var enemy := spawn_scene.instantiate()
	var parent := get_parent()
	if parent == null:
		enemy.free()
		return
	parent.add_child(enemy)
	enemy.global_position = spawn_point.global_position
	_spawned.append(weakref(enemy))
	_wobble()


func _prune_spawned() -> void:
	var alive: Array[WeakRef] = []
	for ref in _spawned:
		if is_instance_valid(ref.get_ref()):
			alive.append(ref)
	_spawned = alive


func _wobble() -> void:
	if _wobble_tween != null and _wobble_tween.is_valid():
		_wobble_tween.kill()
	sprite.scale = Vector2(1.12, 0.9)
	_wobble_tween = create_tween()
	_wobble_tween.tween_property(sprite, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- Đóng cổng -------------------------------------------------------------

func _on_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_players_inside += 1


func _on_zone_body_exited(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_players_inside = maxi(_players_inside - 1, 0)


func _players_inside_reset() -> void:
	_players_inside = 0


func _is_closing_input() -> bool:
	if _players_inside <= 0 or not Input.is_action_pressed(INTERACT_ACTION):
		return false
	var player := get_tree().get_first_node_in_group(&"player") as Player
	return player != null and player.health != null and player.health.is_alive()


func _update_hint() -> void:
	var show_hint := _players_inside > 0 and state != GateState.CLOSED and state != GateState.INACTIVE
	hint_icon.visible = show_hint


func _play_close_sfx() -> void:
	if audio != null and audio.stream != null:
		audio.play()
	else:
		AudioManager.play_sfx(close_sfx)


# --- Hình cổng dựng sẵn (thay bằng SpriteFrames thật qua @export frames) ---

func _build_frames() -> SpriteFrames:
	var built := SpriteFrames.new()
	built.remove_animation(&"default")
	built.add_animation(ANIM_OPEN)
	built.set_animation_speed(ANIM_OPEN, 8.0)
	built.set_animation_loop(ANIM_OPEN, true)
	built.add_animation(ANIM_CLOSING)
	built.set_animation_speed(ANIM_CLOSING, 10.0)
	built.set_animation_loop(ANIM_CLOSING, true)
	built.add_animation(ANIM_CLOSED)
	built.set_animation_speed(ANIM_CLOSED, 8.0)
	built.set_animation_loop(ANIM_CLOSED, false)
	for i in 4:
		var phase := float(i) / 4.0
		built.add_frame(ANIM_OPEN, _portal_texture(0.60 + 0.07 * sin(phase * TAU), 0.80 + 0.20 * sin(phase * TAU)))
	for i in 3:
		var t := float(i) / 3.0
		built.add_frame(ANIM_CLOSING, _portal_texture(lerpf(0.60, 0.18, t), lerpf(1.0, 0.45, t)))
	built.add_frame(ANIM_CLOSED, _portal_texture(0.18, 0.45))
	return built


func _portal_texture(inner_ratio: float, alpha: float) -> ImageTexture:
	var size := FRAME_SIZE
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := Vector2(size * 0.5, size * 0.5)
	var outer := size * 0.5
	var inner_r := outer * inner_ratio
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(center)
			if d <= inner_r:
				image.set_pixel(x, y, Color(0.30, 0.05, 0.45, 0.85 * alpha))
			elif d <= outer:
				var edge := 1.0 - (d - inner_r) / maxf(outer - inner_r, 0.001)
				image.set_pixel(x, y, Color(1.0, 0.35, 0.8, (0.35 + 0.65 * edge) * alpha))
	return ImageTexture.create_from_image(image)