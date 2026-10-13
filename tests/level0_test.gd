extends Node
## Nghiệm thu ải hướng dẫn Level0:
##   1. Cây node đầy đủ trong .tscn (không dựng bằng code lúc chạy)
##   2. Mặt đất + bậc thang một chiều có va chạm
##   3. 2 NPC hướng dẫn dùng đúng thoại trong data/dialogues.json
##   4. Checkpoint hoạt động (chạm -> lưu vị trí hồi sinh)
##   5. Cổng ra mở (ải không có MonsterGate) và chạm -> level_completed
##   6. Player spawn nằm trên mặt đất

var level: Node2D
var checks: int = 0
var fails: int = 0

var _completed: bool = false

## Test chạm cổng ra -> EventBus.level_completed -> GameManager ghi sao/mở ải
## vào save thật. Phải sao lưu rồi trả lại, giống settings_test.gd.
const SAVE_PATH: String = "user://save.json"
var _save_backup: PackedByteArray = PackedByteArray()
var _had_save: bool = false


func _ready() -> void:
	_backup_save()
	level = $Level0
	await get_tree().process_frame
	await get_tree().physics_frame

	print("=== LEVEL0 TEST ===")
	_test_node_tree()
	await _test_ground_and_spawn()
	_test_dialogues()
	await _test_checkpoint()
	await _test_exit_gate()

	print("--- ket qua ---")
	print("PASS" if fails == 0 else "FAIL (%d/%d)" % [fails, checks])
	print("=== LEVEL0 TEST DONE ===")
	_restore_save()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()


# --- save an toan ---------------------------------------------------------

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


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _nodes() -> Node2D:
	return level.get_node(^"Objects") as Node2D


func _test_node_tree() -> void:
	print("--- 1. cay node ---")
	var names: Array[String] = []
	for child in _nodes().get_children():
		names.append(String(child.name))
	print("Objects chứa: ", names)
	for expected: String in ["NpcMove", "NpcEnemy", "Grunt", "Checkpoint", "ExitGate"]:
		_check("có node '%s'" % expected, _nodes().has_node(expected))

	# Đúng nhóm mà gameplay dựa vào.
	_check("Grunt vào group enemy", _nodes().get_node("Grunt").is_in_group(&"enemy"))
	_check("Checkpoint vào group checkpoint",
		_nodes().get_node("Checkpoint").is_in_group(&"checkpoint"))
	_check("NpcMove vào group npc", _nodes().get_node("NpcMove").is_in_group(&"npc"))
	_check("NpcEnemy vào group npc", _nodes().get_node("NpcEnemy").is_in_group(&"npc"))

	# Ải hướng dẫn không có MonsterGate -> cổng ra phải mở ngay.
	_check("không có MonsterGate trong ải hướng dẫn",
		get_tree().get_nodes_in_group(&"gate").is_empty())


func _test_ground_and_spawn() -> void:
	print("--- 2. dat va spawn ---")
	var ground: TileMapLayer = level.get_node(^"Ground") as TileMapLayer
	var tiles: int = ground.get_used_cells().size()
	print("so o dat = ", tiles)
	_check("có mặt đất", tiles > 100, str(tiles))

	# Ô ngay dưới chân PlayerSpawn phải rỗng, ô đó phải là đất.
	var spawn: Marker2D = level.get_node(^"PlayerSpawn") as Marker2D
	var spawn_cell: Vector2i = spawn.global_position / 16.0
	_check("PlayerSpawn nằm trên ô đất",
		ground.get_cell_source_id(spawn_cell) != -1, str(spawn_cell))

	var player: Node2D = level.get_node(^"Player") as Node2D
	_check("Player đặt đúng chỗ PlayerSpawn",
		player.global_position.distance_to(spawn.global_position) < 1.0,
		"%s vs %s" % [player.global_position, spawn.global_position])

	# Bậc thang một chiều: source 1.
	var platform_cells: int = 0
	for cell: Vector2i in ground.get_used_cells():
		if ground.get_cell_source_id(cell) == 1:
			platform_cells += 1
	print("so o bay thang = ", platform_cells)
	_check("có bậc thang một chiều để học nhảy", platform_cells >= 6, str(platform_cells))


func _test_dialogues() -> void:
	print("--- 3. thoai NPC huong dan ---")
	for pair: Array in [["NpcMove", "npc_move"], ["NpcEnemy", "npc_enemy"]]:
		var npc := _nodes().get_node(String(pair[0])) as NPC
		var dialogue_id: String = npc.dialogue_id
		_check("%s dùng dialogue_id '%s'" % [pair[0], pair[1]], dialogue_id == String(pair[1]),
			dialogue_id)
		var lines: PackedStringArray = DialogueDB.lines(dialogue_id, "default")
		print("%-9s dialogue_id=%-10s so cau=%d" % [pair[0], dialogue_id, lines.size()])
		_check("%s có câu thoại 'default'" % pair[0], lines.size() >= 1, str(lines.size()))
		for line: String in lines:
			print("      > %s" % line)


func _test_checkpoint() -> void:
	print("--- 4. checkpoint ---")
	var checkpoint: Checkpoint = _nodes().get_node("Checkpoint") as Checkpoint
	var player: Player = level.get_node(^"Player") as Player
	GameManager.last_checkpoint = Vector2.ZERO
	var before: Vector2 = GameManager.last_checkpoint

	player.global_position = checkpoint.global_position + Vector2(0, -24)
	await _frames(6)
	print("checkpoint da chạm = ", checkpoint.is_reached(),
		" last_checkpoint=", GameManager.last_checkpoint)
	_check("checkpoint kích hoạt khi chạm", checkpoint.is_reached())
	_check("checkpoint lưu vị trí hồi sinh",
		GameManager.last_checkpoint != before and GameManager.last_checkpoint != Vector2.ZERO,
		str(GameManager.last_checkpoint))

	# Xác nhận đúng chỗ checkpoint, không phải vị trí rơi.
	_check("vị trí hồi sinh gần checkpoint",
		GameManager.last_checkpoint.distance_to(checkpoint.global_position) < 64.0,
		str(GameManager.last_checkpoint))


func _test_exit_gate() -> void:
	print("--- 5. qua cong ---")
	var exit_gate: ExitGate = _nodes().get_node("ExitGate") as ExitGate
	# Cổng cần chạy hết animation "opening" mới sang OPEN (co fallback 2 giây).
	await _frames(150)
	print("trang thai cong = %s (0=LOCKED 1=OPENING 2=OPEN)" % exit_gate.state)
	_check("cổng ra tự mở khi ải không có cổng quái",
		exit_gate.state == ExitGate.ExitState.OPEN, str(exit_gate.state))

	var player: Player = level.get_node(^"Player") as Player
	EventBus.level_completed.connect(func() -> void: _completed = true)
	player.global_position = exit_gate.global_position
	await _frames(8)
	print("level_completed = ", _completed)
	_check("chạm cổng ra -> hoàn thành ải", _completed)


func _check(label: String, ok: bool, detail: String = "") -> void:
	checks += 1
	if ok:
		print("   PASS  ", label)
	else:
		fails += 1
		print("   FAIL  ", label, "  ", detail)