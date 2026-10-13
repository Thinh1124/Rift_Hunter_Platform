extends Node2D
## Chup anh EnemyGalleryTest. Di chuyen Player toi tung vung roi chup,
## dung chinh Camera2D cua Player giong het thu gian nguoi choi.

const STOPS: Array[Vector2] = [
	Vector2(480, 312),
	Vector2(740, 312),
	Vector2(980, 312),
	Vector2(1230, 312),
]

func _ready() -> void:
	call_deferred(&"_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("user://gallery_shots")
	var gallery: Node2D = (load("res://tests/EnemyGalleryTest.tscn") as PackedScene).instantiate() as Node2D
	add_child(gallery)
	await get_tree().process_frame

	var player: Node2D = gallery.get_node("Player") as Node2D
	for i in STOPS.size():
		player.global_position = STOPS[i]
		player.velocity = Vector2.ZERO
		for _f in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		await get_tree().process_frame
		var cam: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
		var cx: int = int(cam.get_screen_center_position().x) if cam != null else -1
		get_viewport().get_texture().get_image().save_png("user://gallery_shots/shot_%d.png" % (i + 1))
		print("  shot_%d.png  player x=%d  cam x=%d" % [i + 1, int(STOPS[i].x), cx])

	print("Xong -> ", ProjectSettings.globalize_path("user://gallery_shots"))
	get_tree().quit()