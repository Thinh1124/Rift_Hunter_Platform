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


## Số quái đang còn sống và nằm gần vị trí spawner.
func _enemies_near(center: Vector2, tolerance: float) -> int:
	var found := 0
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy := node as Enemy
		if enemy != null and enemy.dead:
			continue
		if (node as Node2D).global_position.distance_to(center) <= tolerance:
			found += 1
	return found


func _run() -> void:
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(300, 240)
	var floor_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(900, 20)
	floor_shape.shape = rectangle
	floor_body.add_child(floor_shape)
	add_child(floor_body)

	GameManager.lives = 3
	GameManager.last_checkpoint = Vector2(100, 230)
	var player := preload("res://scenes/player/Player.tscn").instantiate() as Player
	player.position = Vector2(100, 230)
	add_child(player)
	player.camera.enabled = false
	var camera := Camera2D.new()
	camera.position = Vector2(400, 320)
	add_child(camera)
	camera.make_current()
	await _frames(4)

	# --- once = true ----------------------------------------------------
	var spawner := preload("res://scenes/objects/EnemySpawner.tscn").instantiate() as EnemySpawner
	spawner.position = Vector2(400, 170)
	spawner.enemy_scene = preload("res://scenes/enemies/SummonedPatrolEnemy.tscn")
	spawner.count = 3
	spawner.radius = 48.0
	spawner.once = true
	add_child(spawner)
	await _frames(2)
	_check(spawner.trigger_zone.collision_mask == 2, "TriggerZone must watch the Player layer")
	_check(spawner.enemy_scene != null, "Spawner must have a default enemy_scene for drag-and-drop use")
	var away := Vector2(100, 230)
	await _frames(6)
	_check(_enemies_near(spawner.global_position, 96.0) == 0, "No enemy may spawn before the player enters the zone")

	# Bước vào vùng -> đổ count quái.
	var center := spawner.global_position
	player.position = Vector2(400, 170)
	player.velocity = Vector2.ZERO
	await _frames(5)
	_check(spawner.spawned_count() == 3, "Entering the zone must spawn exactly count enemies")
	_check(_enemies_near(center, 96.0) == 3, "Every enemy must spawn within radius of the spawner")
	var puffs := 0
	for child in get_children():
		puffs += 1 if child is DustFX else 0
	_check(puffs >= 3, "Spawning must emit a smoke puff per enemy")

	# once = true -> rời rồi vào lại vẫn không đổ thêm.
	player.position = away
	player.velocity = Vector2.ZERO
	await _frames(8)
	player.position = Vector2(400, 170)
	player.velocity = Vector2.ZERO
	await _frames(8)
	_check(spawner.spawned_count() == 3, "once=true must spawn only one batch")
	_check(_enemies_near(center, 96.0) == 3, "once=true must not add enemies on re-entry")
	_check(not spawner.trigger_zone.monitoring, "once=true must disable the TriggerZone after spawning")

	# --- once = false ---------------------------------------------------
	var repeating := preload("res://scenes/objects/EnemySpawner.tscn").instantiate() as EnemySpawner
	repeating.position = Vector2(600, 170)
	repeating.count = 2
	repeating.once = false
	add_child(repeating)
	var repeat_center := repeating.global_position
	await _frames(2)
	player.position = Vector2(600, 170)
	player.velocity = Vector2.ZERO
	await _frames(8)
	_check(repeating.spawned_count() == 2, "once=false must spawn on every entry")
	_check(_enemies_near(repeat_center, 96.0) == 2, "once=false must place its batch around the spawner")
	player.position = away
	player.velocity = Vector2.ZERO
	await _frames(10)
	player.position = Vector2(600, 170)
	player.velocity = Vector2.ZERO
	await _frames(8)
	_check(repeating.spawned_count() == 4, "once=false must spawn again after re-entering")
	_check(repeating.trigger_zone.monitoring, "once=false must keep the TriggerZone active")

	# --- enemy_scene rỗng -> cảnh báo, không crash ------------------------
	var empty := preload("res://scenes/objects/EnemySpawner.tscn").instantiate() as EnemySpawner
	empty.position = Vector2(760, 170)
	empty.enemy_scene = null
	add_child(empty)
	var empty_center := empty.global_position
	await _frames(2)
	player.position = Vector2(760, 170)
	player.velocity = Vector2.ZERO
	await _frames(8)
	_check(empty.spawned_count() == 0, "A spawner without enemy_scene must not count a batch")
	_check(_enemies_near(empty_center, 96.0) == 0, "A spawner without enemy_scene must spawn nothing")
	print("EnemySpawner checks complete: %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)