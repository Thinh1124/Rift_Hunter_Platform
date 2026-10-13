extends Node2D

var failures: int = 0
var endpoints: Array[int] = []


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
	var saw := preload("res://scenes/objects/Saw.tscn").instantiate() as Saw
	add_child(saw)
	saw.set_physics_process(false)
	saw.endpoint_reached.connect(func(endpoint: int) -> void: endpoints.append(endpoint))
	_check(saw.hitbox.collision_layer == 128 and saw.hitbox.collision_mask == 2 and saw.hitbox.damage == 1, "Saw hitbox must use layer 8, mask 2, damage 1")
	_check((saw.hitbox.get_node("CollisionShape2D").shape as CircleShape2D).radius == 14, "Saw collision must be circle radius 14")
	_check(saw.point_a.position == Vector2.ZERO and saw.point_b.position == Vector2(96, 0), "Default endpoints must span 96 pixels")
	saw._tick_motion(0.5)
	_check(saw.hitbox.position.is_equal_approx(Vector2(30, 0)), "Saw must travel at 60 pixels/second")
	saw._tick_motion(1.1)
	_check(saw.hitbox.position.is_equal_approx(Vector2(96, 0)) and endpoints == [1], "Saw must reach endpoint B without overshoot")
	_check(not saw.sparks.emitting, "Open endpoint must not emit wall sparks")
	saw._tick_motion(0.2)
	_check(saw.hitbox.position.is_equal_approx(Vector2(96, 0)), "Saw must pause at endpoint")
	saw._tick_motion(0.2)
	_check(saw.hitbox.position.is_equal_approx(Vector2(90, 0)), "Saw must reverse after 0.3-second pause")
	saw._tick_motion(1.5)
	_check(saw.hitbox.position.is_equal_approx(Vector2.ZERO) and endpoints == [1, 0], "Saw must return to endpoint A")
	saw.path_length = 192
	saw.direction = Vector2(0, 4)
	_check(saw.point_b.position == Vector2(0, 192), "Inspector exports must change length and normalize direction")
	saw._tick_motion(1.0)
	_check(saw.hitbox.position.is_equal_approx(Vector2(0, 60)), "Saw must support vertical routes")
	saw.path_length = 0
	saw._tick_motion(10)
	_check(saw.hitbox.position == Vector2.ZERO, "Zero-length routes must remain stationary")
	saw.path_length = 96
	saw.direction = Vector2.ZERO
	saw._tick_motion(10)
	_check(saw.hitbox.position == Vector2.ZERO, "Zero direction must not produce invalid motion")
	saw.direction = Vector2.RIGHT
	saw.speed = 0
	saw._physics_process(0.125)
	_check(is_equal_approx(saw.sprite.rotation, PI * 0.5), "Sprite must rotate at 720 degrees/second even when stationary")
	_check(saw.sprite.is_playing(), "Saw must play spin animation")
	saw.speed = 60
	# A real world collider immediately past B must produce a short spark burst.
	var wall := StaticBody2D.new()
	wall.position = Vector2(114, 0)
	var wall_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(8, 64)
	wall_shape.shape = rectangle
	wall.add_child(wall_shape)
	add_child(wall)
	await _frames(3)
	saw._tick_motion(1.6)
	_check(saw.sparks.emitting and saw.sparks.global_position.x >= 109, "Wall at endpoint must emit sparks at impact position")
	await _frames(20)
	_check(not saw.sparks.emitting, "Sparks must stop after a short burst")
	wall.queue_free()
	await _frames(3)
	# Endpoint effects must not mistake legacy enemy layer bits for world walls.
	var enemy := StaticBody2D.new()
	enemy.collision_layer = 3
	enemy.add_to_group(&"enemy")
	enemy.position = Vector2(114, 0)
	var enemy_shape := CollisionShape2D.new()
	enemy_shape.shape = rectangle
	enemy.add_child(enemy_shape)
	add_child(enemy)
	await _frames(3)
	saw.path_length = 96
	saw._tick_motion(1.6)
	_check(not saw.sparks.emitting, "Enemy bodies must not trigger endpoint wall sparks")
	enemy.queue_free()
	# Exercise normal physics movement and Player hurtbox immunity.
	saw.path_length = 96
	saw.set_physics_process(true)
	await _frames(30)
	_check(saw.hitbox.position.x >= 29 and saw.hitbox.position.x <= 33, "Saw must move during physics frames")
	saw.set_physics_process(false)
	saw.path_length = 96
	var player := preload("res://scenes/player/Player.tscn").instantiate() as Player
	player.position = Vector2(-100, 0)
	add_child(player)
	player.set_physics_process(false)
	player.state_machine.set_physics_process(false)
	var hp := player.health.current
	player.position = Vector2(0, 9)
	await _frames(4)
	_check(player.health.current == hp - 1 and player.health.is_alive(), "Saw contact must cause one damage rather than instant death")
	saw.hitbox.damage = 2
	player.hurtbox._on_area_entered(saw.hitbox)
	_check(player.health.current == hp - 1, "Saw must respect player i-frames")
	saw.damage = 3
	_check(saw.hitbox.damage == 3, "Damage export must update nested hitbox")
	print("Saw checks complete: %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)
