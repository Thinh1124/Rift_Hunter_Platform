extends LevelBase

var failures: int = 0
var gate_events: Array[Vector2i] = []


func _ready() -> void:
	EventBus.gates_changed.connect(func(remaining: int, total: int) -> void: gate_events.append(Vector2i(remaining, total)))
	super._ready()
	_check(player.global_position.is_equal_approx(player_spawn.global_position), "Inherited spawn must position Player in _ready")
	_check(GameManager.current_level == 3, "Level number must initialize GameManager")
	_check(GameManager.last_checkpoint == player_spawn.global_position, "Checkpoint must use inherited spawn")
	_check(GameManager.remaining_gates == 1 and GameManager.total_gates == 1, "Register gates must exclude boss gate")
	_check(gate_events == [Vector2i(1, 1)], "Level ready must emit gates_changed once")
	_check(AudioManager._music_active.stream == music, "Level must play exported music")
	# HUD đọc state ban đầu từ GameManager: cổng phải hiện đúng, điểm phải 0.
	_check($HUD.gates_label.text == "Gates 1/1", "HUD must initialize gates from GameManager")
	_check($HUD.score_label.text == "000000", "HUD must initialize score")
	# HUD chỉ chiếm dải trên -> không được lấn vùng nút cảm ứng hai góc dưới.
	# Lấy "Rows" (nơi thực sự có nội dung), KHÔNG lấy SafeArea vì SafeArea
	# full-rect nên rect của nó là cả màn hình, so sẽ luôn fail.
	var hud_rect: Rect2 = ($HUD.get_node(^"SafeArea/Rows") as Control).get_global_rect()
	var bottom := get_viewport_rect().size.y
	_check(hud_rect.size.y < bottom * 0.35, "HUD must stay in the top strip, clear of touch controls")
	var touch: Node = get_node_or_null(^"TouchControls")
	if touch != null:
		for action: StringName in [&"move_left", &"move_right", &"jump", &"attack", &"interact"]:
			var center: Vector2 = touch.call(&"button_center", action)
			_check(not hud_rect.has_point(center), "HUD must not cover the %s touch button" % action)
	_check($ParallaxBackground.get_child_count() == 3, "Background must contain three layers")
	_check(not decor.collision_enabled and decor.tile_set.get_physics_layers_count() == 0, "Decor must have no collisions")
	_check(ground.tile_set.get_physics_layer_collision_layer(0) == 1, "Ground must collide on world layer 1")
	_check(player.camera.limit_left == 64 and player.camera.limit_right == 1344 and player.camera.limit_top == 32 and player.camera.limit_bottom == 752, "Camera must receive all four limits")
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
	await _frames(60)
	_check(player.is_on_floor() and absf(player.global_position.y - 320.0) < 1.0, "Player must stand on sample TileMap floor")
	EventBus.score_changed.emit(123)
	EventBus.lives_changed.emit(2)
	EventBus.player_hp_changed.emit(2, 3)
	# Điểm đếm tăng dần (0.3s) -> phải chờ tween chạy xong mới so.
	await _frames(30)
	_check($HUD.score_label.text == "000123", "HUD score must roll to 000123")
	# Lives KHÔNG còn hiển thị trên HUD (máu đã dùng hình tim), nên chỉ kiểm
	# phần còn lại: điểm + mảnh Rift.
	_check($HUD.shard_label.text == "0/%d" % GameManager.SHARDS_REQUIRED, "HUD phải hiện 0/5 mảnh Rift")
	player.respawn()
	_check(player.global_position == player_spawn.global_position, "Respawn must return to level checkpoint")
	# Exercise the dedicated one-way tile with a body rising from beneath it.
	ground.set_cell(Vector2i(30, 15), 1, Vector2i(1, 1))
	var tile := (ground.tile_set.get_source(1) as TileSetAtlasSource).get_tile_data(Vector2i(1, 1), 0)
	_check(tile.is_collision_polygon_one_way(0, 0), "Platform tile must be marked one-way")
	var probe := CharacterBody2D.new()
	probe.collision_layer = 2
	probe.collision_mask = 1
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(6, 8)
	shape.shape = rectangle
	probe.add_child(shape)
	probe.position = Vector2(488, 258)
	add_child(probe)
	await _frames(3)
	probe.velocity.y = -160
	var elapsed := 0.0
	var went_above := false
	while elapsed < 0.7:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		probe.velocity.y += 450 * get_physics_process_delta_time()
		probe.move_and_slide()
		went_above = went_above or probe.position.y < 236
	_check(went_above and probe.is_on_floor() and absf(probe.position.y - 236) < 1, "One-way tile must allow upward passage and support landing")
	probe.queue_free()
	# Make smoothing settle and verify the visible viewport at every arena edge.
	player.set_physics_process(false)
	player.state_machine.set_physics_process(false)
	for corner in [Vector2(-500, -500), Vector2(2000, -500), Vector2(-500, 1400), Vector2(2000, 1400)]:
		player.global_position = corner
		player.camera.reset_smoothing()
		player.camera.force_update_scroll()
		await _frames(3)
		var half_view := get_viewport_rect().size / player.camera.zoom * 0.5
		var center := player.camera.get_screen_center_position()
		_check(center.x - half_view.x >= limit_left - 0.1 and center.x + half_view.x <= limit_right + 0.1, "Camera viewport must respect horizontal limits")
		_check(center.y - half_view.y >= limit_top - 0.1 and center.y + half_view.y <= limit_bottom + 0.1, "Camera viewport must respect vertical limits")
	print("LevelBase checks complete: %d failures" % failures)
	AudioManager.stop_music()
	get_tree().quit(0 if failures == 0 else 1)
