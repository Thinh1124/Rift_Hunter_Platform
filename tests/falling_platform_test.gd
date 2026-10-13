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


func _wait_state(platform: FallingPlatform, wanted: FallingPlatform.PlatformState, max_frames: int) -> void:
	for i in max_frames:
		await get_tree().physics_frame
		if platform.state == wanted:
			break
	await get_tree().process_frame
	_check(platform.state == wanted, "Platform must reach state %d" % wanted)


func _run() -> void:
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(50, 205)
	var floor_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(80, 20)
	floor_shape.shape = rectangle
	floor_body.add_child(floor_shape)
	add_child(floor_body)
	var zone := preload("res://scenes/objects/KillZone.tscn").instantiate() as KillZone
	zone.position = Vector2(200, 470)
	(zone.get_node("CollisionShape2D").shape as RectangleShape2D).size = Vector2(200, 60)
	add_child(zone)
	var platform := preload("res://scenes/objects/FallingPlatform.tscn").instantiate() as FallingPlatform
	platform.position = Vector2(200, 200)
	add_child(platform)
	var origin := platform.global_transform
	_check(platform.collision_layer == 1 and platform.collision_shape.one_way_collision, "Platform must be layer 1 and one-way")
	_check(platform.trigger.collision_mask == 2 and platform.trigger.position.y < -5, "Trigger must watch Player above platform")
	GameManager.lives = 3
	GameManager.last_checkpoint = Vector2(50, 195)
	var player := preload("res://scenes/player/Player.tscn").instantiate() as Player
	player.position = Vector2(200, 230)
	add_child(player)
	player.camera.enabled = false
	var camera := Camera2D.new()
	camera.position = Vector2(200, 300)
	add_child(camera)
	camera.make_current()
	player.velocity.y = -320
	await _frames(6)
	_check(platform.state == FallingPlatform.PlatformState.IDLE and player.velocity.y < 0, "Jumping through from underneath must not trigger collapse")
	await _wait_state(platform, FallingPlatform.PlatformState.SHAKING, 90)
	_check(platform.global_transform == origin and player.is_on_floor(), "Landing on platform must start shaking")
	await _frames(14)
	_check(platform.state == FallingPlatform.PlatformState.SHAKING and platform.global_transform == origin, "Platform must remain solid during 0.5-second delay")
	await _wait_state(platform, FallingPlatform.PlatformState.FALLING, 30)
	var has_debris := false
	for child in get_children():
		has_debris = has_debris or child is DustFX
	_check(has_debris, "Starting fall must emit debris")
	await _frames(24)
	print("Rider diagnostic: player_y=", player.global_position.y, " platform_y=", platform.global_position.y, " on_floor=", player.is_on_floor(), " platform_velocity=", player.get_platform_velocity())
	_check(platform.global_position.y > origin.origin.y + 35, "Platform must accelerate downward")
	_check(absf(player.global_position.y - (platform.global_position.y - 5)) < 3.0, "Player must remain carried on the falling platform")
	_check(platform._fall_speed > 200, "Fall gravity must increase platform speed")
	await _wait_state(platform, FallingPlatform.PlatformState.HIDDEN, 120)
	_check(platform._touches_kill_zone(), "Platform must hide on KillZone contact before going offscreen")
	_check(not platform.visible and platform.collision_shape.disabled, "Hidden platform must disable collision")
	await _frames(120)
	_check(platform.state == FallingPlatform.PlatformState.HIDDEN, "Respawn must wait 3 seconds")
	_check(GameManager.lives == 2 and player.health.is_alive(), "Rider entering KillZone must lose one life and respawn")
	_check(player.global_position.distance_to(GameManager.last_checkpoint) < 1, "Rider must return to checkpoint")
	await _frames(50)
	_check(platform.state == FallingPlatform.PlatformState.HIDDEN, "Platform must not return before respawn_time")
	await _frames(15)
	_check(platform.state == FallingPlatform.PlatformState.RESPAWNING and platform.visible, "Platform must fade in after 3 seconds")
	_check(platform.global_transform == origin, "Respawn must restore exact original transform")
	_check(platform.sprite.modulate.a > 0 and platform.sprite.modulate.a < 1, "Respawn must animate opacity")
	await _frames(20)
	_check(platform.state == FallingPlatform.PlatformState.IDLE and not platform.collision_shape.disabled and platform.trigger.monitoring, "Platform must restore collision and trigger after fade")
	_check(is_equal_approx(platform.sprite.modulate.a, 1), "Fade must restore full opacity")
	player.global_position = Vector2(200, 195)
	player.velocity = Vector2.ZERO
	await _wait_state(platform, FallingPlatform.PlatformState.SHAKING, 15)
	# An offscreen fall must also hide without requiring a KillZone.
	var offscreen := preload("res://scenes/objects/FallingPlatform.tscn").instantiate() as FallingPlatform
	offscreen.position = Vector2(400, 200)
	add_child(offscreen)
	offscreen._start_falling()
	await _wait_state(offscreen, FallingPlatform.PlatformState.HIDDEN, 120)
	_check(not offscreen._touches_kill_zone() and offscreen._outside_viewport(), "Offscreen platform must hide even without KillZone")
	print("FallingPlatform checks complete: %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)

