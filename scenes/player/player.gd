class_name Player
extends CharacterBody2D
## Nhân vật platformer. Điều khiển qua InputMap (move_left, move_right, jump,
## attack) nên hoạt động với bàn phím, gamepad và nút cảm ứng đều như nhau.
##
## Player KHÔNG biết nhân vật nào: mọi hình + chỉ số đến từ
## GameManager.selected_character (1 file .tres / nhân vật).
## Các @export bên dưới là giá trị GỐC, CharacterData nhân thêm hệ số
## (speed_mult / jump_mult / max_hp_bonus / attack_cooldown_mult).

signal landed
signal died
signal damaged(amount: int, from_pos: Vector2)

const GROUP: StringName = &"player"
## Marker2D điểm spawn đầu màn - Level đặt vào group này.
const GROUP_SPAWN: StringName = &"player_spawn"
const STATE_IDLE: StringName = &"Idle"
const STATE_RUN: StringName = &"Run"
const STATE_JUMP: StringName = &"Jump"
const STATE_FALL: StringName = &"Fall"
const STATE_HIT: StringName = &"Hit"
const STATE_DEAD: StringName = &"Dead"

# Giá trị gốc - dùng làm mẫu số khi tính hệ số nhân.
const BASE_SPEED: float = 120.0
const BASE_ACCEL: float = 800.0
const BASE_FRICTION: float = 900.0
const BASE_JUMP: float = -294.0
const BASE_GRAVITY: float = 900.0
const BASE_MAX_FALL: float = 400.0
const BASE_COYOTE: float = 0.1
const BASE_BUFFER: float = 0.1

@export_group("Movement")
@export var speed: float = 120.0
@export var accel: float = 800.0
@export var friction: float = 900.0
## -294 với gravity 900 -> đỉnh nhảy 294^2/(2*900) = 48px = đúng 3 tile 16px.
@export var jump_velocity: float = -294.0
@export var gravity: float = 900.0
@export var max_fall_speed: float = 400.0
@export var coyote: float = 0.1
@export var jump_buffer: float = 0.1
## Nhân velocity.y khi thả jump giữa chừng (nhảy thấp).
@export_range(0.0, 1.0, 0.05) var jump_cut: float = 0.5
## Lực nhảy lần 2 trên không, nhân thêm jump_mult của nhân vật.
## 0.88 = cú nhảy thứ 2 hơi yếu hơn cú đầu, đúng như cảm giác double jump.
## Chỉ dùng khi CharacterData.ability_id == &"double_jump".
@export_range(0.3, 1.5, 0.05) var air_jump_mult: float = 0.88
@export_range(1, 99, 1) var max_hp: int = 3

@export_group("Projectile")
@export var projectile_scene: PackedScene
@export_range(0.0, 3.0, 0.05) var attack_cooldown: float = 0.4
@export_range(10.0, 2000.0, 10.0) var projectile_speed: float = 250.0
@export_range(0.1, 10.0, 0.1) var projectile_life: float = 1.5
## ThrowPoint lệch bao nhiêu px theo hướng nhìn.
@export_range(0.0, 40.0, 1.0) var throw_offset: float = 10.0

@export_group("Stomp")
@export_range(-2000.0, 0.0, 10.0) var stomp_bounce: float = -200.0
@export_range(1, 99, 1) var stomp_damage: int = 1
## Chỉ tính là đạp đầu khi đang rơi xuống nhanh hơn ngưỡng này.
@export_range(0.0, 600.0, 10.0) var stomp_min_fall_speed: float = 30.0

@export_group("Shield")
## Mặc định của add_shield() khi không truyền tham số.
@export_range(0.5, 30.0, 0.5) var shield_duration: float = 8.0
## Màu viền sáng khi có khiên.
@export var shield_color: Color = Color(0.45, 0.85, 1.0, 1.0)
## Nhịp viền sáng (Hz).
@export_range(2.0, 20.0, 1.0) var shield_pulse_hz: float = 8.0

@export_group("Respawn")
## Thời gian nằm chết trước khi trừ 1 mạng.
@export_range(0.0, 3.0, 0.05) var death_duration: float = 0.8
## Bất tử sau khi hồi sinh (giây).
@export_range(0.0, 5.0, 0.05) var respawn_iframe_time: float = 1.5

@export_group("Hit")
## Trong lúc trúng đòn người chơi không điều khiển được.
@export_range(0.0, 1.0, 0.01) var hit_lock_time: float = 0.3
@export var hit_knockback: Vector2 = Vector2(150.0, -150.0)
## Bất tử tạm thời sau khi trúng đòn (giây).
@export_range(0.0, 5.0, 0.05) var iframe_time: float = 1.2
## Nhịp nhấp nháy sprite khi đang bất tử tạm thời (Hz).
@export_range(2.0, 30.0, 1.0) var blink_hz: float = 10.0
## Rung tay khi trúng đòn (ms). 0 = không rung. Chỉ rung nếu SaveManager.vibration
## đang bật (CheckButton "Rung" trong Settings).
@export_range(0.0, 1000.0, 10.0) var hit_vibration_ms: float = 120.0

@export_group("Camera")
@export var look_ahead: float = 24.0
@export_range(1.0, 40.0, 0.5) var look_ahead_speed: float = 8.0
## LevelBase sẽ ghi đè 4 giá trị này.
@export var limit_left: int = -100000
@export var limit_top: int = -100000
@export var limit_right: int = 100000
@export var limit_bottom: int = 100000

@export_group("Character")
@export var use_character_data: bool = true
@export var character_override: CharacterData
@export_range(0.1, 2.0, 0.05) var character_size_multiplier: float = 0.8

@export_group("Refs")
@export var sprite: AnimatedSprite2D
@export var health: HealthComponent
@export var hurtbox: HurtboxComponent
@export var state_machine: StateMachine
@export var camera: Camera2D
@export var coyote_timer: Timer
@export var jump_buffer_timer: Timer
@export var attack_cooldown_timer: Timer
@export var iframe_timer: Timer
@export var throw_point: Marker2D
@export var body_shape: CollisionShape2D
@export var hurt_shape: CollisionShape2D

var character: CharacterData
var facing: int = 1
var input_dir: float = 0.0
var control_enabled: bool = true

var _blink_time: float = 0.0
var _shield_pulse: float = 0.0
var _shield_left: float = 0.0
## true = đang có khiên (bất tử do đồ, không phải do i-frame).
var shield_active: bool = false
var _spawn_position: Vector2 = Vector2.ZERO

var _speed: float = 120.0
var _accel: float = 800.0
var _friction: float = 900.0
var _jump_velocity: float = -294.0
var _gravity: float = 900.0
var _max_fall_speed: float = 400.0
var _coyote_time: float = 0.1
var _jump_buffer_time: float = 0.1
var _max_hp: int = 3
var _attack_cooldown: float = 0.4
var _was_on_floor: bool = false
var _jumped: bool = false
var _jump_prev: bool = false
## Nhân vật có năng kỹ đặc nhảy 2 lần trên không (ability_id).
var _can_double_jump: bool = false
## Đã dùng cú nhảy trên không lần này chưa. Reset khi chạm đất.
var _air_jump_used: bool = false
## Cú nhảy vừa thực hiện có phải trên không không — Jump state dùng để chọn anim.
var last_jump_was_air: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	_spawn_position = global_position
	sprite = sprite if sprite != null else find_child(^"Sprite", true, false) as AnimatedSprite2D
	health = health if health != null else find_child(^"HealthComponent", true, false) as HealthComponent
	hurtbox = hurtbox if hurtbox != null else find_child(^"Hurtbox", true, false) as HurtboxComponent
	state_machine = state_machine if state_machine != null else find_child(^"StateMachine", true, false) as StateMachine
	camera = camera if camera != null else find_child(^"Camera2D", true, false) as Camera2D
	coyote_timer = coyote_timer if coyote_timer != null else find_child(^"CoyoteTimer", true, false) as Timer
	jump_buffer_timer = jump_buffer_timer if jump_buffer_timer != null else find_child(^"JumpBufferTimer", true, false) as Timer
	attack_cooldown_timer = attack_cooldown_timer if attack_cooldown_timer != null else find_child(^"AttackCooldown", true, false) as Timer
	iframe_timer = iframe_timer if iframe_timer != null else find_child(^"IFrame", true, false) as Timer
	throw_point = throw_point if throw_point != null else find_child(^"ThrowPoint", true, false) as Marker2D
	_resolve_shapes()

	if use_character_data:
		var data: CharacterData = character_override if character_override != null else GameManager.selected_character
		if data != null:
			apply_character(data)
		else:
			apply_exports()
	else:
		apply_exports()

	# Sprite có thể vừa được đổi sang nhân vật khác -> áp lại hướng nhìn.
	_apply_facing()

	if hurtbox != null and health != null:
		hurtbox.health = health
		hurtbox.hit_received.connect(_on_hit_received)
	if camera != null:
		camera.limit_left = limit_left
		camera.limit_top = limit_top
		camera.limit_right = limit_right
		camera.limit_bottom = limit_bottom
	if state_machine != null:
		# _ready() chạy từ con lên cha -> StateMachine.states đã sẵn sàng.
		if state_machine.states.is_empty():
			state_machine.ready.connect(_bind_states, CONNECT_ONE_SHOT)
		else:
			_bind_states()
	if health != null:
		health.damaged.connect(_on_damaged)
		health.died.connect(_on_died)
		health.health_changed.connect(_on_health_changed)
	if iframe_timer != null:
		iframe_timer.timeout.connect(_on_iframe_timeout)


func _bind_states() -> void:
	for key: StringName in state_machine.states:
		var state := state_machine.states[key] as PlayerState
		if state != null:
			state.setup(self)


## Export kiểu Node chưa resolve xong khi _ready() chạy -> dò theo cấu trúc:
## CollisionShape2D trực tiếp của Player = thân, của Hurtbox = vùng trúng đòn.
func _resolve_shapes() -> void:
	if body_shape == null:
		for child in get_children():
			if child is CollisionShape2D:
				body_shape = child as CollisionShape2D
				break
	if hurt_shape == null and hurtbox != null:
		for child in hurtbox.get_children():
			if child is CollisionShape2D:
				hurt_shape = child as CollisionShape2D
				break


# --- Nạp chỉ số ------------------------------------------------------------

## Dùng nguyên giá trị export (nhân vật trung tính, không có .tres).
func apply_exports() -> void:
	_speed = speed
	_jump_velocity = jump_velocity
	_max_hp = max_hp
	_attack_cooldown = attack_cooldown
	_apply_derived()


## Lấy chỉ số + hình từ CharacterData (1 file .tres cho mỗi model).
## Các @export của Player là giá trị GỐC, CharacterData nhân thêm hệ số.
func apply_character(data: CharacterData) -> void:
	character = data
	_speed = speed * data.speed_mult
	_jump_velocity = jump_velocity * data.jump_mult
	_can_double_jump = data.ability_id == &"double_jump"
	_air_jump_used = false
	_max_hp = maxi(max_hp + data.max_hp_bonus, 1)
	_attack_cooldown = attack_cooldown * data.attack_cooldown_mult
	projectile_scene = data.projectile_scene if data.projectile_scene != null else preload("res://scenes/objects/Projectile.tscn")
	if sprite != null:
		var frames: SpriteFrames = data.validated_sprite_frames()
		if frames != null:
			sprite.sprite_frames = frames
		sprite.scale = Vector2.ONE * character_size_multiplier
		sprite.position = data.sprite_offset * character_size_multiplier
		_play_spawn_animation()
	_apply_body_size(data.collision_size)
	_apply_derived()


## Đổi kích thước thân + hurtbox theo collision_size của nhân vật.
func _apply_body_size(size: Vector2) -> void:
	var w: float = maxf(size.x, 2.0)
	var h: float = maxf(size.y, 4.0)
	if body_shape != null:
		var body := body_shape.shape as CapsuleShape2D
		if body == null:
			body = CapsuleShape2D.new()
			body_shape.shape = body
		body.radius = w * 0.5 * character_size_multiplier
		body.height = maxf(h, w) * character_size_multiplier
		body_shape.position = Vector2(0.0, -h * 0.5) * character_size_multiplier
	if hurt_shape != null:
		var hurt := hurt_shape.shape as CapsuleShape2D
		if hurt == null:
			hurt = CapsuleShape2D.new()
			hurt_shape.shape = hurt
		hurt.radius = maxf(w * 0.5 - 1.0, 1.0) * character_size_multiplier
		hurt.height = maxf(h - 2.0, 2.0) * character_size_multiplier
		hurt_shape.position = Vector2(0.0, -h * 0.5 + 1.0) * character_size_multiplier


func _apply_derived() -> void:
	if health != null:
		health.max_health = _max_hp
		# HealthComponent._ready() chạy TRƯỚC Player._ready (con trước cha) nên
		# nó nạp current = max_health GỐC (3) vào lúc đó. apply_character() mới
		# đổi max_health theo nhân vật -> nếu không nạp lại thì vào màn xong
		# nhân vật có 5 máu lại chỉ còn 3 (HUD hiện 3/5 tim).
		health.reset()
	if coyote_timer != null:
		coyote_timer.wait_time = _coyote_time
	if jump_buffer_timer != null:
		jump_buffer_timer.wait_time = _jump_buffer_time
	if attack_cooldown_timer != null:
		attack_cooldown_timer.wait_time = _attack_cooldown
	EventBus.player_hp_changed.emit(
		health.current if health != null else _max_hp, _max_hp)


# --- Vật lý ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_poll_input()
	_read_direction()
	_apply_gravity(delta)
	_apply_horizontal(delta)
	_update_coyote()
	_update_look_ahead(delta)
	_update_throw_point()
	_update_shield(delta)
	_update_blink(delta)
	move_and_slide()


## Nhận diện cạnh lên/xuống của jump bằng so sánh trạng thái giữa 2 frame -
## hoạt động với bàn phím lẫn Input.action_press() của nút cảm ứng.
func _poll_input() -> void:
	var jump_now: bool = Input.is_action_pressed(&"jump")
	if jump_now and not _jump_prev:
		jump_buffer_timer.start(_jump_buffer_time)
	elif (not jump_now) and _jump_prev:
		_apply_jump_cut()
	_jump_prev = jump_now
	if can_attack() and Input.is_action_just_pressed(&"attack"):
		throw_projectile()


func _read_direction() -> void:
	if not control_enabled:
		input_dir = 0.0
		return
	input_dir = Input.get_axis(&"move_left", &"move_right")
	if absf(input_dir) > 0.2:
		facing = 1 if input_dir > 0.0 else -1
		_apply_facing()


## Đổi hướng nhìn của sprite theo `facing`.
##
## Sprite vẽ sẵn nhìn sang PHẢI (giống Enemy/NPC), nên quay trái chỉ cần
## flip_h. Không có hàm này thì nhân vật luôn nhìn phải kể cả khi chạy trái.
func _apply_facing() -> void:
	if sprite != null:
		sprite.flip_h = facing < 0


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		if velocity.y > 0.0:
			velocity.y = 0.0
		return
	velocity.y = minf(velocity.y + _gravity * delta, _max_fall_speed)


func _apply_horizontal(delta: float) -> void:
	var target: float = input_dir * _speed
	var rate: float = _accel if absf(input_dir) > 0.01 else _friction
	velocity.x = move_toward(velocity.x, target, rate * delta)


## Chỉ bật coyote khi rời mép do đi, KHÔNG bật khi vừa nhảy.
func _update_coyote() -> void:
	if is_on_floor():
		_was_on_floor = true
		_jumped = false
		if not coyote_timer.is_stopped():
			coyote_timer.stop()
		return
	if _was_on_floor and not _jumped:
		coyote_timer.start(_coyote_time)
	_was_on_floor = false


func _update_look_ahead(delta: float) -> void:
	if camera == null or look_ahead <= 0.0:
		return
	var dir: float = signf(velocity.x) if absf(velocity.x) > 5.0 else 0.0
	var target: float = dir * look_ahead
	var weight: float = 1.0 - exp(-look_ahead_speed * delta)
	camera.position.x = lerpf(camera.position.x, target, weight)
	# Làm tròn: lerp ra số lẻ sẽ đẩy camera lệch nửa pixel -> tile nhòe/nhiễu.
	camera.position.x = roundf(camera.position.x)


## ThrowPoint bám theo hướng nhìn (lệch throw_offset px).
func _update_throw_point() -> void:
	if throw_point == null:
		return
	throw_point.position = Vector2(throw_offset * float(facing) * character_size_multiplier, throw_point.position.y)


## Đếm ngược khiên. Hết giờ -> tắt khiên (i-frame vẫn còn nếu đang chạy).
func _update_shield(delta: float) -> void:
	if not shield_active:
		return
	_shield_left -= delta
	if _shield_left <= 0.0:
		set_shield(false)


## Nhấp nháy khi i-frame; có khiên thì đổi sang viền sáng thay vì nhấp nháy.
func _update_blink(delta: float) -> void:
	if sprite == null:
		return
	var base: Color = Color.WHITE
	var color: Color = base
	if shield_active:
		_shield_pulse += delta
		var wave: float = 0.5 + 0.5 * sin(_shield_pulse * TAU * shield_pulse_hz)
		color = base.lerp(shield_color, 0.35 + 0.45 * wave)
	var alpha: float = 1.0
	if health != null and health.invincible and not shield_active:
		_blink_time += delta
		var period: float = 1.0 / maxf(blink_hz, 0.1)
		if fmod(_blink_time, period) >= period * 0.5:
			alpha = 0.25
	sprite.modulate = color
	sprite.modulate.a = alpha


# --- Hàm công khai cho GameManager / Pickup --------------------------------


## Khiên: bất tử + viền sáng trong `duration` giây (mặc định lấy shield_duration).
func add_shield(duration: float = 8.0) -> void:
	shield_active = true
	_shield_left = duration if duration > 0.0 else shield_duration
	_sync_invincible()
	AudioManager.play_sfx(&"shield")


func is_shielded() -> bool:
	return shield_active


func shield_time_left() -> float:
	return _shield_left


func set_shield(value: bool) -> void:
	shield_active = value
	if not value:
		_shield_left = 0.0
		if sprite != null:
			sprite.modulate = Color.WHITE
	_sync_invincible()


## KillZone gọi: chết ngay, BỎ QUA i-frame và khiên. Đi qua state Dead như bình thường.
func kill_by_hazard() -> void:
	if health == null or not health.is_alive():
		return
	if current_state() == STATE_DEAD:
		return
	shield_active = false
	if iframe_timer != null:
		iframe_timer.stop()
	health.invincible = false
	health.take_damage(health.current, global_position)


## Hồi sinh: về checkpoint (nếu có) hoặc PlayerSpawn, HP đầy, i-frame respawn_iframe_time.
func respawn() -> void:
	global_position = respawn_position()
	velocity = Vector2.ZERO
	facing = 1
	_apply_facing()
	shield_active = false
	_shield_left = 0.0
	_blink_time = 0.0
	if health != null:
		health.reset()
	set_control_enabled(true)
	if state_machine != null:
		state_machine.change_state(STATE_IDLE)
	_start_iframe(respawn_iframe_time)


## Checkpoint -> PlayerSpawn -> vị trí lúc scene spawn.
func respawn_position() -> Vector2:
	if GameManager.last_checkpoint != Vector2.ZERO:
		return GameManager.last_checkpoint
	var marker := get_tree().get_first_node_in_group(GROUP_SPAWN)
	if marker is Node2D:
		return (marker as Node2D).global_position
	return _spawn_position


func _start_iframe(duration: float = -1.0) -> void:
	if health == null:
		return
	_blink_time = 0.0
	if iframe_timer != null:
		iframe_timer.start(duration if duration > 0.0 else iframe_time)
	_sync_invincible()


func _on_iframe_timeout() -> void:
	_blink_time = 0.0
	_sync_invincible()


## invincible = khiên đang bật HOẶC i-frame đang chạy.
func _sync_invincible() -> void:
	if health == null:
		return
	var iframe: bool = iframe_timer != null and not iframe_timer.is_stopped()
	health.invincible = shield_active or iframe


# --- Tấn công / đạn -------------------------------------------------------

## true = còn mạng, còn sống và đã hết cooldown.
func can_attack() -> bool:
	if health == null or not health.is_alive():
		return false
	if current_state() == STATE_DEAD:
		return false
	return attack_cooldown_timer == null or attack_cooldown_timer.is_stopped()


## Ném 1 viên đạn tại ThrowPoint theo hướng nhìn, rồi bắt đầu cooldown.
## Trả về null nếu đang cooldown / chết / chưa gán projectile_scene.
func throw_projectile() -> Projectile:
	if not can_attack():
		return null
	if projectile_scene == null:
		push_warning("Player: chưa gán projectile_scene.")
		return null
	var parent: Node = get_parent()
	if parent == null:
		return null
	var projectile := projectile_scene.instantiate() as Projectile
	if projectile == null:
		push_warning("Player: projectile_scene gốc phải là Projectile.")
		return null
	projectile.direction = facing
	projectile.speed = projectile_speed
	projectile.life = projectile_life
	parent.add_child(projectile)
	projectile.global_position = throw_point.global_position if throw_point != null else global_position
	if attack_cooldown_timer != null:
		attack_cooldown_timer.start()
	return projectile


# --- Đạp đầu --------------------------------------------------------------

## Enemy.StompZone gọi hàm này khi chạm Player. true = đạp đầu thành công.
## is_boss = true -> điểm do GameManager quyết định là 2000.
func notify_stomp(enemy: Node, is_boss: bool = false) -> bool:
	if not can_stomp():
		return false
	var target: HealthComponent = _find_health(enemy)
	# Bật lên NGAY -> can_stomp() false trong chính frame này, không nảy 2 lần.
	velocity.y = stomp_bounce
	if target != null:
		var was_alive: bool = target.is_alive()
		target.take_damage(stomp_damage, global_position)
		if was_alive and not target.is_alive():
			# Bảng thưởng nằm ở GameManager (200 điểm / 2000 boss).
			GameManager.report_enemy_killed(is_boss)
			AudioManager.play_sfx(&"enemy_die")
			EventBus.request_shake.emit(3.0, 0.15)
	AudioManager.play_sfx(&"stomp")
	return true


## Chỉ khi đang sống và đang rơi xuống.
func can_stomp() -> bool:
	if health == null or not health.is_alive():
		return false
	if current_state() == STATE_DEAD:
		return false
	return velocity.y > stomp_min_fall_speed


## Tìm HealthComponent của enemy: ưu tiên chính node, rồi con, rồi cha (StompZone).
func _find_health(node: Node) -> HealthComponent:
	if node == null:
		return null
	if node is HealthComponent:
		return node as HealthComponent
	var direct := node.get_node_or_null(^"HealthComponent") as HealthComponent
	if direct != null:
		return direct
	var parent: Node = node.get_parent()
	if parent != null:
		var from_parent := parent.get_node_or_null(^"HealthComponent") as HealthComponent
		if from_parent != null:
			return from_parent
	return node.find_child(^"HealthComponent", true, false) as HealthComponent


# --- Nhảy -----------------------------------------------------------------

func can_jump() -> bool:
	return is_on_floor() or not coyote_timer.is_stopped() or can_air_jump()


## Cú nhảy thứ 2 trên không còn dùng được không.
func can_air_jump() -> bool:
	return _can_double_jump and not _air_jump_used and not is_on_floor()


func has_jump_request() -> bool:
	return not jump_buffer_timer.is_stopped()


func do_jump() -> bool:
	if not can_jump() or not has_jump_request():
		return false
	# Phải đọc cửa sổ coyote TRƯỚC khi dừng timer. Dừng rồi mới kiểm tra thì
	# `coyote_timer.is_stopped()` luôn true -> mọi cú nhảy (kể cả cú từ mặt đất)
	# đều rơi vào nhánh nhảy trên không và nhảy yếu hơn 12%.
	var from_ground: bool = is_on_floor() or not coyote_timer.is_stopped()
	jump_buffer_timer.stop()
	coyote_timer.stop()
	_jumped = true
	if from_ground:
		_air_jump_used = false
		last_jump_was_air = false
		velocity.y = _jump_velocity
	else:
		_air_jump_used = true
		last_jump_was_air = true
		velocity.y = _jump_velocity * air_jump_mult
	state_machine.change_state(STATE_JUMP)
	AudioManager.play_sfx(&"double_jump" if last_jump_was_air else &"jump")
	# Nhảy lần 2 xảy ra khi đã ở sẵn state Jump -> change_state() là no-op nên
	# enter() không chạy, animation sẽ không đổi. Phát tay ở đây.
	if state_machine.is_current(STATE_JUMP):
		apply_jump_animation()
	return true


## Clip của cú nhảy vừa thực hiện: trên không -> "double_jump" (nếu có),
## nền tảng -> "jump". Gọi từ cả Player.do_jump() lẫn JumpState.enter().
func apply_jump_animation() -> void:
	if last_jump_was_air:
		play_animation_or(&"double_jump", &"jump")
	else:
		play_animation(&"jump")


## Thả jump giữa lúc bay lên -> cắt ngắn cú nhảy.
func _apply_jump_cut() -> void:
	if velocity.y < 0.0:
		velocity.y *= jump_cut


func notify_landed() -> void:
	_air_jump_used = false
	AudioManager.play_sfx(&"land")
	DustFX.spawn(get_parent(), global_position)
	landed.emit()


# --- Trạng thái / hình ảnh -------------------------------------------------

func play_animation(anim: StringName) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	if not sprite.sprite_frames.has_animation(anim):
		return
	if sprite.animation == anim and sprite.is_playing():
		return
	sprite.play(anim)


## Phát `anim`; nếu SpriteFrames không có thì phát `fallback`.
## Dùng cho anim chỉ tồn tại ở một số nhân vật (vd double_jump chỉ có ở Ninja Frog).
func play_animation_or(anim: StringName, fallback: StringName) -> void:
	if sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim):
		play_animation(anim)
	else:
		play_animation(fallback)


## Vừa gán sprite_frames, AnimatedSprite2D tự chọn animation ĐẦU TIÊN trong danh
## sách. Các nhân vật hiện tại liệt kê theo thứ tự alphabet, nên animation đầu là
## "dead"/"hit" -> lúc màn vừa mở nhân vật đứng đúng pose chết cho tới frame sau.
## Phát "appear" nếu SpriteFrames có; hết clip thì về idle. Không có -> idle luôn.
func _play_spawn_animation() -> void:
	if sprite == null:
		return
	AudioManager.play_sfx(&"player_appear")
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"appear"):
		play_animation(&"appear")
		# appear là clip một lần: hết clip -> idle. CONNECT_ONE_SHOT nên tự rút.
		var on_done := Callable(self, "_on_spawn_animation_finished")
		if not sprite.animation_finished.is_connected(on_done):
			sprite.animation_finished.connect(on_done, CONNECT_ONE_SHOT)
		return
	play_animation(&"idle")


func _on_spawn_animation_finished() -> void:
	play_animation(&"idle")


func set_control_enabled(value: bool) -> void:
	control_enabled = value
	if not value:
		input_dir = 0.0


func current_state() -> StringName:
	if state_machine == null or state_machine.current_state == null:
		return &""
	return state_machine.current_state.name


func _on_health_changed(cur: int, mx: int) -> void:
	EventBus.player_hp_changed.emit(cur, mx)


func _on_damaged(amount: int, from_pos: Vector2) -> void:
	damaged.emit(amount, from_pos)
	EventBus.request_shake.emit(3.0, 0.15)
	_start_iframe()
	AudioManager.play_sfx(&"player_hurt")
	_vibrate_hit()
	if current_state() == STATE_DEAD or current_state() == STATE_HIT:
		return
	state_machine.change_state(STATE_HIT, {"from": from_pos})


## Rung tay khi trúng đòn. Settings tắt rung -> SaveManager.vibration = false ->
## bỏ qua. Trên desktop Input.vibrate_handheld() là no-op nên không lỗi.
func _vibrate_hit() -> void:
	if hit_vibration_ms <= 0.0 or not SaveManager.vibration:
		return
	Input.vibrate_handheld(int(hit_vibration_ms))


func _on_died() -> void:
	if current_state() != STATE_DEAD:
		state_machine.change_state(STATE_DEAD)
	died.emit()


func _on_hit_received(hitbox: HitboxComponent) -> void:
	if not hitbox.apply_knockback or health == null or not health.is_alive():
		return
	var away := signf(global_position.x - hitbox.global_position.x)
	if is_zero_approx(away):
		away = float(facing)
	velocity = Vector2(away * absf(hitbox.knockback.x), hitbox.knockback.y)
