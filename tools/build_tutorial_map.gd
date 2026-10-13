extends SceneTree
## Authoring only; replaces Level0 geometry to match the tutorial reference.
const PATH: String = "res://scenes/levels/Level0.tscn"
const TILE: int = 16
const BLOCKS: Array[Rect2i] = [
	Rect2i(2, 23, 19, 2),
	Rect2i(13, 21, 2, 2),
	Rect2i(15, 19, 4, 4),
	Rect2i(25, 23, 2, 2),
	Rect2i(27, 21, 2, 4),
	Rect2i(29, 19, 2, 6),
	Rect2i(31, 17, 2, 8),
	Rect2i(33, 15, 2, 10),
	Rect2i(35, 21, 3, 4),
	Rect2i(42, 21, 20, 4),
	Rect2i(58, 19, 4, 2),
]

func _initialize() -> void:
	call_deferred(&"_build")

func _build() -> void:
	var level := (load(PATH) as PackedScene).instantiate() as Node2D
	level.set(&"limit_right", 1024)
	level.set(&"limit_bottom", 576)
	(level.get_node("PlayerSpawn") as Node2D).position = Vector2(64, 368)
	(level.get_node("Player") as Node2D).position = Vector2(64, 368)
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
		var ax: int = 1
		if not cells.has(cell + Vector2i.LEFT):
			ax = 0
		elif not cells.has(cell + Vector2i.RIGHT):
			ax = 2
		var ay: int = 1
		if not cells.has(cell + Vector2i.UP):
			ay = 0
		elif not cells.has(cell + Vector2i.DOWN):
			ay = 2
		ground.set_cell(cell, 0, Vector2i(ax, ay))
	# A one-way connector lets players jump through from underneath.
	for x in range(38, 42):
		ground.set_cell(Vector2i(x, 21), 1, Vector2i(0 if x == 38 else (2 if x == 41 else 1), 1))
	var objects := level.get_node("Objects") as Node2D
	(objects.get_node("NpcMove") as Node2D).position = Vector2(128, 368)
	(objects.get_node("NpcEnemy") as Node2D).position = Vector2(736, 336)
	var grunt := objects.get_node("Grunt") as Node2D
	grunt.position = Vector2(816, 328)
	grunt.set(&"drops_shards", true)
	grunt.set(&"shard_drop", 5)
	(objects.get_node("Checkpoint") as Node2D).position = Vector2(704, 336)
	(objects.get_node("ExitGate") as Node2D).position = Vector2(976, 304)
	var kill := (load("res://scenes/objects/KillZone.tscn") as PackedScene).instantiate() as Node2D
	kill.name = "KillZone"
	kill.position = Vector2(512, 624)
	objects.add_child(kill)
	kill.owner = level
	var packed := PackedScene.new()
	assert(packed.pack(level) == OK)
	assert(ResourceSaver.save(packed, PATH) == OK)
	var text: String = FileAccess.get_file_as_string(PATH)
	text = text.replace("[gd_scene format=4]", '[gd_scene format=4 uid="uid://4cfd666xsq0b"]')
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	_preview(ground)
	level.free()
	print("Level0 rebuilt: tutorial steps, gap, one-way connector, one enemy dropping five shards, Blue background")
	quit()

func _preview(ground: TileMapLayer) -> void:
	var image := Image.create(1024, 576, false, Image.FORMAT_RGBA8)
	image.fill(Color("252932"))
	for cell: Vector2i in ground.get_used_cells():
		var atlas := ground.tile_set.get_source(ground.get_cell_source_id(cell)) as TileSetAtlasSource
		image.blit_rect(atlas.texture.get_image(), Rect2i(ground.get_cell_atlas_coords(cell) * TILE, Vector2i(TILE, TILE)), cell * TILE)
	image.fill_rect(Rect2i(59, 348, 10, 20), Color("75e18b"))
	image.fill_rect(Rect2i(808, 320, 16, 16), Color("dc323b"))
	image.fill_rect(Rect2i(964, 248, 24, 56), Color("36bce8"))
	assert(image.save_png("res://docs/map_previews/level0.png") == OK)
