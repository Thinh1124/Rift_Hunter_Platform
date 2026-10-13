extends EnemyState

func physics_update(delta: float) -> void:
	if valid():
		enemy.tick_boss(delta)
