extends Node
## Chup LevelSelect theo save THAT (khong ghi du lieu gia nhu ui_shots).

func _ready() -> void:
	call_deferred(&"_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("user://lock_shots")
	var ls: Control = (load("res://scenes/ui/LevelSelect.tscn") as PackedScene).instantiate() as Control
	add_child(ls)
	await get_tree().process_frame

	print("save that: unlocked_level=%d  levels_completed=%d  stars=%s" % [
		SaveManager.unlocked_level, SaveManager.levels_completed, SaveManager.stars])

	for state: Vector2i in [Vector2i(1, 0), Vector2i(2, 1), Vector2i(3, 4), Vector2i(6, 6)]:
		SaveManager.unlocked_level = state.x
		SaveManager.stars = {}
		for lvl in range(1, state.y + 1):
			SaveManager.stars[str(lvl)] = 3 - ((lvl + 1) % 3)
		ls.call(&"refresh")
		for _i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		await get_tree().process_frame
		var name: String = "locked_upto_%d.png" % state.x
		get_viewport().get_texture().get_image().save_png("user://lock_shots/" + name)
		print("  luu ", name)

	print("Xong -> ", ProjectSettings.globalize_path("user://lock_shots"))
	get_tree().quit()