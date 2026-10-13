extends Node2D

var failures: int = 0

func _ready() -> void:
	call_deferred(&"_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
	await get_tree().process_frame

func _player(at: Vector2) -> Player:
	var target := preload("res://scenes/player/Player.tscn").instantiate() as Player
	target.character_override = GameManager.load_character("pink_man")
	target.position = at
	add_child(target)
	target.set_physics_process(false)
	target.state_machine.set_physics_process(false)
	target.velocity = Vector2.ZERO
	return target

func _bomb(at: Vector2) -> BombEnemy:
	var bomb := preload("res://scenes/enemies/Bomb.tscn").instantiate() as BombEnemy
	bomb.position = at
	add_child(bomb)
	return bomb

func _wait_dead(bomb: BombEnemy) -> void:
	for i in 240:
		if bomb.dead:
			return
		await _frames(1)
	_check(false, "Bomb must detonate after chasing and fusing")

func _run() -> void:
	var ground := StaticBody2D.new()
	ground.position = Vector2(300, 220)
	ground.collision_layer = 1
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(900, 40)
	collision.shape = rectangle
	ground.add_child(collision)
	add_child(ground)

	var target := _player(Vector2(220, 200))
	var bomb := _bomb(Vector2(100, 188))
	var score_before: int = GameManager.score
	var shards_before: int = get_tree().get_nodes_in_group(&"pickup").size()
	await _frames(30)
	_check(bomb.position.x > 110 and bomb.current_state() == &"Chase", "Bomb must chase the player horizontally")
	_check(target.health.current == 3 and not bomb.contact_hitbox.is_active(), "Touch damage must be disabled before the explosion")
	await _wait_dead(bomb)
	_check(bomb.dead and target.health.current == 1, "Explosion must remove exactly two HP")
	_check(bomb.sprite.animation == &"dead", "Bomb must play its explosion animation")
	await _frames(3)
	_check(GameManager.score == score_before + bomb.score_value, "Explosion must award score once")
	_check(get_tree().get_nodes_in_group(&"pickup").size() == shards_before + bomb.shard_drop, "Explosion must drop its configured shard")
	bomb._detonate()
	await _frames(3)
	_check(target.health.current == 1 and GameManager.score == score_before + bomb.score_value, "Explosion cannot hit or reward twice")
	bomb.queue_free()
	target.queue_free()
	await _frames(3)

	# Escape the fuse radius: no damage outside the blast.
	target = _player(Vector2(200, 200))
	bomb = _bomb(Vector2(178, 188))
	await _frames(4)
	_check(bomb.current_state() == &"Attack", "A nearby player must start the fuse")
	target.position = Vector2(450, 200)
	await _wait_dead(bomb)
	_check(target.health.current == 3, "Escaping the blast radius must prevent damage")
	bomb.queue_free()
	target.queue_free()
	await _frames(3)

	# Existing shields and invulnerability must still protect the player.
	for shield in [false, true]:
		target = _player(Vector2(200, 200))
		if shield:
			target.add_shield(8)
		else:
			target.health.invincible = true
		bomb = _bomb(Vector2(178, 188))
		await _wait_dead(bomb)
		_check(target.health.current == 3, "Shield / invulnerability must block explosion damage")
		bomb.queue_free()
		target.queue_free()
		await _frames(3)

	# Killing the bomb before its fuse finishes prevents the damaging blast.
	target = _player(Vector2(200, 200))
	bomb = _bomb(Vector2(178, 188))
	await _frames(4)
	bomb.take_damage(2, target.position)
	await _frames(35)
	_check(target.health.current == 3 and not bomb._detonated, "A defeated bomb must not detonate later")
	bomb.queue_free()
	target.queue_free()
	await _frames(3)
	AudioManager.stop_sfx()
	await get_tree().create_timer(0.1).timeout
	print("Bomb checks complete: %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)
