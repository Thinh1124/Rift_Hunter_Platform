extends PlayerState
## Bị đánh: bị đẩy lùi, mất quyền điều khiển trong hit_lock_time.

var _timer: float = 0.0


func enter(msg: Dictionary = {}) -> void:
	var from: Vector2 = msg.get("from", Vector2.ZERO)
	var away: float = signf(player.global_position.x - from.x)
	if is_zero_approx(away):
		away = float(player.facing)
	player.velocity = Vector2(away * player.hit_knockback.x, player.hit_knockback.y)
	player.set_control_enabled(false)
	_timer = player.hit_lock_time
	play_animation(&"hit")


func physics_update(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	player.set_control_enabled(true)
	if not alive():
		player.state_machine.change_state(Player.STATE_DEAD)
		return
	if player.is_on_floor():
		resume_ground_state()
	else:
		player.state_machine.change_state(Player.STATE_FALL)


func exit() -> void:
	player.set_control_enabled(true)