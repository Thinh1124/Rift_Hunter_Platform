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


## Gọi enter_state() khi state được kích hoạt.
func enter(_msg: Dictionary = {}) -> void:
	if valid():
		enemy.enter_state(name)


## Gọi tick_* method tương ứng theo state name.
func physics_update(delta: float) -> void:
	if not valid():
		return
	
	match name:
		&"Patrol":
			enemy.tick_patrol(delta)
		&"Detect":
			enemy.tick_detect(delta)
		&"Chase":
			enemy.tick_chase(delta)
		&"Attack":
			enemy.tick_attack(delta)
		&"Hurt":
			enemy.tick_hurt(delta)
		&"Dead":
			enemy.tick_dead(delta)
		&"Return":
			if enemy.has_method(&"tick_return"):
				enemy.tick_return(delta)