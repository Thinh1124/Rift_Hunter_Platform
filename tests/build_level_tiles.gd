extends SceneTree
## Authoring helper: materialize editable TileSet resources and template cells.

func _initialize() -> void:
	var terrain := load("res://assets/Terrain/world_tileset.png") as Texture2D
	var platforms := load("res://assets/Terrain/platforms.png") as Texture2D
	var ground := TileSet.new()
	ground.tile_size = Vector2i(16, 16)
	ground.add_physics_layer()
	ground.set_physics_layer_collision_layer(0, 1)
	ground.set_physics_layer_collision_mask(0, 0)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = terrain
	atlas.texture_region_size = Vector2i(16, 16)
	ground.add_source(atlas, 0)
	for x in range(3):
		for y in range(3):
			var cell := Vector2i(x, y)
			atlas.create_tile(cell)
			var tile := atlas.get_tile_data(cell, 0)
			tile.set_collision_polygons_count(0, 1)
			tile.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]))
	var platform_atlas := TileSetAtlasSource.new()
	platform_atlas.texture = platforms
	platform_atlas.texture_region_size = Vector2i(16, 16)
	ground.add_source(platform_atlas, 1)
	for x in range(3):
		var cell := Vector2i(x, 1)
		platform_atlas.create_tile(cell)
		var tile := platform_atlas.get_tile_data(cell, 0)
		tile.set_collision_polygons_count(0, 1)
		tile.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, -1), Vector2(-8, -1)]))
		tile.set_collision_polygon_one_way(0, 0, true)
		tile.set_collision_polygon_one_way_margin(0, 0, 1.0)
	var decor := TileSet.new()
	decor.tile_size = Vector2i(16, 16)
	var decor_atlas := TileSetAtlasSource.new()
	decor_atlas.texture = terrain
	decor_atlas.texture_region_size = Vector2i(16, 16)
	decor.add_source(decor_atlas, 0)
	for x in range(terrain.get_width() / 16):
		for y in range(terrain.get_height() / 16):
			decor_atlas.create_tile(Vector2i(x, y))
	var result := ResourceSaver.save(ground, "res://assets/Terrain/level_ground_tileset.tres", ResourceSaver.FLAG_CHANGE_PATH)
	assert(result == OK, "Cannot save ground TileSet")
	result = ResourceSaver.save(decor, "res://assets/Terrain/level_decor_tileset.tres", ResourceSaver.FLAG_CHANGE_PATH)
	assert(result == OK, "Cannot save decor TileSet")
	ground.take_over_path("res://assets/Terrain/level_ground_tileset.tres")
	decor.take_over_path("res://assets/Terrain/level_decor_tileset.tres")
	var level := load("res://scenes/levels/LevelBase.tscn").instantiate() as Node2D
	var floor_layer := level.get_node("Ground") as TileMapLayer
	floor_layer.tile_set = ground
	(level.get_node("Decor") as TileMapLayer).tile_set = decor
	for x in range(80):
		floor_layer.set_cell(Vector2i(x, 20), 0, Vector2i(0, 0))
		floor_layer.set_cell(Vector2i(x, 21), 0, Vector2i(0, 1))
	var scene := PackedScene.new()
	result = scene.pack(level)
	assert(result == OK, "Cannot pack LevelBase")
	result = ResourceSaver.save(scene, "res://scenes/levels/LevelBase.tscn")
	assert(result == OK, "Cannot save LevelBase")
	level.free()
	print("LevelBase TileSets and editable sample floor generated")
	quit()
