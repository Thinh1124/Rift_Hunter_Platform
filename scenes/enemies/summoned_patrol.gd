extends PatrolEnemy
## Keep summoned enemies patrolling rather than entering the base chase cycle.
var _hurt_left: float = 0.0

func _ready() -> void:
	super._ready()
	sprite = $AnimatedSprite2D
	enter_state(STATE_PATROL)


func tick_patrol(delta: float) -> void:
	_apply_gravity(delta)
	if is_on_floor():
		velocity.y = gravity * delta
	_update_raycast_direction()
	wall_check.force_raycast_update()
	floor_check.force_raycast_update()
	if wall_check.is_colliding() or (is_on_floor() and not floor_check.is_colliding()):
		_flip()
		velocity.x = 0.0
	else:
		velocity.x = float(direction) * speed
	move_and_slide()


func enter_state(state_name: StringName) -> void:
	super.enter_state(state_name)
	if state_name == STATE_HURT:
		_hurt_left = hurt_stun
		velocity.x = 0.0
		play_anim(&"hit")


func tick_hurt(delta: float) -> void:
	_apply_gravity(delta)
	move_and_slide()
	_hurt_left -= delta
	if _hurt_left <= 0.0:
		state_machine.change_state(STATE_PATROL)


func _on_stomp_zone_area_entered(area: Area2D) -> void:
	if dead:
		return
	var target := area.get_parent() as Player
	if target == null or not target.can_stomp():
		return
	target.velocity.y = target.stomp_bounce
	take_damage(stomp_damage, target.global_position)
	AudioManager.play_sfx(&"stomp")
