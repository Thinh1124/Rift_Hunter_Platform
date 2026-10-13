class_name ShooterEnemy
extends Enemy

const BULLET = preload("res://scenes/objects/EnemyProjectile.tscn")
@export var fire_interval: float = 2.0
@export var bullet_speed: float = 120.0
@export var detect: float = 180.0

var _fire_left: float = 0.0
var _telegraph_left: float = -1.0
var _hurt_left: float = 0.0


func _ready() -> void:
	super._ready()
	state_machine.set_physics_process(false)
	_fire_left = fire_interval
	contact_hitbox.set_active(false)
	play_anim(&"idle")


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if dead:
		tick_dead(delta)
		return
	_apply_gravity(delta)
	if is_on_floor():
		velocity.y = gravity * delta
	velocity.x = 0.0
	move_and_slide()
	_hurt_left = maxf(0.0, _hurt_left - delta)
	if _hurt_left > 0.0:
		return
	_fire_left -= delta
	if _telegraph_left >= 0.0:
		_telegraph_left -= delta
		if sprite != null:
			var pulse := 0.5 + 0.5 * sin(_telegraph_left * TAU * 8.0)
			sprite.modulate = _base_modulate.lerp(Color(2, 1.5, 1.5), 0.5 + 0.5 * pulse)
		if _telegraph_left <= 0.0:
			if can_see_player():
				_fire()
			_telegraph_left = -1.0
			_fire_left = fire_interval
			if sprite != null:
				sprite.modulate = _base_modulate
	elif _fire_left <= 0.0 and can_see_player():
		AudioManager.play_sfx(&"enemy_detect")
		_telegraph_left = 0.3
	play_anim(&"idle")


func can_see_player() -> bool:
	if not is_instance_valid(player) or player.health == null or not player.health.is_alive():
		return false
	var offset := player.global_position + Vector2(0, -10) - global_position
	if offset.x * direction <= 0.0 or offset.length() > detect or absf(offset.y) > 24.0:
		return false
	var ray := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(direction * detect, 0), 3)
	ray.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(ray)
	return not hit.is_empty() and hit.collider == player


func _fire() -> void:
	AudioManager.play_sfx(&"enemy_attack")
	var projectile := BULLET.instantiate() as EnemyProjectile
	projectile.position = (get_parent() as Node2D).to_local(global_position + Vector2(direction * 12, 0))
	projectile.travel_direction = Vector2(direction, 0)
	projectile.speed = bullet_speed
	projectile.source = self
	get_parent().add_child(projectile)


func _on_damaged(_amount: int, _from_pos: Vector2) -> void:
	if health.is_alive():
		AudioManager.play_sfx(&"enemy_hurt")
	_start_flash()
	_telegraph_left = -1.0
	_fire_left = fire_interval
	_hurt_left = hurt_stun
	play_anim(&"hit")


func _on_stomp_zone_area_entered(area: Area2D) -> void:
	if dead:
		return
	var target := area.get_parent() as Player
	if target == null or not target.can_stomp():
		return
	target.velocity.y = target.stomp_bounce
	take_damage(stomp_damage, target.global_position)
	AudioManager.play_sfx(&"stomp")
