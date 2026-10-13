extends Node2D

const CHARACTERS: Array[String] = ["pink_man", "ninja_frog", "virtual_guy", "mask_dude"]
const ASSETS: Array[String] = ["Fireball", "ShurikenMagic", "EnergyBall", "Arrow"]
const FRAME_COUNTS: Array[int] = [4, 2, 4, 1]
var failures: int = 0
var player: Player

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

func _shoot(direction: int) -> Projectile:
	player.facing = direction
	player._update_throw_point()
	player.attack_cooldown_timer.stop()
	return player.throw_projectile()

func _wall(at: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = at
	body.collision_layer = 1
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(16, 40)
	collision.shape = rectangle
	body.add_child(collision)
	add_child(body)
	return body

func _run() -> void:
	player = preload("res://scenes/player/Player.tscn").instantiate() as Player
	player.position = Vector2(300, 200)
	add_child(player)
	player.set_physics_process(false)
	player.state_machine.set_physics_process(false)
	player.state_machine.set_process_unhandled_input(false)
	player.camera.enabled = false
	player.health.invincible = true
	for index in CHARACTERS.size():
		var id: String = CHARACTERS[index]
		var data: CharacterData = GameManager.load_character(id)
		_check(data != null and data.projectile_scene != null, id + " must have a projectile scene")
		player.apply_character(data)
		player.health.invincible = true
		for direction in [-1, 1]:
			var shot := _shoot(direction)
			_check(shot != null, id + " must fire")
			if shot == null:
				continue
			_check(shot.sprite.flip_h == (direction < 0), id + " must flip its projectile immediately when shooting left")
			_check(shot.direction == direction, id + " must use the facing direction")
			_check(shot.damage == 1 and shot.speed == player.projectile_speed, id + " must preserve damage and speed")
			var frames: SpriteFrames = shot.sprite.sprite_frames
			_check(frames.get_frame_count(&"fly") == FRAME_COUNTS[index], id + " must use every frame")
			for frame in FRAME_COUNTS[index]:
				var atlas := frames.get_frame_texture(&"fly", frame) as AtlasTexture
				_check(atlas != null and atlas.atlas.resource_path == "res://assets/projectiles/%s.png" % ASSETS[index], id + " must use its assigned asset")
			_check(shot.sprite.is_playing(), id + " must animate automatically")
			if id == "mask_dude":
				_check(is_equal_approx(shot.sprite.rotation, float(direction) * PI / 4.0), "Arrow must point along its flight direction")
			_check(player.throw_projectile() == null, id + " must block attacks during cooldown")
			_check(is_equal_approx(player.attack_cooldown_timer.wait_time, player.attack_cooldown * data.attack_cooldown_mult), id + " must respect its character cooldown")
			var position_before: Vector2 = shot.global_position
			var animation_ticks: Array[int] = [0]
			shot.sprite.frame_changed.connect(func() -> void: animation_ticks[0] += 1)
			await _frames(6)
			await get_tree().create_timer(0.12).timeout
			_check(is_instance_valid(shot), id + " must survive normal flight")
			if is_instance_valid(shot):
				_check((shot.global_position.x - position_before.x) * float(direction) > 0, id + " must travel in its facing direction")
				if FRAME_COUNTS[index] > 1:
					_check(animation_ticks[0] > 0, id + " animation must advance")
				shot.queue_free()
			await _frames(2)

			var wall := _wall(player.throw_point.global_position + Vector2(float(direction) * 40, 0))
			await _frames(2)
			shot = _shoot(direction)
			await _frames(18)
			_check(not is_instance_valid(shot), id + " must disappear when hitting World")
			wall.queue_free()
			await _frames(2)

			var enemy := preload("res://scenes/enemies/Enemy.tscn").instantiate() as Enemy
			enemy.max_hp = 3
			enemy.drops_shards = false
			enemy.position = player.throw_point.global_position + Vector2(float(direction) * 40, 0)
			add_child(enemy)
			enemy.set_physics_process(false)
			enemy.state_machine.set_physics_process(false)
			await _frames(2)
			shot = _shoot(direction)
			await _frames(18)
			_check(enemy.health.current == 2, id + " must damage the enemy exactly once")
			_check(not is_instance_valid(shot), id + " must disappear when hitting an enemy")
			enemy.queue_free()
			await _frames(2)

		player.projectile_life = 0.05
		var expiring := _shoot(1)
		await _frames(8)
		_check(not is_instance_valid(expiring), id + " must respect its configured lifetime")
		player.projectile_life = 1.5
		if DisplayServer.get_name() != "headless":
			player.projectile_life = 3.0
			player.projectile_speed = 1000.0
			var offscreen := _shoot(1)
			await _frames(45)
			_check(not is_instance_valid(offscreen), id + " must disappear offscreen before its lifetime expires")
			player.projectile_life = 1.5
			player.projectile_speed = 250.0
		player.attack_cooldown_timer.stop()
		player.health.current = 0
		_check(player.throw_projectile() == null, id + " must not fire when dead")
		player.health.reset()
		print(id + ": projectile checks finished")

	var fallback := CharacterData.new()
	fallback.sprite_frames = GameManager.load_character("pink_man").sprite_frames
	player.apply_character(fallback)
	_check(player.projectile_scene.resource_path == "res://scenes/objects/Projectile.tscn", "Changing to a character without a custom projectile must restore the default")
	player.queue_free()
	await _frames(2)
	print("CharacterProjectile checks complete: %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)
