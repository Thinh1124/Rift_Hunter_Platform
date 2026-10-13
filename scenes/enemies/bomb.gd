class_name BombEnemy
extends PatrolEnemy
## Patrol -> Chase -> Attack (fuse) -> Dead. Explosion damages each player once.

@export_range(0.0, 400.0, 1.0) var chase_speed: float = 65.0
@export_range(8.0, 128.0, 1.0) var trigger_radius: float = 28.0
@export_range(8.0, 256.0, 1.0) var explosion_radius: float = 48.0
@export_range(0.0, 3.0, 0.05) var fuse_time: float = 0.45
@export_range(1, 99, 1) var explosion_damage: int = 2
@export_range(1.0, 20.0, 0.5) var fuse_flash_frequency: float = 6.0
@export_range(0.0, 20.0, 0.5) var explosion_shake_strength: float = 4.0
@export_range(0.0, 2.0, 0.05) var explosion_shake_duration: float = 0.2

@onready var explosion_hitbox: HitboxComponent = %ExplosionHitbox
@onready var explosion_shape: CollisionShape2D = %ExplosionShape

var _fuse_left: float = 0.0
var _hurt_left: float = 0.0
var _detonated: bool = false


func _ready() -> void:
	super._ready()
	contact_hitbox.set_active(false)
	var circle := explosion_shape.shape.duplicate() as CircleShape2D
	circle.radius = explosion_radius
	explosion_shape.shape = circle
	explosion_hitbox.damage = explosion_damage


func enter_state(state_name: StringName) -> void:
	if state_name == STATE_ATTACK:
		_fuse_left = fuse_time
		velocity.x = 0.0
		play_anim(&"hit")
		AudioManager.play_sfx(&"bomb_fuse")
	else:
		super.enter_state(state_name)
		if state_name == STATE_HURT:
			_hurt_left = hurt_stun


func tick_patrol(delta: float) -> void:
	if dead:
		return
	if can_see_player():
		state_machine.change_state(STATE_CHASE)
		return
	super.tick_patrol(delta)


func tick_detect(delta: float) -> void:
	state_machine.change_state(STATE_CHASE)
	tick_chase(delta)


func tick_chase(delta: float) -> void:
	if dead:
		return
	if not can_see_player():
		state_machine.change_state(STATE_PATROL)
		return
	if distance_to_player() <= trigger_radius:
		state_machine.change_state(STATE_ATTACK)
		return
	_face_player()
	_apply_gravity(delta)
	if is_on_floor():
		velocity.y = gravity * delta
	var patrol_speed: float = speed
	speed = chase_speed
	_step(delta)
	speed = patrol_speed


func tick_attack(delta: float) -> void:
	if dead or _detonated:
		return
	_apply_gravity(delta)
	velocity.x = 0.0
	move_and_slide()
	_fuse_left -= delta
	if sprite != null:
		var pulse: float = 0.5 + 0.5 * sin((fuse_time - _fuse_left) * TAU * fuse_flash_frequency)
		sprite.modulate = _base_modulate.lerp(Color(1, 0.2, 0.2), pulse)
	if _fuse_left <= 0.0:
		_detonate()


func tick_hurt(delta: float) -> void:
	super.tick_hurt(delta)
	_hurt_left -= delta
	if _hurt_left <= 0.0:
		state_machine.change_state(STATE_CHASE if can_see_player() else STATE_PATROL)


func _detonate() -> void:
	if dead or _detonated:
		return
	_detonated = true
	explosion_hitbox.set_active(true)
	# Query once; the area remains non-monitorable to prevent duplicate hits.
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = explosion_shape.shape
	query.transform = explosion_shape.global_transform
	query.collision_mask = 2
	query.collide_with_bodies = true
	query.collide_with_areas = false
	for hit: Dictionary in get_world_2d().direct_space_state.intersect_shape(query, 32):
		var target := hit["collider"] as Player
		if target != null and target.hurtbox != null:
			target.hurtbox._on_area_entered(explosion_hitbox)
	explosion_hitbox.set_active(false)
	AudioManager.play_sfx(&"bomb_explode")
	EventBus.request_shake.emit(explosion_shake_strength, explosion_shake_duration)
	health.current = 0
	health.health_changed.emit(0, health.max_health)
	health.died.emit()


func _on_died() -> void:
	if dead:
		return
	super._on_died()
	velocity = Vector2.ZERO
	if sprite != null:
		sprite.modulate = _base_modulate


func tick_dead(delta: float) -> void:
	_dead_left -= delta
	if _dead_left <= 0.0:
		queue_free()
