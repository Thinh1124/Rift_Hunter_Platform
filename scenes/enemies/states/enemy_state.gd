class_name EnemyState
extends State
## Base của các state của Enemy. Tên node = tên state (Patrol, Detect, ...).

var enemy: Enemy


func setup(e: Enemy) -> void:
	enemy = e


func valid() -> bool:
	return is_instance_valid(enemy) and enemy.state_machine != null


func alive() -> bool:
	return valid() and enemy.health != null and enemy.health.is_alive()


func play(anim: StringName) -> void:
	if valid():
		enemy.play_anim(anim)