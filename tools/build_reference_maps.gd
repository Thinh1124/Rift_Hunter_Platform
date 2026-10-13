extends SceneTree
## Run: Godot --headless --path . --script res://tools/build_reference_maps.gd
## Authoring only: saves editable tiles to the four inherited level scenes.

const TILE: int = 16
const CELL: int = 32
const WIDTH: int = 30
const HEIGHT: int = 16
const ORIGIN: Vector2i = Vector2i(0, 2)
const MAP_PATH: String = "res://scenes/levels/Level%d.tscn"


func _initialize() -> void:
	for number in range(1, 5):
		_build(number)
	quit()


func _rectangle(cells: Dictionary[Vector2i, bool], x: int, y: int, w: int, h: int = 1) -> void:
	for column in range(x, x + w):
		for row in range(y, y + h):
			cells[Vector2i(column, row)] = true


func _layout(number: int) -> Dictionary[Vector2i, bool]:
	var cells: Dictionary[Vector2i, bool] = {}
	match number:
		1:
			for x in range(7):
				var top: int = 12 - maxi(x - 1, 0)
				_rectangle(cells, x, top, 1, 13 - top)
			_rectangle(cells, 7, 7, 3)
			_rectangle(cells, 12, 7, 2)
			_rectangle(cells, 16, 7, 6)
			for x in range(22, WIDTH):
				var top: int = 7 - (x - 21) / 2
				_rectangle(cells, x, top, 1, 8 - top)
		2:
			_rectangle(cells, 0, 7, 6)
			_rectangle(cells, 0, 8, 1, 5)
			_rectangle(cells, 0, 12, 22)
			_rectangle(cells, 10, 7, 12)
			_rectangle(cells, 10, 8, 1, 2)
			_rectangle(cells, 12, 8, 1)
			_rectangle(cells, 14, 8, 1)
			_rectangle(cells, 21, 3, 1, 9)
			_rectangle(cells, 21, 3, 9)
			for cell: Vector2i in [Vector2i(7, 5), Vector2i(9, 4), Vector2i(11, 4), Vector2i(13, 3), Vector2i(15, 2), Vector2i(17, 2), Vector2i(19, 1)]:
				cells[cell] = true
		3:
			_rectangle(cells, 0, 5, 6, 2)
			_rectangle(cells, 6, 8, 2)
			_rectangle(cells, 8, 9, 2)
			_rectangle(cells, 10, 11, 11)
			_rectangle(cells, 16, 7, 4)
			for x in range(20, 27):
				_rectangle(cells, x, 30 - x, 1)
			_rectangle(cells, 27, 3, 3, 2)
		4:
			_rectangle(cells, 0, 9, 5)
			_rectangle(cells, 6, 13, 2)
			_rectangle(cells, 8, 9, 2)
			_rectangle(cells, 10, 13, 3)
			_rectangle(cells, 11, 8, 2)
			_rectangle(cells, 15, 13, 2)
			_rectangle(cells, 16, 9, 1, 5)
			_rectangle(cells, 21, 9, 9)
			_rectangle(cells, 17, 6, 3)
			_rectangle(cells, 21, 5, 1)
			_rectangle(cells, 23, 3, 1)
			_rectangle(cells, 25, 2, 5)
	return cells


func _build(number: int) -> void:
	var layout: Dictionary[Vector2i, bool] = _layout(number)
	var occupied: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in layout:
		for dx in 2:
			for dy in 2:
				occupied[cell * 2 + Vector2i(dx, dy) + ORIGIN] = true
	var ground := TileMapLayer.new()
	ground.tile_set = load("res://assets/Terrain/level_ground_tileset.tres") as TileSet
	for cell: Vector2i in occupied:
		var atlas_x: int = 1
		if not occupied.has(cell + Vector2i.LEFT):
			atlas_x = 0
		elif not occupied.has(cell + Vector2i.RIGHT):
			atlas_x = 2
		var atlas_y: int = 1
		if not occupied.has(cell + Vector2i.UP):
			atlas_y = 0
		elif not occupied.has(cell + Vector2i.DOWN):
			atlas_y = 2
		ground.set_cell(cell, 0, Vector2i(atlas_x, atlas_y))
	var data: PackedByteArray = ground.get(&"tile_map_data")
	var path: String = MAP_PATH % number
	var original: String = FileAccess.get_file_as_string(path)
	var header: String = original.get_slice("\n", 0)
	var root_pattern := RegEx.new()
	root_pattern.compile('\\[node name="Level%d"[^\\n]*\\]' % number)
	var root_match: RegExMatch = root_pattern.search(original)
	assert(root_match != null, "Missing inherited level root: " + path)
	var root_header: String = root_match.get_string()
	var start_row: int = [12, 7, 5, 9][number - 1]
	var exit_row: int = [3, 3, 3, 2][number - 1]
	var spawn: Vector2 = Vector2(CELL * 0.5, start_row * CELL + ORIGIN.y * TILE - 18)
	var exit_position: Vector2 = Vector2((WIDTH - 1) * CELL + CELL * 0.5, exit_row * CELL + ORIGIN.y * TILE)
	var content: String = header + '\n\n[ext_resource type="PackedScene" path="res://scenes/levels/LevelBase.tscn" id="1_base"]\n'
	content += '[ext_resource type="PackedScene" path="res://scenes/objects/KillZone.tscn" id="2_kill"]\n\n'
	content += root_header + '\nlevel_number = %d\nlimit_left = 0\nlimit_right = %d\nlimit_top = 0\nlimit_bottom = %d\n\n' % [number, WIDTH * CELL, HEIGHT * CELL + ORIGIN.y * TILE]
	content += '[node name="Ground" parent="." index="1"]\nposition = Vector2(0, 0)\ntile_map_data = PackedByteArray("%s")\n\n' % Marshalls.raw_to_base64(data)
	content += '[node name="Decor" parent="." index="2"]\ntile_map_data = PackedByteArray()\n\n'
	content += '[node name="PlayerSpawn" parent="." index="4"]\nposition = Vector2(%s, %s)\n\n' % [spawn.x, spawn.y]
	content += '[node name="Player" parent="." index="5"]\nposition = Vector2(%s, %s)\n\n' % [spawn.x, spawn.y]
	content += '[node name="ExitGate" parent="." index="11"]\nposition = Vector2(%s, %s)\n\n' % [exit_position.x, exit_position.y]
	content += '[node name="KillZone" parent="Objects" instance=ExtResource("2_kill")]\nposition = Vector2(%d, %d)\n' % [WIDTH * CELL / 2, HEIGHT * CELL + ORIGIN.y * TILE + 48]
	var output := FileAccess.open(path, FileAccess.WRITE)
	assert(output != null, "Cannot write " + path)
	output.store_string(content)
	output.close()
	_preview(number, ground, spawn, exit_position)
	print("Level%d: %d editable ground tiles, spawn=%s, exit=%s" % [number, occupied.size(), spawn, exit_position])
	ground.free()


func _preview(number: int, ground: TileMapLayer, spawn: Vector2, exit_position: Vector2) -> void:
	var image := Image.create(WIDTH * CELL, HEIGHT * CELL + ORIGIN.y * TILE, false, Image.FORMAT_RGBA8)
	image.fill(Color("252932"))
	var atlas := ground.tile_set.get_source(0) as TileSetAtlasSource
	var texture: Image = atlas.texture.get_image()
	for cell: Vector2i in ground.get_used_cells():
		var source: Vector2i = ground.get_cell_atlas_coords(cell) * TILE
		image.blit_rect(texture, Rect2i(source, Vector2i(TILE, TILE)), cell * TILE)
	image.fill_rect(Rect2i(Vector2i(spawn) - Vector2i(5, 10), Vector2i(10, 20)), Color("75e18b"))
	image.fill_rect(Rect2i(Vector2i(exit_position) - Vector2i(12, 56), Vector2i(24, 56)), Color("36bce8"))
	DirAccess.make_dir_recursive_absolute("res://docs/map_previews")
	assert(image.save_png("res://docs/map_previews/level%d.png" % number) == OK)
