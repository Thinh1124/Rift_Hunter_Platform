class_name PlayerState
extends State
## Base của các state của Player. Tên node = tên state (Idle, Run, Jump, Fall, Hit, Dead).

var player: Player


func setup(p: Player) -> void:
	player = p


func play_animation(anim: StringName) -> void:
	if is_instance_valid(player):
		player.play_animation(anim)


func valid() -> bool:
	return is_instance_valid(player) and player.state_machine != null


func alive() -> bool:
	return valid() and player.health != null and player.health.is_alive()


## Quay về state phù hợp với việc đang đứng / đang bay.
func resume_ground_state() -> void:
	if absf(player.input_dir) > 0.2:
		player.state_machine.change_state(Player.STATE_RUN)
	else:
		player.state_machine.change_state(Player.STATE_IDLE)