extends PlayerState
## Đang rơi xuống.

func enter(_msg: Dictionary = {}) -> void:
	play_animation(&"fall")


func physics_update(_delta: float) -> void:
	if not alive():
		player.state_machine.change_state(Player.STATE_DEAD)
		return
	# Cửa sổ coyote vẫn nhảy được, và cú nhảy lần 2 trên không (nếu nhân vật có
	# năng kỹ đặt). do_jump() tự phân biệt nên không cần kiểm tra coyote ở đây.
	if player.has_jump_request() and player.do_jump():
		return
	if player.is_on_floor():
		player.notify_landed()
		resume_ground_state()