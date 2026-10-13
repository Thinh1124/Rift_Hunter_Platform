extends SceneTree
## Authoring only. Running this replaces manual edits to Level6.tscn.

const LEVEL_PATH: String = "res://scenes/levels/Level6.tscn"
const TILE: int = 16
const WIDTH: int = 64
const HEIGHT: int = 36
const SPAWN: Vector2 = Vector2(128, 512)
const GATE: Vector2 = Vector2(912, 144)
const BLOCKS: Array[Rect2i] = [
	Rect2i(0, 0, 64, 2),
	Rect2i(0, 2, 2, 30),
	Rect2i(62, 2, 2, 30),
	Rect2i(0, 32, 64, 4),
	Rect2i(2, 23, 4, 2),
	Rect2i(58, 23, 4, 2),
	Rect2i(60, 25, 2, 7),
	Rect2i(13, 16, 8, 2),
	Rect2i(29, 13, 6, 2),
	Rect2i(43, 16, 8, 2),
	Rect2i(53, 9, 9, 2),
]

func _initialize() -> void:
	call_deferred(&"_build")

func _build() -> void:
	var level := (load("res://scenes/levels/LevelBase.tscn") as PackedScene).instantiate() as Node2D
	level.name = "Level6"
	level.set(&"level_number", 6)
	level.set(&"limit_left", 0)
	level.set(&"limit_right", WIDTH * TILE)
	level.set(&"limit_top", 0)
	level.set(&"limit_bottom", HEIGHT * TILE)
	level.set(&"season", "winter")
	(level.get_node("PlayerSpawn") as Marker2D).position = SPAWN
	(level.get_node("Player") as Node2D).position = SPAWN
	var regular_exit := level.get_node("ExitGate")
	level.remove_child(regular_exit)
	regular_exit.free()
	var background := level.get_node("ScrollingBackground") as ScrollingLevelBackground
	background.background_texture = preload("res://assets/Background/Yellow.png")
	var ground := level.get_node("Ground") as TileMapLayer
	ground.position = Vector2.ZERO
	ground.clear()
	(level.get_node("Decor") as TileMapLayer).clear()
	var cells: Dictionary[Vector2i, bool] = {}
	for block: Rect2i in BLOCKS:
		for x in range(block.position.x, block.end.x):
			for y in range(block.position.y, block.end.y):
				cells[Vector2i(x, y)] = true
	for cell: Vector2i in cells:
		var atlas_x: int = 1
		if not cells.has(cell + Vector2i.LEFT):
			atlas_x = 0
		elif not cells.has(cell + Vector2i.RIGHT):
			atlas_x = 2
		var atlas_y: int = 1
		if not cells.has(cell + Vector2i.UP):
			atlas_y = 0
		elif not cells.has(cell + Vector2i.DOWN):
			atlas_y = 2
		ground.set_cell(cell, 0, Vector2i(atlas_x, atlas_y))
	var objects := level.get_node("Objects") as Node2D
	var boss := _add(objects, "res://scenes/enemies/Boss.tscn", "Boss", Vector2(512, 462), level)
	boss.set(&"arena_left", 32.0)
	boss.set(&"arena_right", 960.0)
	_add(objects, "res://scenes/enemies/FlyingBug.tscn", "FlyingBugLeft", Vector2(240, 376), level)
	_add(objects, "res://scenes/enemies/FlyingBug.tscn", "FlyingBugRight", Vector2(752, 376), level)
	_add(objects, "res://scenes/enemies/Bomb.tscn", "Bomb", Vector2(848, 500), level)
	var gate := _add(objects, "res://scenes/enemies/BigGate.tscn", "BigGate", GATE, level)
	gate.find_child(^"Sprite", false, false).set(&"position", Vector2(0, -24))
	var packed := PackedScene.new()
	assert(packed.pack(level) == OK)
	assert(ResourceSaver.save(packed, LEVEL_PATH) == OK)
	# Persist the nested sprite offset as a native scene override.
	var text: String = FileAccess.get_file_as_string(LEVEL_PATH)
	text = text.replace("[gd_scene format=4]", '[gd_scene format=4 uid="uid://nc7ih72mk2ri"]')
	text += '\n[node name="Sprite" parent="Objects/BigGate" index="0"]\nposition = Vector2(0, -24)\n'
	var output := FileAccess.open(LEVEL_PATH, FileAccess.WRITE)
	assert(output != null)
	output.store_string(text)
	output.close()
	_preview(ground)
	level.free()
	_verify(cells.size())
	quit()

func _add(parent: Node, scene_path: String, node_name: String, at: Vector2, root: Node) -> Node2D:
	var node := (load(scene_path) as PackedScene).instantiate() as Node2D
	node.name = node_name
	node.position = at
	parent.add_child(node)
	node.owner = root
	return node

func _preview(ground: TileMapLayer) -> void:
	var image := Image.create(WIDTH * TILE, HEIGHT * TILE, false, Image.FORMAT_RGBA8)
	image.fill(Color("252932"))
	var atlas := ground.tile_set.get_source(0) as TileSetAtlasSource
	var texture: Image = atlas.texture.get_image()
	for cell: Vector2i in ground.get_used_cells():
		image.blit_rect(texture, Rect2i(ground.get_cell_atlas_coords(cell) * TILE, Vector2i(TILE, TILE)), cell * TILE)
	image.fill_rect(Rect2i(123, 492, 10, 20), Color("75e18b"))
	image.fill_rect(Rect2i(900, 88, 24, 56), Color("36bce8"))
	image.fill_rect(Rect2i(470, 412, 84, 100), Color("dc323b"))
	for at: Vector2i in [Vector2i(240, 376), Vector2i(752, 376), Vector2i(848, 500)]:
		image.fill_rect(Rect2i(at - Vector2i(12, 12), Vector2i(24, 24)), Color("dc323b"))
	DirAccess.make_dir_recursive_absolute("res://docs/map_previews")
	assert(image.save_png("res://docs/map_previews/level6.png") == OK)

func _verify(expected_cells: int) -> void:
	var level := (load(LEVEL_PATH) as PackedScene).instantiate() as Node2D
	var ground := level.get_node("Ground") as TileMapLayer
	assert(ground.get_used_cells().size() == expected_cells)
	for cell: Vector2i in ground.get_used_cells():
		assert(ground.get_cell_tile_data(cell).get_collision_polygons_count(0) == 1)
	assert(level.get_node_or_null("ExitGate") == null)
	assert(level.get_node("Objects/Boss").get_script().get_global_name() == &"Boss")
	assert(level.get_node("Objects/BigGate").get_script().get_global_name() == &"BigGate")
	assert((level.get_node("Objects/BigGate/Sprite") as Node2D).position == Vector2(0, -24))
	assert(ground.get_cell_source_id(ground.local_to_map(SPAWN + Vector2(0, 2))) == 0)
	assert(ground.get_cell_source_id(ground.local_to_map(GATE + Vector2(0, 2))) == 0)
	assert((level.get_node("ScrollingBackground") as ScrollingLevelBackground).background_texture.resource_path == "res://assets/Background/Yellow.png")
	level.free()
	print("Level6 verified: %d ground tiles, boss arena, enemies, spawn, post-boss gate, Yellow background" % expected_cells)
