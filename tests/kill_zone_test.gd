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
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(50, 200)
	var floor_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(100, 20)
	floor_shape.shape = rectangle
	floor_body.add_child(floor_shape)
	add_child(floor_body)
	var zone := preload("res://scenes/objects/KillZone.tscn").instantiate() as KillZone
	zone.position = Vector2(200, 300)
	(zone.get_node("CollisionShape2D").shape as RectangleShape2D).size = Vector2(600, 80)
	add_child(zone)
	_check(zone.collision_layer == 128 and zone.collision_mask == 2, "KillZone must use layer 8 and mask 2")
	var other_zone := preload("res://scenes/objects/KillZone.tscn").instantiate() as KillZone
	_check((other_zone.get_node("CollisionShape2D").shape as RectangleShape2D).size == Vector2(1280, 96), "Resizing one instance must not resize all KillZones")
	other_zone.free()
	GameManager.lives = 3
	GameManager.last_checkpoint = Vector2(50, 190)
	var player := preload("res://scenes/player/Player.tscn").instantiate() as Player
	player.position = GameManager.last_checkpoint
	add_child(player)
	await _frames(4)
	player.add_shield(8)
	player._start_iframe(2.0)
	player.position = Vector2(220, 100)
	player.velocity.y = 200
	for i in range(120):
		await get_tree().physics_frame
		if player.current_state() == Player.STATE_DEAD:
			break
	_check(player.current_state() == Player.STATE_DEAD and player.health.current == 0, "Falling into KillZone must kill Player through real body overlap")
	_check(not player.shield_active, "KillZone must bypass shield and i-frames")
	zone._on_body_entered(player)
	zone._on_body_entered(player)
	await _frames(60)
	_check(GameManager.lives == 2, "Repeated hazard contact must cost exactly one life")
	_check(player.health.is_alive() and player.current_state() != Player.STATE_DEAD, "Player must respawn alive")
	_check(player.global_position.distance_to(GameManager.last_checkpoint) < 1.0 and player.is_on_floor(), "Player must respawn at checkpoint and stand on floor")
	await _frames(60)
	_check(GameManager.lives == 2, "Respawn outside KillZone must not deduct more lives")
	# Verify both enemy collision conventions, with no kill score awarded.
	var score_before := GameManager.score
	var legacy_enemy := CharacterBody2D.new()
	legacy_enemy.collision_layer = 3
	legacy_enemy.add_to_group(&"enemy")
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	legacy_enemy.add_child(shape)
	legacy_enemy.position = Vector2(120, 300)
	add_child(legacy_enemy)
	var modern_enemy := preload("res://scenes/enemies/ShooterEnemy.tscn").instantiate() as ShooterEnemy
	modern_enemy.position = Vector2(280, 300)
	add_child(modern_enemy)
	var neutral := StaticBody2D.new()
	neutral.position = Vector2(340, 300)
	neutral.collision_layer = 4
	var neutral_shape := CollisionShape2D.new()
	neutral_shape.shape = RectangleShape2D.new()
	neutral.add_child(neutral_shape)
	add_child(neutral)
	await _frames(5)
	_check(not is_instance_valid(legacy_enemy), "Mask 2 must remove legacy enemy bodies")
	_check(not is_instance_valid(modern_enemy), "Layer 3 enemies must also be removed")
	_check(is_instance_valid(neutral), "Non-enemy bodies must be ignored")
	_check(GameManager.score == score_before, "Falling enemies must not award kill score")
	print("KillZone checks complete: %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)
