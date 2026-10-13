extends Node2D

var failures: int = 0
var _reached_count: int = 0
var _bus_count: int = 0


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
	rectangle.size = Vector2(300, 20)
	floor_shape.shape = rectangle
	floor_body.add_child(floor_shape)
	add_child(floor_body)

	var checkpoint := preload("res://scenes/objects/Checkpoint.tscn").instantiate() as Checkpoint
	checkpoint.position = Vector2(150, 190)
	add_child(checkpoint)
	checkpoint.reached.connect(func(_pos: Vector2) -> void: _reached_count += 1)
	EventBus.checkpoint_reached.connect(func(_pos: Vector2) -> void: _bus_count += 1)
	await _frames(2)
	_check(checkpoint.collision_layer == 64 and checkpoint.collision_mask == 2, "Checkpoint must use layer 7 and mask 2")
	_check(checkpoint.is_in_group(&"checkpoint"), "Checkpoint must join group \"checkpoint\"")
	_check(checkpoint.sprite.sprite_frames == checkpoint.frames_locked and checkpoint.sprite.is_playing(), "Unvisited checkpoint must play the locked flag animation")
	_check(checkpoint.sprite.animation == Checkpoint.ANIM_LOCKED, "Unvisited checkpoint must start with flag_out")
	_check(checkpoint.sprite.sprite_frames.has_animation(Checkpoint.ANIM_LOCKED), "Locked SpriteFrames must contain the off animation")

	GameManager.lives = 3
	GameManager.last_checkpoint = Vector2(50, 190)
	var player := preload("res://scenes/player/Player.tscn").instantiate() as Player
	player.position = Vector2(40, 190)
	add_child(player)
	player.camera.enabled = false
	var camera := Camera2D.new()
	camera.position = Vector2(150, 300)
	add_child(camera)
	camera.make_current()
	await _frames(4)
	_check(not checkpoint.is_reached(), "Standing away from the flag must not activate it")

	# Chạm lần đầu -> cờ bay, lưu checkpoint, phát EventBus, hạt vàng.
	player.position = Vector2(150, 190)
	player.velocity = Vector2.ZERO
	await _frames(6)
	_check(checkpoint.is_reached(), "Touching the flag must activate it")
	_check(checkpoint.sprite.animation == Checkpoint.ANIM_WAVING, "Activated checkpoint must switch to the waving flag animation")
	_check(GameManager.last_checkpoint == checkpoint.global_position, "Activated checkpoint must save its global position")
	_check(_reached_count == 1 and _bus_count == 1, "Activation must emit reached and checkpoint_reached exactly once")
	var has_gold := false
	for child in get_children():
		has_gold = has_gold or child is PickupFX
	_check(has_gold, "Activation must spawn gold particles")

	# Đi qua lần hai -> không phát lại, không ghi đè checkpoint khác.
	GameManager.last_checkpoint = Vector2(40, 190)
	player.position = Vector2(150, 190)
	player.velocity = Vector2.ZERO
	await _frames(6)
	_check(_reached_count == 1 and _bus_count == 1, "Re-entering the flag must not trigger again")
	_check(GameManager.last_checkpoint == Vector2(40, 190), "Reached checkpoint must not overwrite a later checkpoint")

	# Nghiệm thu: chết sau khi qua cờ -> hồi sinh đúng tại cờ.
	var expected := checkpoint.global_position
	player.position = Vector2(40, 190)
	player.velocity = Vector2.ZERO
	await _frames(2)
	GameManager.last_checkpoint = expected
	player.kill_by_hazard()
	for i in range(120):
		await get_tree().physics_frame
		if player.current_state() != Player.STATE_DEAD:
			break
	await _frames(30)
	_check(GameManager.lives == 2, "Dying after the checkpoint must cost exactly one life")
	_check(player.health.is_alive() and player.current_state() != Player.STATE_DEAD, "Player must respawn alive")
	_check(player.global_position.distance_to(expected) < 1.0 and player.is_on_floor(), "Player must respawn standing at the checkpoint flag")
	print("Checkpoint checks complete: %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)