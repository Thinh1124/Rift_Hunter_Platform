extends Node2D
## Chup anh nut ao (co icon) de kiem tra hinh dang.

func _ready() -> void:
	call_deferred(&"_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("user://touch_shots")
	var level: Node2D = (load("res://scenes/levels/Level0.tscn") as PackedScene).instantiate() as Node2D
	add_child(level)
	await get_tree().process_frame

	var touch: TouchControls = level.get_node("TouchControls") as TouchControls
	touch.force_visible = true
	touch.visible = true
	touch.opacity = 1.0
	touch._layout()
	await get_tree().process_frame

	var cam: Camera2D = level.get_node("Player").get_node_or_null("Camera2D") as Camera2D
	if cam != null:
		cam.reset_smoothing()
		cam.force_update_scroll()
	for _f in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("user://touch_shots/buttons.png")
	print("  luu buttons.png")
	print("  Left  center=", touch.button_center(&"move_left"))
	print("  Right center=", touch.button_center(&"move_right"))
	print("  Jump  center=", touch.button_center(&"jump"))
	print("  Attack center=", touch.button_center(&"attack"))
	print("  Interact center=", touch.button_center(&"interact"))
	get_tree().quit()