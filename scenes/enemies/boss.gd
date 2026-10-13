class_name Boss
extends Enemy

const REST: StringName = &"Rest"
const TELEGRAPH: StringName = &"Telegraph"
const DASH: StringName = &"Dash"
const SLAM: StringName = &"Slam"
const SHOOT: StringName = &"Shoot"
const STUNNED: StringName = &"Stunned"
const HOSTILE_PROJECTILE = preload("res://scenes/objects/EnemyProjectile.tscn")
const SUMMONED_PATROL = preload("res://scenes/enemies/SummonedPatrolEnemy.tscn")

@export_group("Boss")
@export_range(0.0, 1.0, 0.05) var phase2_at: float = 0.5
@export var dash_speed: float = 260.0
@export var slam_wave_speed: float = 140.0
@export var rest_time: float = 1.5
@export var telegraph: float = 0.4
@export var phase2_speed_mult: float = 1.3
@export var summon_interval: float = 8.0
@export_range(0, 10, 1) var max_summon_gates: int = 2
@export var slam_jump_speed: float = 420.0
@export var shot_speed: float = 180.0
@export var damage_iframe: float = 0.45
@export_group("Arena (world coordinates)")
@export var arena_left: float = -320.0
@export var arena_right: float = 320.0
@export_group("Refs")
@export var body_collision: CollisionShape2D

@onready var shot_point: Marker2D = $ShotPoint
@onready var summon_timer: Timer = $SummonTimer
@onready var summon_gate: Node2D = $SummonGate

var phase: int = 1
var _state_left: float = 0.0
var _attack: StringName = DASH
var _airborne: bool = false
var _slam_target_x: float
var _slam_start_y: float
var _damage_left: float = 0.0
var _phase_flash_left: float = 0.0
var _gate_left: float = -1.0
var _gate_anchor: Vector2
var _spawned_this_gate: bool = false
var _summoned_gate_count: int = 0
var _projectiles: Array[EnemyProjectile] = []
var _minions: Array[PatrolEnemy] = []
var _rng := RandomNumberGenerator.new()
var _body_half_size := Vector2(64, 72)


func _ready() -> void:
	super._ready()
	body_collision = body_collision if body_collision != null else find_child(^"CollisionShape2D", false, false) as CollisionShape2D
	_body_half_size = _world_body_bounds().size * 0.5
	if arena_left > arena_right:
		var saved_left := arena_left
		arena_left = arena_right
		arena_right = saved_left
	add_to_group(&"boss")
	_rng.randomize()
	_gate_anchor = summon_gate.global_position
	summon_gate.hide()
	summon_timer.wait_time = maxf(summon_interval, 0.1)
	summon_timer.timeout.connect(_on_summon_timeout)
	health.health_changed.connect(_on_boss_hp_changed)
	_on_boss_hp_changed(health.current, health.max_health)
	enter_state(REST)


func speed_multiplier() -> float:
	return phase2_speed_mult if phase == 2 else 1.0


func _on_boss_hp_changed(cur: int, maximum: int) -> void:
	EventBus.boss_hp_changed.emit(cur, maximum)
	if not dead and cur > 0 and phase == 1 and float(cur) <= float(maximum) * phase2_at:
		phase = 2
		AudioManager.play_sfx(&"boss_phase")
		_phase_flash_left = 0.3
		EventBus.request_shake.emit(2.0, 0.2)
		if _summoned_gate_count < max_summon_gates:
			summon_timer.start(maxf(summon_interval, 0.1))


func _on_damaged(_amount: int, _from_pos: Vector2) -> void:
	if dead:
		return
	if health.is_alive():
		AudioManager.play_sfx(&"enemy_hurt")
	_start_flash()
	_damage_left = damage_iframe
	health.invincible = true


func _on_stomp_zone_area_entered(area: Area2D) -> void:
	if dead or current_state() == SLAM or health.invincible:
		return
	var target := area.get_parent() as Player
	if target == null or not target.can_stomp():
		return
	# Boss owns damage and death scoring; notify_stomp would deal a second hit
	# and award another kill bonus on the lethal stomp.
	target.velocity.y = target.stomp_bounce
	take_damage(stomp_damage, target.global_position)
	AudioManager.play_sfx(&"stomp")


func enter_state(state_name: StringName) -> void:
	if sprite != null:
		sprite.modulate = _base_modulate
	if contact_hitbox != null:
		contact_hitbox.set_active(not dead and state_name in [DASH, SLAM])
	match state_name:
		REST:
			velocity.x = 0.0
			_state_left = rest_time
			play_anim(&"idle")
		TELEGRAPH:
			AudioManager.play_sfx(&"enemy_detect")
			velocity.x = 0.0
			_state_left = telegraph
			_face_player()
			play_anim(&"idle")
		DASH:
			AudioManager.play_sfx(&"boss_dash")
			# Always run toward the opposite side, even with player behind us.
			direction = 1 if global_position.x <= (arena_left + arena_right) * 0.5 else -1
			_state_left = absf(arena_right - arena_left) / maxf(dash_speed * speed_multiplier(), 1.0) + 1.0
			play_anim(&"run")
		SLAM:
			_airborne = false
			_slam_start_y = global_position.y
			_slam_target_x = clampf(player.global_position.x if is_instance_valid(player) else global_position.x, arena_left + _body_half_size.x, arena_right - _body_half_size.x)
			velocity = Vector2(0.0, -slam_jump_speed * speed_multiplier())
			_state_left = 4.0
			play_anim(&"run")
		SHOOT:
			_fire_fan()
			state_machine.change_state(REST)
		STUNNED:
			AudioManager.play_sfx(&"projectile_hit")
			velocity.x = 0.0
			_state_left = 1.0
			play_anim(&"hit")
			EventBus.request_shake.emit(2.0, 0.15)
		STATE_DEAD:
			velocity = Vector2.ZERO
			_dead_left = 1.5
			play_anim(&"dead")
	if sprite != null:
		sprite.flip_h = direction < 0


func _update_flash(delta: float) -> void:
	if sprite == null:
		return
	_phase_flash_left = maxf(0.0, _phase_flash_left - delta)
	_flash_left = maxf(0.0, _flash_left - delta)
	if not dead and (_phase_flash_left > 0.0 or _flash_left > 0.0):
		sprite.modulate = Color(3, 3, 3)
	elif not dead and current_state() == TELEGRAPH:
		var pulse := 0.5 + 0.5 * sin((telegraph - _state_left) * TAU * 8.0)
		sprite.modulate = _base_modulate.lerp(Color(2, 1.6, 1.8), 0.5 + 0.5 * pulse)
	else:
		sprite.modulate = _base_modulate


func tick_boss(delta: float) -> void:
	if dead:
		_dead_left -= delta
		if _dead_left <= 0.0:
			queue_free()
		return
	_damage_left = maxf(0.0, _damage_left - delta)
	if _damage_left <= 0.0:
		health.invincible = false
	_prune_spawned_nodes()
	_tick_gate(delta)
	var state := current_state()
	if state == SLAM:
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed * speed_multiplier())
	else:
		_apply_gravity(delta)
		if is_on_floor():
			velocity.y = gravity * delta
	_state_left -= delta
	match state:
		REST:
			velocity.x = 0.0
			move_and_slide()
			if _state_left <= 0.0 and _player_alive():
				_choose_attack()
		TELEGRAPH:
			velocity.x = 0.0
			move_and_slide()
			if _state_left <= 0.0:
				state_machine.change_state(_attack)
		DASH:
			_tick_dash(delta)
		SLAM:
			_tick_slam(delta)
		STUNNED:
			velocity.x = 0.0
			move_and_slide()
			if _state_left <= 0.0:
				state_machine.change_state(REST)
	_constrain_to_arena()


func _player_alive() -> bool:
	return is_instance_valid(player) and player.health != null and player.health.is_alive()


func _choose_attack() -> void:
	var choices: Array[StringName] = [DASH, SLAM]
	if phase == 2:
		choices.append(SHOOT)
	_attack = choices[_rng.randi_range(0, choices.size() - 1)]
	state_machine.change_state(TELEGRAPH)


func _tick_dash(delta: float) -> void:
	var travel := dash_speed * speed_multiplier() * delta
	var origin := global_position + Vector2(direction * (_body_half_size.x + travel), 0)
	var ground := PhysicsRayQueryParameters2D.create(origin, origin + Vector2(0, _body_half_size.y + 24.0), 1)
	ground.exclude = [get_rid()]
	if is_on_floor() and get_world_2d().direct_space_state.intersect_ray(ground).is_empty():
		state_machine.change_state(STUNNED)
		return
	velocity.x = direction * dash_speed * speed_multiplier()
	move_and_slide()
	if is_on_wall() or _at_arena_edge() or _state_left <= 0.0:
		state_machine.change_state(STUNNED)


func _tick_slam(delta: float) -> void:
	velocity.x = (move_toward(global_position.x, _slam_target_x, speed * speed_multiplier() * delta) - global_position.x) / maxf(delta, 0.001)
	move_and_slide()
	if not is_on_floor():
		_airborne = true
	if _airborne and is_on_floor():
		_emit_slam_waves()
		EventBus.request_shake.emit(3.0, 0.2)
		state_machine.change_state(REST)
	elif _state_left <= 0.0 or global_position.y > _slam_start_y + 80.0:
		# Recover if a designer leaves an arena hole or a low ceiling blocks jump.
		global_position.y = _slam_start_y
		velocity = Vector2.ZERO
		state_machine.change_state(REST)


func _at_arena_edge() -> bool:
	return global_position.x <= arena_left + _body_half_size.x or global_position.x >= arena_right - _body_half_size.x


func _constrain_to_arena() -> void:
	var left := minf(arena_left, arena_right) + _body_half_size.x
	var right := maxf(arena_left, arena_right) - _body_half_size.x
	global_position.x = clampf(global_position.x, left, maxf(left, right))


func _spawn_projectile(at: Vector2, heading: Vector2, projectile_speed: float, wave: bool = false) -> EnemyProjectile:
	var projectile := HOSTILE_PROJECTILE.instantiate() as EnemyProjectile
	projectile.position = (get_parent() as Node2D).to_local(at)
	projectile.travel_direction = heading.normalized()
	projectile.speed = projectile_speed * speed_multiplier()
	projectile.ground_wave = wave
	projectile.source = self
	get_parent().add_child(projectile)
	_projectiles.append(projectile)
	return projectile


func _emit_slam_waves() -> void:
	AudioManager.play_sfx(&"boss_slam")
	var bounds: Rect2 = _world_body_bounds()
	for side in [-1, 1]:
		var at := Vector2(bounds.get_center().x + side * (bounds.size.x * 0.5 + 8.0), bounds.end.y - 8.0)
		_spawn_projectile(at, Vector2(side, 0), slam_wave_speed, true)


func _world_body_bounds() -> Rect2:
	return body_collision.global_transform * body_collision.shape.get_rect()


func _fire_fan() -> void:
	AudioManager.play_sfx(&"boss_shoot")
	_face_player()
	shot_point.position.x = direction * absf(shot_point.position.x)
	var aim := Vector2(direction, 0)
	if is_instance_valid(player):
		aim = (player.global_position + Vector2(0, -10) - shot_point.global_position).normalized()
	for angle in [-20.0, 0.0, 20.0]:
		_spawn_projectile(shot_point.global_position, aim.rotated(deg_to_rad(angle)), shot_speed)


func _on_summon_timeout() -> void:
	if dead or phase != 2 or _gate_left >= 0.0:
		return
	if _summoned_gate_count >= max_summon_gates:
		summon_timer.stop()
		return
	_summoned_gate_count += 1
	if _summoned_gate_count >= max_summon_gates:
		summon_timer.stop()
	_gate_left = telegraph + 0.35
	_spawned_this_gate = false
	summon_gate.global_position = _gate_anchor
	summon_gate.show()
	AudioManager.play_sfx(&"boss_summon")


func _tick_gate(delta: float) -> void:
	if _gate_left < 0.0:
		return
	summon_gate.global_position = _gate_anchor
	_gate_left -= delta
	summon_gate.scale = Vector2.ONE * (1.0 + 0.12 * sin(_gate_left * TAU * 6.0))
	if not _spawned_this_gate and _gate_left <= 0.35:
		_spawned_this_gate = true
		for side in [-1, 1]:
			var minion := SUMMONED_PATROL.instantiate() as PatrolEnemy
			var at := _gate_anchor + Vector2(side * 20.0, 0)
			at.x = clampf(at.x, arena_left + 12.0, arena_right - 12.0)
			minion.position = (get_parent() as Node2D).to_local(at)
			minion.face_right = side > 0
			minion.speed *= speed_multiplier()
			get_parent().add_child(minion)
			_minions.append(minion)
	if _gate_left <= 0.0:
		summon_gate.hide()
		_gate_left = -1.0


func _prune_spawned_nodes() -> void:
	# Freed objects cannot be cast into typed lambda arguments in Array.filter.
	for index in range(_projectiles.size() - 1, -1, -1):
		if not is_instance_valid(_projectiles[index]):
			_projectiles.remove_at(index)
	for index in range(_minions.size() - 1, -1, -1):
		if not is_instance_valid(_minions[index]):
			_minions.remove_at(index)


func _on_died() -> void:
	if dead:
		return
	dead = true
	control_enabled = false
	health.invincible = true
	summon_timer.stop()
	summon_gate.hide()
	_gate_left = -1.0
	_disable_hitboxes()
	_prune_spawned_nodes()
	for projectile in _projectiles:
		if is_instance_valid(projectile):
			projectile.set_active(false)
			projectile.queue_free()
	for minion in _minions:
		if is_instance_valid(minion):
			minion._disable_hitboxes()
			minion.queue_free()
	state_machine.change_state(STATE_DEAD)
	_drop_shards()
	GameManager.add_score(2000)
	AudioManager.play_sfx(&"enemy_die")
	EventBus.request_shake.emit(6.0, 0.8)
	EventBus.boss_defeated.emit()
	died_enemy.emit(self)


func _on_screen_exited() -> void:
	# Arena combat and phase communication continue while the camera moves.
	pass
