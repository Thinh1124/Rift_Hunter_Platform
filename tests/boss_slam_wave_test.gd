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

func _run() -> void:
	for size: float in [1.0, 0.8, 0.6]:
		var arena := Node2D.new()
		arena.position = Vector2(80, 40)
		add_child(arena)
		var floor_body := StaticBody2D.new()
		floor_body.position = Vector2(0, 210)
		floor_body.collision_layer = 1
		var collision := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(1000, 20)
		collision.shape = rectangle
		floor_body.add_child(collision)
		arena.add_child(floor_body)
		var target := preload("res://scenes/player/Player.tscn").instantiate() as Player
		target.position = Vector2(180, 200)
		arena.add_child(target)
		target.set_physics_process(false)
		target.state_machine.set_physics_process(false)
		target.health.invincible = true
		var boss := preload("res://scenes/enemies/Boss.tscn").instantiate() as Boss
		boss.scale = Vector2.ONE * size
		boss.position = Vector2(0, 140)
		boss.rest_time = 60
		boss.max_summon_gates = 0
		boss.arena_left = -320
		boss.arena_right = 480
		arena.add_child(boss)
		await _frames(30)
		_check(boss.is_on_floor(), "Boss must settle before Slam")
		boss.state_machine.change_state(&"Slam")
		for i in 180:
			await _frames(1)
			if boss.current_state() != &"Slam":
				break
		_check(boss.current_state() == &"Rest" and boss.is_on_floor(), "Slam must land and recover")
		await _frames(6)
		var waves: Array[EnemyProjectile] = []
		for projectile in boss._projectiles:
			if is_instance_valid(projectile) and projectile.ground_wave:
				waves.append(projectile)
		_check(waves.size() == 2, "Scale %.1f: landing must create two surviving ground waves" % size)
		for wave in waves:
			_check(absf(wave.global_position.y - 232.0) < 0.5, "Waves must travel eight pixels above the actual floor")
			_check(wave.is_active(), "Ground waves must retain their damage hitbox")
		arena.queue_free()
		await _frames(3)
	await _test_level6()
	AudioManager.stop_music()
	AudioManager.stop_sfx()
	await get_tree().create_timer(0.1).timeout
	print("Boss Slam wave checks complete: %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)


func _test_level6() -> void:
	var level := preload("res://scenes/levels/Level6.tscn").instantiate() as LevelBase
	add_child(level)
	var boss := level.get_node("Objects/Boss") as Boss
	level.player.set_physics_process(false)
	level.player.state_machine.set_physics_process(false)
	level.player.health.invincible = true
	level.player.position.x = boss.global_position.x
	level.player.camera.force_update_scroll()
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy := node as Enemy
		if enemy != null and enemy != boss:
			enemy.set_physics_process(false)
			enemy.state_machine.set_physics_process(false)
			enemy.contact_hitbox.set_active(false)
	boss._state_left = 60
	await _frames(30)
	_check(boss.is_on_floor(), "Level6 boss must be grounded before Slam")
	boss.state_machine.change_state(&"Slam")
	for i in 180:
		await _frames(1)
		if boss.current_state() != &"Slam":
			break
	_check(boss.current_state() == &"Rest" and boss.is_on_floor(), "Level6 Slam must land and recover")
	await _frames(6)
	var waves: int = 0
	for projectile in boss._projectiles:
		if is_instance_valid(projectile) and projectile.ground_wave:
			waves += 1
	_check(waves == 2, "Level6 scaled boss must produce two surviving ground waves")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/map_previews/level6_slam_fixed.png")
	level.queue_free()
	await _frames(3)
