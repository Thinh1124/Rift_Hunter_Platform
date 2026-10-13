extends SceneTree
## Authoring only: Godot --headless --path . --script res://tools/build_level5.gd
## Saves static editable tiles; rerunning replaces manual edits to Level5.

const TILE: int = 16
const WIDTH: int = 64
const HEIGHT: int = 36
const LEVEL_PATH: String = "res://scenes/levels/Level5.tscn"
const SPAWN: Vector2 = Vector2(32, 544)
const EXIT: Vector2 = Vector2(976, 96)

# Rectangles in tile coordinates: x, y, width, height.
const BLOCKS: Array[Rect2i] = [
	Rect2i(0, 34, 18, 2),
	Rect2i(3, 33, 2, 1),
	Rect2i(12, 32, 6, 2),
	Rect2i(16, 30, 8, 2),
	Rect2i(20, 28, 6, 2),
	Rect2i(22, 25, 2, 1),
	Rect2i(5, 20, 5, 6),
	Rect2i(10, 20, 6, 4),
	Rect2i(16, 20, 4, 2),
	Rect2i(18, 18, 2, 2),
	Rect2i(20, 18, 6, 4),
	Rect2i(24, 14, 2, 4),
	Rect2i(26, 19, 2, 3),
	Rect2i(28, 21, 2, 1),
	Rect2i(30, 22, 6, 2),
	Rect2i(34, 24, 4, 1),
	Rect2i(38, 25, 2, 1),
	Rect2i(38, 26, 8, 4),
	Rect2i(42, 24, 4, 2),
	Rect2i(38, 34, 8, 2),
	Rect2i(44, 22, 15, 2),
	Rect2i(46, 20, 10, 2),
	Rect2i(54, 18, 4, 2),
	Rect2i(48, 16, 10, 2),
	Rect2i(46, 14, 2, 4),
	Rect2i(52, 28, 10, 2),
	Rect2i(60, 24, 2, 4),
	Rect2i(38, 12, 10, 2),
	Rect2i(42, 10, 12, 2),
	Rect2i(49, 7, 5, 3),
	Rect2i(54, 6, 10, 3),
	Rect2i(52, 12, 4, 1),
	Rect2i(28, 18, 2, 1),
	Rect2i(30, 17, 2, 1),
	Rect2i(32, 16, 2, 1),
	Rect2i(34, 15, 2, 1),
	Rect2i(36, 13, 2, 2),
]

func _initialize() -> void:
	var cells: Dictionary[Vector2i, bool] = {}
	for block: Rect2i in BLOCKS:
		for x in range(block.position.x, block.end.x):
			for y in range(block.position.y, block.end.y):
				cells[Vector2i(x, y)] = true
	var ground := TileMapLayer.new()
	ground.tile_set = load("res://assets/Terrain/level_ground_tileset.tres") as TileSet
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
	var original: String = FileAccess.get_file_as_string(LEVEL_PATH)
	var regex := RegEx.new()
	regex.compile('\\[node name="Level5"[^\\n]*\\]')
	var root: RegExMatch = regex.search(original)
	assert(root != null, "Missing Level5 inherited root")
	var data: PackedByteArray = ground.get(&"tile_map_data")
	var text: String = original.get_slice("\n", 0) + '\n\n[ext_resource type="PackedScene" path="res://scenes/levels/LevelBase.tscn" id="1_base"]\n'
	text += '[ext_resource type="PackedScene" path="res://scenes/objects/KillZone.tscn" id="2_kill"]\n\n'
	text += root.get_string() + '\nlevel_number = 5\nlimit_left = 0\nlimit_right = 1024\nlimit_top = 0\nlimit_bottom = 576\nseason = "autumn"\n\n'
	text += '[node name="Ground" parent="." index="1"]\nposition = Vector2(0, 0)\ntile_map_data = PackedByteArray("%s")\n\n' % Marshalls.raw_to_base64(data)
	text += '[node name="Decor" parent="." index="2"]\ntile_map_data = PackedByteArray()\n\n'
	text += '[node name="PlayerSpawn" parent="." index="4"]\nposition = Vector2(32, 544)\n\n'
	text += '[node name="Player" parent="." index="5"]\nposition = Vector2(32, 544)\n\n'
	text += '[node name="ExitGate" parent="." index="11"]\nposition = Vector2(976, 96)\n\n'
	text += '[node name="KillZone" parent="Objects" instance=ExtResource("2_kill")]\nposition = Vector2(512, 640)\n'
	var output := FileAccess.open(LEVEL_PATH, FileAccess.WRITE)
	assert(output != null)
	output.store_string(text)
	output.close()
	_preview(ground)
	ground.free()
	_verify(cells.size())
	quit()

func _preview(ground: TileMapLayer) -> void:
	var image := Image.create(WIDTH * TILE, HEIGHT * TILE, false, Image.FORMAT_RGBA8)
	image.fill(Color("252932"))
	var atlas := ground.tile_set.get_source(0) as TileSetAtlasSource
	var texture: Image = atlas.texture.get_image()
	for cell: Vector2i in ground.get_used_cells():
		image.blit_rect(texture, Rect2i(ground.get_cell_atlas_coords(cell) * TILE, Vector2i(TILE, TILE)), cell * TILE)
	image.fill_rect(Rect2i(Vector2i(SPAWN) - Vector2i(5, 20), Vector2i(10, 20)), Color("75e18b"))
	image.fill_rect(Rect2i(Vector2i(EXIT) - Vector2i(12, 56), Vector2i(24, 56)), Color("36bce8"))
	DirAccess.make_dir_recursive_absolute("res://docs/map_previews")
	assert(image.save_png("res://docs/map_previews/level5.png") == OK)

func _verify(expected_cells: int) -> void:
	var level := (load(LEVEL_PATH) as PackedScene).instantiate() as Node2D
	var ground := level.get_node("Ground") as TileMapLayer
	assert(ground.get_used_cells().size() == expected_cells)
	for cell: Vector2i in ground.get_used_cells():
		assert(ground.get_cell_tile_data(cell).get_collision_polygons_count(0) == 1)
	assert(ground.get_cell_source_id(ground.local_to_map(SPAWN + Vector2(0, 2))) == 0)
	assert(ground.get_cell_source_id(ground.local_to_map(EXIT + Vector2(0, 2))) == 0)
	assert(level.find_children("*", "Enemy", true, false).is_empty())
	assert(level.get_node_or_null("Objects/KillZone") != null)
	level.free()
	print("Level5: %d editable ground tiles; collision, spawn, exit and scene tree verified" % expected_cells)
