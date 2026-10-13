extends EnemyState
## Charger keeps the inherited health/death states and adds its attack cycle.

func enter(_msg: Dictionary = {}) -> void:
	if valid():
		enemy.enter_state(name)


func physics_update(delta: float) -> void:
	if valid():
		enemy.tick_charger(delta)
