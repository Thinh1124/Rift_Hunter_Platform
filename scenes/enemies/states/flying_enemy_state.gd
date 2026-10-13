extends EnemyState
## The flying enemy has exactly three states, declared in FlyingEnemy.tscn.

func physics_update(delta: float) -> void:
	if not valid():
		return
	var flying := enemy as FlyingEnemy
	if flying == null:
		return
	match name:
		FlyingEnemy.STATE_IDLE:
			flying.tick_idle(delta)
		FlyingEnemy.STATE_DETECT_PLAYER:
			flying.tick_detect_player(delta)
		Enemy.STATE_DEAD:
			flying.tick_dead(delta)
