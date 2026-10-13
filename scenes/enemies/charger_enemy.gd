class_name ChargerEnemy
extends Enemy

const WINDUP: StringName = &"Windup"
const DASH: StringName = &"Dash"
const STUNNED: StringName = &"Stunned"
const COOLDOWN: StringName = &"Cooldown"

@export_group("Charge")
@export_range(0.0, 600.0, 1.0) var detect: float = 160.0
@export_range(0.0, 5.0, 0.05) var windup: float = 0.5
@export_range(0.0, 1000.0, 1.0) var dash_speed: float = 200.0
@export_range(0.0, 5.0, 0.05) var stun_time: float = 1.5
@export_range(0.0, 5.0, 0.05) var cooldown: float = 1.0

@onready var sight_ray: RayCast2D = $SightRay
@onready var wall_check: RayCast2D = $WallCheck

var _state_left: float = 0.0
var _dash_direction: int = 1


func _ready() -> void:
	super._ready()
	# Child states enter before Enemy binds their owner, so enter Patrol again.
	enter_state(STATE_PATROL)
	_update_rays(0.0)


func enter_state(state_name: StringName) -> void:
	if sprite != null:
		sprite.modulate = _base_modulate
	if contact_hitbox != null:
		contact_hitbox.set_active(not dead and state_name != STUNNED and state_name != COOLDOWN and state_name != STATE_HURT)
	match state_name:
		STATE_PATROL:
			play_anim(&"run")
		WINDUP:
			velocity.x = 0.0
			_state_left = windup
			_face_player()
			play_anim(&"idle")
		DASH:
			_dash_direction = direction
			play_anim(&"run")
		STUNNED:
			velocity.x = 0.0
			_state_left = stun_time
			play_anim(&"hit")
			EventBus.request_shake.emit(2.0, 0.12)
		COOLDOWN:
			velocity.x = 0.0
			_state_left = cooldown
			play_anim(&"idle")
		STATE_HURT:
			velocity.x = 0.0
			_state_left = hurt_stun
			play_anim(&"hit")


func can_see_player() -> bool:
	if not is_instance_valid(player) or player.health == null or not player.health.is_alive():
		return false
	sight_ray.force_raycast_update()
	return sight_ray.is_colliding() and sight_ray.get_collider() == player


func _update_rays(travel: float) -> void:
	sight_ray.target_position = Vector2(float(direction) * detect, 0.0)
	wall_check.target_position = Vector2(float(direction) * (7.0 + travel), 0.0)
	sight_ray.force_raycast_update()
	wall_check.force_raycast_update()
	if sprite != null:
		sprite.flip_h = direction < 0


func _ledge_ahead(travel: float) -> bool:
	# Probe beyond the body's leading edge AND this frame's movement.
	var origin := global_position + Vector2(float(direction) * (7.0 + travel), 0.0)
	var query := PhysicsRayQueryParameters2D.create(origin, origin + Vector2(0.0, ledge_check_height), 1)
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func tick_charger(delta: float) -> void:
	if dead:
		tick_dead(delta)
		return
	_apply_gravity(delta)
	# Keep floor contact stable while standing or charging horizontally.
	if has_gravity and is_on_floor():
		velocity.y = gravity * delta
	var state := current_state()
	match state:
		STATE_PATROL:
			_update_rays(speed * delta)
			if wall_check.is_colliding() or (is_on_floor() and _ledge_ahead(speed * delta)):
				_flip()
				velocity.x = 0.0
				_update_rays(speed * delta)
			else:
				velocity.x = float(direction) * speed
			move_and_slide()
			if is_on_floor() and can_see_player():
				state_machine.change_state(WINDUP)
		WINDUP:
			_face_player()
			_update_rays(0.0)
			_wait(delta, DASH)
			if current_state() == WINDUP and sprite != null:
				var pulse := 0.5 + 0.5 * sin((windup - _state_left) * TAU * 8.0)
				sprite.modulate = _base_modulate.lerp(Color(1.0, 0.08, 0.08), 0.55 + pulse * 0.45)
		DASH:
			direction = _dash_direction
			_update_rays(dash_speed * delta)
			if wall_check.is_colliding():
				state_machine.change_state(STUNNED)
			elif not is_on_floor() or _ledge_ahead(dash_speed * delta):
				_flip()
				state_machine.change_state(COOLDOWN)
			else:
				velocity.x = float(_dash_direction) * dash_speed
				move_and_slide()
				if is_on_wall():
					state_machine.change_state(STUNNED)
				else:
					_hit_player_during_dash()
		STUNNED, COOLDOWN, STATE_HURT:
			_wait(delta, STATE_PATROL)


func _wait(delta: float, next_state: StringName) -> void:
	velocity.x = 0.0
	move_and_slide()
	_state_left -= delta
	if _state_left <= 0.0:
		state_machine.change_state(next_state)


func _hit_player_during_dash() -> void:
	if contact_hitbox == null:
		return
	for area in contact_hitbox.get_overlapping_areas():
		var target := area as HurtboxComponent
		if target == null or not target.get_parent().is_in_group(&"player"):
			continue
		# Same receiver path as ordinary contact: respects invincibility and
		# prevents duplicate damage if area_entered already delivered the hit.
		target._on_area_entered(contact_hitbox)
		state_machine.change_state(COOLDOWN)
		return
