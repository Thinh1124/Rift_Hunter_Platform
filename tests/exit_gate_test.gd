extends Node2D

var failures: int = 0
var _level_completed: int = 0
var _gate_closed: int = 0
var _shakes: Array[Vector2] = []

## Test làm cổng phát EventBus.level_completed -> GameManager._on_level_completed()
## gọi SaveManager.set_stars()/unlock() -> ghi đè user://save.json thật của người
## chơi. Phải sao lưu rồi trả lại (như settings_test.gd, level0_test.gd).
const SAVE_PATH: String = "user://save.json"
var _save_backup: PackedByteArray = PackedByteArray()
var _had_save: bool = false


func _ready() -> void:
	_backup_save()
	call_deferred(&"_run")


func _backup_save() -> void:
	_had_save = FileAccess.file_exists(SAVE_PATH)
	if _had_save:
		_save_backup = FileAccess.get_file_as_bytes(SAVE_PATH)


func _restore_save() -> void:
	if _had_save:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_buffer(_save_backup)
			file.close()
	elif FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
	await get_tree().process_frame


func _run() -> void:
	GameManager.shard_count = 0
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(100, 240)
	var floor_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(600, 20)
	floor_shape.shape = rectangle
	floor_body.add_child(floor_shape)
	add_child(floor_body)

	EventBus.level_completed.connect(func() -> void: _level_completed += 1)
	EventBus.gate_closed.connect(func(_id: StringName) -> void: _gate_closed += 1)
	EventBus.request_shake.connect(func(strength: float, duration: float) -> void: _shakes.append(Vector2(strength, duration)))

	# --- ExitGate bắt buộc đủ 5 shard ---------------------------------
	var gate := preload("res://scenes/objects/ExitGate.tscn").instantiate() as ExitGate
	gate.position = Vector2(200, 220)
	add_child(gate)
	await _frames(3)
	_check(gate.collision_layer == 64 and gate.collision_mask == 2, "ExitGate must use layer 7 and mask 2")
	_check(gate.state == ExitGate.ExitState.LOCKED, "ExitGate must start locked")
	_check(not gate.glow.visible, "Glow must be hidden while locked")
	_check(gate.sprite.modulate.r < 0.8, "Locked gate must look greyed out")
	_check(gate.sprite.sprite_frames.has_animation(ExitGate.ANIM_LOCKED) and gate.sprite.sprite_frames.has_animation(ExitGate.ANIM_OPENING) and gate.sprite.sprite_frames.has_animation(ExitGate.ANIM_OPEN), "ExitGate must provide locked, opening and open animations")

	GameManager.lives = 3
	GameManager.last_checkpoint = Vector2(100, 230)
	var player := preload("res://scenes/player/Player.tscn").instantiate() as Player
	player.position = Vector2(60, 230)
	add_child(player)
	player.camera.enabled = false
	var camera := Camera2D.new()
	camera.position = Vector2(200, 320)
	add_child(camera)
	camera.make_current()
	await _frames(4)

	# Còn cổng thì vẫn khóa, và chạm cũng không qua được.
	EventBus.gates_changed.emit(2, 2)
	await _frames(3)
	_check(gate.state == ExitGate.ExitState.LOCKED, "ExitGate must stay locked while gates remain")
	player.position = Vector2(200, 196)
	player.velocity = Vector2.ZERO
	await _frames(6)
	_check(_level_completed == 0, "Locked gate must not complete the level")
	_check(gate.state == ExitGate.ExitState.LOCKED, "Touching a locked gate must not open it")

	# Đóng hết cổng không mở exit; chỉ shard thứ 10 mới kích hoạt.
	EventBus.gates_changed.emit(0, 2)
	EventBus.gates_changed.emit(0, 0)
	await _frames(3)
	_check(gate.state == ExitGate.ExitState.LOCKED, "Clearing all gates or having no gates must not bypass shards")
	EventBus.shards_changed.emit(5, 5)
	await _frames(2)
	_check(gate.state == ExitGate.ExitState.LOCKED, "A signal alone must not bypass the real shard count")
	GameManager.add_shards(GameManager.SHARDS_REQUIRED - 1)
	await _frames(3)
	_check(gate.state == ExitGate.ExitState.LOCKED, "Four shards must keep the exit locked")
	_check(not gate.glow.visible and _level_completed == 0, "Four shards must not activate or complete the exit")
	GameManager.add_shards(1)
	await _frames(2)
	_check(gate.state == ExitGate.ExitState.OPENING, "The fifth shard must start the opening animation")
	_check(gate.glow.visible, "Opening gate must switch its glow on")
	_check(gate.sprite.animation == ExitGate.ANIM_OPENING, "Opening gate must play the opening animation")
	await _frames(40)
	_check(gate.state == ExitGate.ExitState.OPEN, "Gate must settle in the open state")
	_check(gate.glow.visible, "Open gate must keep its glow on")

	# Chạm -> level_completed đúng một lần.
	player.position = Vector2(200, 196)
	player.velocity = Vector2.ZERO
	await _frames(8)
	_check(_level_completed == 1, "Touching the open gate must complete the level once")
	_check(gate.is_completed(), "ExitGate must remember it completed")
	_check(_gate_closed == 0, "ExitGate must not emit gate_closed")
	player.position = Vector2(60, 230)
	player.velocity = Vector2.ZERO
	await _frames(4)
	player.position = Vector2(200, 196)
	player.velocity = Vector2.ZERO
	await _frames(8)
	_check(_level_completed == 1, "Re-entering the open gate must not complete the level again")

	# Already holding five shards when the scene enters the tree opens the gate.
	var ready_gate := preload("res://scenes/objects/ExitGate.tscn").instantiate() as ExitGate
	ready_gate.position = Vector2(400, 220)
	add_child(ready_gate)
	await _frames(3)
	_check(ready_gate.state == ExitGate.ExitState.OPENING, "A gate spawned with five shards must unlock")

	GameManager.shard_count = 0
	EventBus.shards_changed.emit(0, GameManager.SHARDS_REQUIRED)
	await _frames(2)
	_check(ready_gate.state == ExitGate.ExitState.LOCKED, "Resetting shards must deactivate an unfinished gate")
	var empty_gate := preload("res://scenes/objects/ExitGate.tscn").instantiate() as ExitGate
	empty_gate.position = Vector2(500, 220)
	add_child(empty_gate)
	await _frames(2)
	EventBus.gates_changed.emit(0, 0)
	empty_gate._unlock()
	await _frames(3)
	_check(empty_gate.state == ExitGate.ExitState.LOCKED, "An empty level must stay locked even if unlock is requested")

	# BigGate: existing boss gate behavior.
	var big := preload("res://scenes/enemies/BigGate.tscn").instantiate() as BigGate
	big.position = Vector2(200, 220)
	add_child(big)
	await _frames(3)
	_check(big.is_boss_gate, "BigGate must be flagged as a boss gate")
	_check(big.spawn_scene == null, "BigGate must not spawn enemies")
	_check(big.scale == Vector2(2, 2), "BigGate must be twice as large")
	_check(is_equal_approx(big.close_time, 3.0), "BigGate must use close_time = 3.0")
	_check(big.state == MonsterGate.GateState.INACTIVE and not big.visible, "BigGate must stay inactive and hidden before the boss dies")
	GameManager.register_gates()
	_check(GameManager.total_gates == 0, "Boss gate must not count toward the normal gate total")

	EventBus.boss_defeated.emit()
	await _frames(3)
	_check(big.state == MonsterGate.GateState.OPEN, "boss_defeated must activate the BigGate")
	_check(big.visible, "Activated BigGate must become visible")
	await _frames(70)
	_check(big.alive_count() == 0, "BigGate must never spawn enemies")
	_check(GameManager.total_gates == 0, "Boss gate must still be excluded from the gate total")

	# Giữ interact đủ lâu -> Closed -> level_completed + nổ sáng + rung màn hình.
	big.close_time = 0.3
	player.position = big.position + Vector2(0, -24)
	player.velocity = Vector2.ZERO
	await _frames(8)
	Input.action_press(&"interact")
	await _frames(30)
	Input.action_release(&"interact")
	await _frames(4)
	_check(big.state == MonsterGate.GateState.CLOSED, "Holding interact must close the BigGate")
	_check(_level_completed == 2, "BigGate closing must complete the level")
	_check(_gate_closed == 0, "BigGate must emit level_completed instead of gate_closed")
	_check(big.burst.emitting, "BigGate must emit its light burst")
	_check(big.burst_glow.visible, "BigGate must flash its glow on close")
	_check(_shakes.size() >= 1 and _shakes[_shakes.size() - 1].x >= 5.0, "BigGate must shake the screen on close")
	print("ExitGate/BigGate checks complete: %d failures" % failures)
	_restore_save()
	AudioManager.stop_sfx()
	await get_tree().create_timer(0.1).timeout
	get_tree().quit(0 if failures == 0 else 1)
