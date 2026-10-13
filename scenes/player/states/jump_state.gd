extends PlayerState
## Đang bay lên.

func enter(_msg: Dictionary = {}) -> void:
	play_animation(&"jump")


func physics_update(_delta: float) -> void:
	if not alive():
		player.state_machine.change_state(Player.STATE_DEAD)
		return
	if player.velocity.y > 0.0:
		player.state_machine.change_state(Player.STATE_FALL)
		return
	if player.is_on_floor() and player.velocity.y >= 0.0:
		player.notify_landed()
		resume_ground_state()