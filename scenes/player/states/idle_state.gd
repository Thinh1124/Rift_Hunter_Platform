extends PlayerState
## Đứng yên trên mặt đất.

func enter(_msg: Dictionary = {}) -> void:
	play_animation(&"idle")


func physics_update(_delta: float) -> void:
	if not alive():
		player.state_machine.change_state(Player.STATE_DEAD)
		return
	if player.has_jump_request() and player.do_jump():
		return
	if not player.is_on_floor():
		player.state_machine.change_state(Player.STATE_FALL)
		return
	if absf(player.input_dir) > 0.2:
		player.state_machine.change_state(Player.STATE_RUN)