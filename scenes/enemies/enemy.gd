class_name Enemy
extends CharacterBody2D
## Lớp cha cho MỌI quái. Biến thể chỉ cần instance Enemy.tscn rồi ghi đè
## _on_patrol / _on_detect / _on_chase / _on_attack (hoặc thay cả state machine).
##
## Lớp con KHÔNG cần biết Player có HealthComponent ở đâu: mọi tương tác đi qua
## group "player" + các hàm công khai (can_stomp / stomp_bounce).

signal died_enemy(enemy: Enemy)

const GROUP: StringName = &"enemy"

const STATE_PATROL: StringName = &"Patrol"
const STATE_DETECT: StringName = &"Detect"
const STATE_CHASE: StringName = &"Chase"
const STATE_ATTACK: StringName = &"Attack"
const STATE_HURT: StringName = &"Hurt"
const STATE_DEAD: StringName = &"Dead"

## Enemy.tscn dùng "walk", nhân vật chính dùng "run".
const ANIM_ALIASES: Dictionary[StringName, StringName] = {&"run": &"walk"}
## Scene mảnh Rift rơi ra khi quái chết.
const SHARD_SCENE: PackedScene = preload("res://scenes/objects/RiftShard.tscn")

@export_group("Health")
@export_range(1, 99, 1) var max_hp: int = 1
@export_range(0, 9999, 10) var score_value: int = 200
## Chết có rơi mảnh Rift không. Boss/gate tắt để không phá số mảnh của màn.
@export var drops_shards: bool = true
@export_range(0, 5, 1) var shard_drop: int = 1
## Trong state Hurt quái không hành động (giây).
@export_range(0.0, 2.0, 0.01) var hurt_stun: float = 0.25
## Nháy trắng khi trúng đòn (giây).
@export_range(0.0, 1.0, 0.01) var flash_time: float = 0.1
## Đẩy lùi khi trúng đòn (px/s).
@export_range(0.0, 1000.0, 10.0) var knockback: float = 120.0
## Nhấc lên khi trúng đòn (px/s, âm = lên trên).
@export_range(-600.0, 0.0, 10.0) var knockback_lift: float = -80.0
## Chờ sau khi chết rồi mới biến mất (giây).
@export_range(0.0, 3.0, 0.05) var death_delay: float = 0.4

@export_group("Movement")
@export_range(0.0, 400.0, 1.0) var speed: float = 40.0
@export_range(0.0, 4000.0, 10.0) var accel: float = 400.0
@export_range(0.0, 4000.0, 10.0) var gravity: float = 900.0
@export_range(0.0, 2000.0, 10.0) var max_fall_speed: float = 400.0
@export var face_right: bool = true
## Quay lại khi đụng tường.
@export var turn_at_wall: bool = true
## Quay lại khi sắp rơi xuống hố (raycast xuống phía trước).
@export var turn_at_ledge: bool = true
@export_range(4.0, 64.0, 1.0) var ledge_check_height: float = 28.0
## false = quái bay, không áp trọng lực.
@export var has_gravity: bool = true

@export_group("Combat")
## Sát thương thân quái gây ra khi chạm Player.
@export_range(0, 99, 1) var contact_damage: int = 1
## Sát thương khi bị đạp đầu.
@export_range(1, 99, 1) var stomp_damage: int = 1

@export_group("AI")
## Bán kính phát hiện Player (px).
@export_range(0.0, 600.0, 8.0) var detect_radius: float = 96.0
## Trong khoảng này quái chuyển sang Attack (px).
@export_range(0.0, 600.0, 8.0) var attack_radius: float = 24.0
## Thời gian "chớp mắt" ở state Detect trước khi đuổi (giây).
@export_range(0.0, 2.0, 0.05) var detect_time: float = 0.25
## Thời gian ở state Attack rồi mới quay lại Chase (giây).
@export_range(0.0, 5.0, 0.05) var attack_delay: float = 0.6

@export_group("Refs")
@export var sprite: AnimatedSprite2D
@export var health: HealthComponent
@export var hurtbox: HurtboxComponent
@export var contact_hitbox: HitboxComponent
@export var stomp_zone: Area2D
@export var state_machine: StateMachine
@export var on_screen: VisibleOnScreenNotifier2D

## 1 = đi sang phải, -1 = sang trái.
var direction: int = 1
var player: Player
var dead: bool = false
var control_enabled: bool = true

var _detect_left: float = 0.0
var _attack_left: float = 0.0
var _flash_left: float = 0.0
var _dead_left: float = 0.0
var _base_modulate: Color = Color.WHITE


func _ready() -> void:
	add_to_group(GROUP)
	direction = 1 if face_right else -1
	sprite = sprite if sprite != null else _find_sprite()
	health = health if health != null else find_child(^"HealthComponent", true, false) as HealthComponent
	hurtbox = hurtbox if hurtbox != null else find_child(^"Hurtbox", true, false) as HurtboxComponent
	contact_hitbox = contact_hitbox if contact_hitbox != null else find_child(^"ContactHitbox", true, false) as HitboxComponent
	stomp_zone = stomp_zone if stomp_zone != null else find_child(^"StompZone", true, false) as Area2D
	state_machine = state_machine if state_machine != null else find_child(^"StateMachine", true, false) as StateMachine
	on_screen = on_screen if on_screen != null else find_child(^"VisibleOnScreenNotifier2D", true, false) as VisibleOnScreenNotifier2D

	player = get_tree().get_first_node_in_group(&"player") as Player
	if health != null:
		health.max_health = max_hp
		health.current = max_hp
		health.damaged.connect(_on_damaged)
		health.died.connect(_on_died)
	if hurtbox != null and health != null:
		hurtbox.health = health
	if contact_hitbox != null:
		contact_hitbox.damage = contact_damage
	if stomp_zone != null:
		stomp_zone.area_entered.connect(_on_stomp_zone_area_entered)
	if on_screen != null:
		on_screen.screen_entered.connect(_on_screen_entered)
		on_screen.screen_exited.connect(_on_screen_exited)
	if sprite != null:
		_base_modulate = sprite.modulate
		sprite.flip_h = direction < 0
	_bind_states()
	# StateMachine la con nen _ready() chay TRUOC Enemy._ready(): luc do `sprite`
	# con null, play_anim() cua state khoi tao khong co hieu luc. Enemy se dung
	# yen mot animation (thuong la idle) suot cho phan di chuyen. Phai ap lai
	# animation cua state dang chay sau khi da lay duoc sprite.
	if state_machine != null and state_machine.current_state != null:
		enter_state(state_machine.current_state.name)


## Tim AnimatedSprite2D du chua gan `sprite` trong Inspector.
## Khong nen dua theo ten: node trong Enemy.tscn ten "AnimatedSprite2D", nen
## find_child("Sprite") — cach cu — luon tra null. Scene moi tao ma quen gan
## `sprite` se hien anh nhung khong flip_h, khong modulate, khong phat animation.
func _find_sprite() -> AnimatedSprite2D:
	if sprite != null:
		return sprite
	var direct := find_child(^"AnimatedSprite2D", true, false) as AnimatedSprite2D
	if direct != null:
		return direct
	for child in find_children("*" as String, ^"AnimatedSprite2D", true, false):
		return child as AnimatedSprite2D
	return null


func _bind_states() -> void:
	if state_machine == null:
		return
	if state_machine.states.is_empty():
		state_machine.ready.connect(_bind_states, CONNECT_ONE_SHOT)
		return
	for key: StringName in state_machine.states:
		var state := state_machine.states[key] as EnemyState
		if state != null:
			state.setup(self)


func _physics_process(delta: float) -> void:
	_update_flash(delta)
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as Player


# --- Tick theo state (gọi từ EnemyState) -----------------------------------

func tick_patrol(delta: float) -> void:
	_on_patrol(delta)
	_apply_gravity(delta)
	_step(delta)
	if can_see_player():
		state_machine.change_state(STATE_DETECT)


func tick_detect(delta: float) -> void:
	_on_detect(delta)
	_apply_gravity(delta)
	_stop(delta)
	_detect_left -= delta
	if not can_see_player():
		state_machine.change_state(STATE_PATROL)
	elif _detect_left <= 0.0:
		state_machine.change_state(STATE_CHASE)


func tick_chase(delta: float) -> void:
	_on_chase(delta)
	_apply_gravity(delta)
	if can_see_player() and distance_to_player() <= attack_radius:
		state_machine.change_state(STATE_ATTACK)
		return
	if not can_see_player():
		state_machine.change_state(STATE_PATROL)
		return
	_face_player()
	_step(delta)


func tick_attack(delta: float) -> void:
	_on_attack(delta)
	_apply_gravity(delta)
	_stop(delta)
	_face_player()
	_attack_left -= delta
	if not can_see_player():
		state_machine.change_state(STATE_PATROL)
	elif _attack_left <= 0.0:
		state_machine.change_state(STATE_CHASE)


## Vẫn trượt theo knockback trong lúc choáng.
func tick_hurt(delta: float) -> void:
	_apply_gravity(delta)
	_step(delta)


func tick_dead(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	move_and_slide()
	_dead_left -= delta
	if _dead_left <= 0.0:
		queue_free()


# --- HÀM ẢO: lớp con ghi đè ----------------------------------------------

## Đi tuần. Mặc định: chạy thẳng theo `direction`.
func _on_patrol(_delta: float) -> void:
	pass


## Vừa phát hiện Player. Mặc định: đứng yên.
func _on_detect(_delta: float) -> void:
	pass


## Đuổi theo. Mặc định: chạy về phía Player.
func _on_chase(_delta: float) -> void:
	pass


## Ra đòn. Mặc định: chỉ quay mặt, lớp con tự bắn/ném.
func _on_attack(_delta: float) -> void:
	pass


# --- AI cơ bản -------------------------------------------------------------

func can_see_player() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	if player.health == null or not player.health.is_alive():
		return false
	return distance_to_player() <= detect_radius


func distance_to_player() -> float:
	if player == null or not is_instance_valid(player):
		return INF
	return global_position.distance_to(player.global_position)


func _face_player() -> void:
	if player == null or not is_instance_valid(player):
		return
	if is_zero_approx(player.global_position.x - global_position.x):
		return
	direction = 1 if player.global_position.x > global_position.x else -1
	if sprite != null:
		sprite.flip_h = direction < 0


func enter_state(state_name: StringName) -> void:
	match state_name:
		STATE_PATROL:
			play_anim(&"run")
		STATE_DETECT:
			AudioManager.play_sfx(&"enemy_detect")
			_detect_left = detect_time
			play_anim(&"idle")
		STATE_CHASE:
			play_anim(&"run")
		STATE_ATTACK:
			AudioManager.play_sfx(&"enemy_attack")
			_attack_left = attack_delay
			play_anim(&"idle")
		STATE_HURT:
			play_anim(&"hit")
		STATE_DEAD:
			play_anim(&"dead")


# --- Vật lý ----------------------------------------------------------------

func _apply_gravity(delta: float) -> void:
	if not has_gravity or is_on_floor():
		if is_on_floor() and velocity.y > 0.0:
			velocity.y = 0.0
		return
	velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)


func _step(delta: float) -> void:
	if control_enabled:
		velocity.x = move_toward(velocity.x, float(direction) * speed, accel * delta)
	move_and_slide()
	if turn_at_wall and is_on_wall():
		_flip()
	if turn_at_ledge and is_on_floor() and _no_ground_ahead():
		_flip()
	if sprite != null:
		sprite.flip_h = direction < 0


func _stop(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, accel * delta)
	move_and_slide()


func _flip() -> void:
	direction = -direction
	if sprite != null:
		sprite.flip_h = direction < 0


## Raycast xuống phía trước: không có đất = sắp rơi xuống hố.
func _no_ground_ahead() -> bool:
	var space := get_world_2d().direct_space_state
	var from: Vector2 = global_position + Vector2(float(direction) * 12.0, 0.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, ledge_check_height), 1)
	query.exclude = [get_rid()]
	return space.intersect_ray(query).is_empty()


# --- Sát thương ------------------------------------------------------------

func take_damage(amount: int = 1, from_pos: Vector2 = Vector2.ZERO) -> void:
	if dead or health == null:
		return
	health.take_damage(amount, from_pos)


func apply_knockback(from_pos: Vector2) -> void:
	var away: float = signf(global_position.x - from_pos.x)
	if is_zero_approx(away):
		away = float(direction)
	velocity = Vector2(away * knockback, knockback_lift)


func _on_stomp_zone_area_entered(area: Area2D) -> void:
	if dead:
		return
	# Hurtbox của Player không được gán trực tiếp, nhưng nó là con của Player.
	# Hãy tìm Player parent của Hurtbox.
	var parent_node := area.get_parent()
	var p := parent_node as Player
	if p == null:
		return
	if not p.can_stomp():
		return
	take_damage(stomp_damage, p.global_position)
	p.notify_stomp(self)
	AudioManager.play_sfx(&"stomp")


func _on_damaged(_amount: int, from_pos: Vector2) -> void:
	if dead or state_machine == null:
		return
	_start_flash()
	if health != null and health.is_alive():
		AudioManager.play_sfx(&"enemy_hurt")
		state_machine.change_state(STATE_HURT, {"from": from_pos})


func _on_died() -> void:
	if dead:
		return
	dead = true
	control_enabled = false
	_disable_hitboxes()
	velocity = Vector2(0.0, minf(velocity.y, -60.0))
	_dead_left = death_delay
	GameManager.add_score(score_value)
	AudioManager.play_sfx(&"enemy_die")
	EventBus.request_shake.emit(2.0, 0.12)
	# Phát animation dead
	play_anim(&"dead")
	_drop_shards()
	if state_machine != null:
		state_machine.change_state(STATE_DEAD)
	died_enemy.emit(self)


## Quái chết rơi mảnh Rift. Đây là nguồn duy nhất của mảnh: người chơi phải
## đánh quái mới đủ mảnh mở cánh cổng cuối màn.
func _drop_shards() -> void:
	if not drops_shards or shard_drop <= 0:
		return
	var parent := get_parent()
	if parent == null:
		return
	for i in shard_drop:
		var shard := SHARD_SCENE.instantiate() as RiftShard
		if shard == null:
			return
		# Nảy tản ra nhẹ, để người chơi phải đi nhặt chứ không tự vào túi.
		shard.position = global_position + Vector2(randf_range(-8.0, 8.0), randf_range(-6.0, 2.0))
		parent.call_deferred("add_child", shard)


## Chết rồi -> không đánh, không nhận đòn, không đạp đầu được nữa.
func _disable_hitboxes() -> void:
	if contact_hitbox != null:
		contact_hitbox.set_active(false)
	if hurtbox != null:
		hurtbox.set_deferred(&"monitoring", false)
	if stomp_zone != null:
		stomp_zone.set_deferred(&"monitoring", false)


# --- Hình ảnh / offscreen --------------------------------------------------

func play_anim(anim: StringName) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var name: StringName = anim
	if not sprite.sprite_frames.has_animation(name) and ANIM_ALIASES.has(anim):
		name = ANIM_ALIASES[anim]
	if not sprite.sprite_frames.has_animation(name):
		# Fallback: "dead" -> "idle", "run" -> "walk", etc.
		if anim == &"dead":
			name = &"idle"
		else:
			name = &"idle"
	if not sprite.sprite_frames.has_animation(name):
		return
	if sprite.animation == name and sprite.is_playing():
		return
	sprite.play(name)


func _start_flash() -> void:
	_flash_left = flash_time


func _update_flash(delta: float) -> void:
	if sprite == null:
		return
	if _flash_left > 0.0:
		_flash_left -= delta
		sprite.modulate = Color(3.0, 3.0, 3.0, 1.0)
	elif not sprite.modulate.is_equal_approx(_base_modulate):
		sprite.modulate = _base_modulate


## Lọt khỏi màn hình (margin 64px) -> dừng xử lý cho tới khi quay lại.
func _on_screen_exited() -> void:
	set_physics_process(false)


func _on_screen_entered() -> void:
	if not dead:
		set_physics_process(true)


func current_state() -> StringName:
	if state_machine == null or state_machine.current_state == null:
		return &""
	return state_machine.current_state.name
