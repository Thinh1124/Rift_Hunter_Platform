extends Node
## Chup anh CharacterSelect o 2 trang thai: da mo khoa / chua mo khoa.

func _ready() -> void:
	call_deferred(&"_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("user://char_shots")
	var saved: int = SaveManager.levels_completed

	var cs: CharacterSelect = (load("res://scenes/ui/CharacterSelect.tscn") as PackedScene).instantiate() as CharacterSelect
	cs.overlay_mode = true
	add_child(cs)
	await get_tree().process_frame

	# 1) Save moi -> chi Pink Man mo khoa.
	SaveManager.levels_completed = 0
	cs.open()
	for i in 3:
		await get_tree().process_frame
	await _shot("locked_virtual_guy.png", 1)
	await _shot("locked_ninja_frog.png", 3)

	# 2) Vượt het -> tat ca mo khoa.
	SaveManager.levels_completed = 4
	cs.open()
	for i in 3:
		await get_tree().process_frame
	await _shot("unlocked_ninja_frog.png", 3)

	SaveManager.levels_completed = saved
	print("Xong -> ", ProjectSettings.globalize_path("user://char_shots"))
	get_tree().quit()


func _shot(file: String, index: int) -> void:
	var cs: CharacterSelect = get_child(0) as CharacterSelect
	cs._index = index
	cs._show_current()
	for _i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("user://char_shots/" + file)
	var lock: Label = cs.get_node("%LockLabel") as Label
	print("  %s -> '%s' tint=%s" % [file, lock.text, cs.get_node("%Sprite").modulate])