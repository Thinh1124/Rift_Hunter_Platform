extends Node

const SAVE_PATH: String = "user://save.json"
var failures: int = 0
var completed_count: int = 0
var defeated_count: int = 0
var saved_bytes: PackedByteArray
var had_save: bool = false

func _ready() -> void:
	had_save = FileAccess.file_exists(SAVE_PATH)
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes(SAVE_PATH)
	call_deferred(&"_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
	await get_tree().process_frame

func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/map_previews/level6_%s.png" % name)

func _run() -> void:
	var level := preload("res://scenes/levels/Level6.tscn").instantiate() as LevelBase
	add_child(level)
	var boss := level.get_node("Objects/Boss") as Boss
	var gate := level.get_node("Objects/BigGate") as BigGate
	var hud := level.get_node("HUD") as GameHUD
	var player: Player = level.player
	player.health.invincible = true
	EventBus.level_completed.connect(func() -> void: completed_count += 1)
	EventBus.boss_defeated.connect(func() -> void: defeated_count += 1)
	await _frames(20)
	_check(GameManager.current_level == 6, "Level6 must register as the boss level")
	_check(boss.health.current == 20 and hud.boss_bar.max_value == 20, "Boss and HUD must start with twenty HP")
	_check(gate.state == MonsterGate.GateState.INACTIVE and not gate.visible, "Gate must be hidden until the boss dies")
	_check(level.get_node_or_null("ExitGate") == null, "No regular exit may bypass the boss fight")
	_check(boss.arena_left == 32 and boss.arena_right == 960, "Boss bounds must match the arena walls")
	_check((level.get_node("ScrollingBackground") as ScrollingLevelBackground).background_texture.resource_path.ends_with("Yellow.png"), "Level6 must retain its Yellow background")
	await _shot("boss")

	# Shards and interaction cannot finish the level before the boss is defeated.
	GameManager.shard_count = GameManager.SHARDS_REQUIRED
	EventBus.shards_changed.emit(GameManager.shard_count, GameManager.SHARDS_REQUIRED)
	_check(hud.gates_label.text != hud.gates_open_text, "Shard count must not announce an open boss exit")
	player.position = Vector2(912, 144)
	player.velocity = Vector2.ZERO
	await _frames(8)
	Input.action_press(&"interact")
	await _frames(200)
	Input.action_release(&"interact")
	_check(completed_count == 0 and gate.state == MonsterGate.GateState.INACTIVE, "Interaction before victory must not complete the level")

	player.position = level.player_spawn.position
	player.velocity = Vector2.ZERO
	for i in 20:
		boss.take_damage(1, player.global_position)
		if boss.health.current == 10:
			_check(boss.phase == 2, "Boss must enter phase two at ten HP")
		if boss.dead:
			break
		await _frames(30)
	_check(boss.dead and defeated_count == 1, "Boss death must publish one defeat event")
	_check(gate.visible and gate.state == MonsterGate.GateState.OPEN, "Boss defeat must activate the upper-right gate")
	_check(hud.gates_label.text == hud.gates_open_text, "HUD must announce the boss exit after victory")
	_check(completed_count == 0, "Boss defeat must wait for gate interaction")
	await _frames(95)
	_check(not is_instance_valid(boss), "Boss must disappear after its death animation")
	_check(not hud.boss_bar.visible, "Boss bar must hide after victory")

	player.position = Vector2(912, 144)
	player.velocity = Vector2.ZERO
	await _frames(8)
	Input.action_press(&"interact")
	await _frames(200)
	Input.action_release(&"interact")
	_check(gate.state == MonsterGate.GateState.CLOSED and completed_count == 1, "Holding interact must complete the boss level exactly once")
	var victory := level.get_node("LevelComplete") as CanvasLayer
	_check(victory.visible and (victory.get_node("%TitleLabel") as Label).text == "YOU WIN!", "Final victory screen must show YOU WIN")
	await _shot("victory")
	level.queue_free()
	await get_tree().process_frame
	AudioManager.stop_music()
	AudioManager.stop_sfx()
	await get_tree().create_timer(0.1).timeout
	if had_save:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		file.store_buffer(saved_bytes)
		file.close()
	elif FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	print("Level6 encounter checks complete: %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)
