extends PlayerState
## Đang rơi xuống.

func enter(_msg: Dictionary = {}) -> void:
	play_animation(&"fall")


func physics_update(_delta: float) -> void:
	if not alive():
		player.state_machine.change_state(Player.STATE_DEAD)
		return
	# Cửa sổ coyote: vừa rời mép mà vẫn kịp bấm jump thì vẫn nhảy được.
	if not player.coyote_timer.is_stopped() and player.has_jump_request() and player.do_jump():
		return
	if player.is_on_floor():
		player.notify_landed()
		resume_ground_state()