extends SceneTree
## Authoring helper: dựng res://scenes/levels/Level0.tscn (ải hướng dẫn, map nhỏ).
##
## Chạy: godot --headless --script res://tests/build_level0.gd
##
## Dùng tool này vì tile data của TileMapLayer lưu dạng PackedByteArray - không
## gõ tay trong .tscn được. Scene vẫn lưu ra .tscn bình thường nên cây node
## hiện đầy đủ trong Scene dock, sửa tay sau đó thoải mái.

const LEVEL_PATH: String = "res://scenes/levels/Level0.tscn"

## Bản đồ: 44 x 23 ô (16px) = 704 x 368 px. Cao hơn viewport 360 để camera
## không lộ nền đen.
const MAP_W: int = 44
const MAP_H: int = 23
const TILE: int = 16
## Hàng mặt đất (ô trên cùng của lớp đất).
const GROUND_ROW: int = 18

## Ô đất trong world_tileset.png: 0 = mặt trên, 1 = lớp dưới.
const SOIL_TOP: Vector2i = Vector2i(0, 0)
const SOIL_FILL: Vector2i = Vector2i(0, 1)
## Bậc thang một chiều trong platforms.png.
const PLATFORM: Vector2i = Vector2i(0, 1)

const P_SPAWN: Vector2 = Vector2(32, 288)
const P_NPC_MOVE: Vector2 = Vector2(88, 288)
const P_NPC_ENEMY: Vector2 = Vector2(232, 288)
const P_ENEMY: Vector2 = Vector2(304, 288)
const P_CHECKPOINT: Vector2 = Vector2(400, 288)
const P_EXIT: Vector2 = Vector2(608, 288)


func _initialize() -> void:
	var level: Node2D = load("res://scenes/levels/LevelBase.tscn").instantiate() as Node2D
	level.name = "Level0"

	# LevelBase để sẵn tên level_number = 1; đổi thành 0 và chỉnh camera.
	level.set(&"level_number", 0)
	level.set(&"limit_left", 0)
	level.set(&"limit_right", MAP_W * TILE)
	level.set(&"limit_top", 0)
	level.set(&"limit_bottom", MAP_H * TILE)
	level.set(&"season", "spring")

	_build_ground(level)
	_build_decor(level)
	_build_objects(level)

	var packed := PackedScene.new()
	var err: int = packed.pack(level)
	assert(err == OK, "Cannot pack Level0")
	err = ResourceSaver.save(packed, LEVEL_PATH)
	assert(err == OK, "Cannot save Level0")

	# PackedScene.pack() BỎ QUA node chưa có owner -> kiểm tra lại sau khi
	# pack để không bao giờ lưu ra scene thiếu object.
	var probe: Node = packed.instantiate()
	var objects: Node2D = probe.get_node("Objects") as Node2D
	for expected: String in ["NpcMove", "NpcEnemy", "Grunt", "Checkpoint", "ExitGate"]:
		assert(objects.has_node(expected), "Level0.tscn thiếu node '%s'." % expected)
	probe.free()
	level.free()
	print("Level0 generated: %d x %d tiles" % [MAP_W, MAP_H])
	quit()


func _build_ground(level: Node2D) -> void:
	var ground: TileMapLayer = level.get_node("Ground") as TileMapLayer
	# LevelBase mang sẵn mẫu sàn -> xoá hết trước khi dựng map mới.
	ground.clear()
	for x in MAP_W:
		ground.set_cell(Vector2i(x, GROUND_ROW), 0, SOIL_TOP)
		for y in range(GROUND_ROW + 1, MAP_H):
			ground.set_cell(Vector2i(x, y), 0, SOIL_FILL)
	# Bậc thang một chiều để học nhảy lên cao.
	for x in range(10, 14):
		ground.set_cell(Vector2i(x, 14), 1, PLATFORM)
	for x in range(17, 21):
		ground.set_cell(Vector2i(x, 11), 1, PLATFORM)


func _build_decor(level: Node2D) -> void:
	var decor: TileMapLayer = level.get_node("Decor") as TileMapLayer
	decor.clear()
	# Cây và bụi đứng trên mặt đất, ô (1,6)/(3,6)/(5,6) là hàng cây trong atlas.
	for x: int in [4, 20, 28, 36]:
		decor.set_cell(Vector2i(x, GROUND_ROW - 1), 0, Vector2i(1, 6))
	# Bụi cỏ thấp ở sát mặt đất.
	for x: int in [7, 15, 24, 32, 40]:
		decor.set_cell(Vector2i(x, GROUND_ROW - 1), 0, Vector2i(3, 6))


func _build_objects(level: Node2D) -> void:
	var objects: Node2D = level.get_node("Objects") as Node2D
	# Node2D không có clear() như TileMapLayer -> xoá từng con.
	for child in objects.get_children():
		objects.remove_child(child)
		child.free()
	var spawn: Marker2D = level.get_node("PlayerSpawn") as Marker2D
	spawn.position = P_SPAWN

	_add(objects, "res://scenes/objects/NPC.tscn", "NpcMove", P_NPC_MOVE,
		{"dialogue_id": "npc_move"}, level)
	_add(objects, "res://scenes/objects/NPC.tscn", "NpcEnemy", P_NPC_ENEMY,
		{"dialogue_id": "npc_enemy"}, level)
	_add(objects, "res://scenes/enemies/SummonedPatrolEnemy.tscn", "Grunt", P_ENEMY, {}, level)
	_add(objects, "res://scenes/objects/Checkpoint.tscn", "Checkpoint", P_CHECKPOINT, {}, level)
	_add(objects, "res://scenes/objects/ExitGate.tscn", "ExitGate", P_EXIT, {}, level)

	# Chặn lỗi âm thầm: thiếu object thì assert trước khi pack, không lưu
	# một scene nửa vời rồi mới phát hiện.
	for expected: String in ["NpcMove", "NpcEnemy", "Grunt", "Checkpoint", "ExitGate"]:
		assert(objects.has_node(expected), "Objects thiếu node '%s'." % expected)
		assert(objects.get_node(expected).owner == level,
			"Node '%s' chưa set owner -> pack() sẽ bỏ qua." % expected)


func _add(parent: Node, scene_path: String, node_name: String, pos: Vector2,
		props: Dictionary, owner_root: Node) -> Node:
	var node: Node = load(scene_path).instantiate()
	node.name = node_name
	node.position = pos
	for key: String in props:
		node.set(key, props[key])
	parent.add_child(node)
	# BẮT BUỘC: không có owner thì PackedScene.pack() loại bỏ node này.
	node.owner = owner_root
	return node