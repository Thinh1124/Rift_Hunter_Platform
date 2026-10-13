extends PlayerState
## Đang bay lên.

func enter(_msg: Dictionary = {}) -> void:
	# Player tự chọn clip: nhảy lần 2 trên không dùng "double_jump", nhân vật
	# không có clip đó thì về "jump".
	player.apply_jump_animation()


func physics_update(_delta: float) -> void:
	if not alive():
		player.state_machine.change_state(Player.STATE_DEAD)
		return
	# Nhảy 2 lần phải dùng được cả lúc ĐANG BAY LÊN, không chỉ lúc rơi xuống.
	# Nếu chỉ để fall_state xử lý thì bấm jump sớm sẽ không có tác dụng gì.
	if player.can_air_jump() and player.has_jump_request() and player.do_jump():
		return
	if player.velocity.y > 0.0:
		player.state_machine.change_state(Player.STATE_FALL)
		return
	if player.is_on_floor() and player.velocity.y >= 0.0:
		player.notify_landed()
		resume_ground_state()