extends Node
## KIỂM TRA UI BẰNG ẢNH THẬT.
##
## Headless không có renderer (texture_2d_get trả null) nên test bằng số không
## bắt được lỗi hiển thị. Script này chạy CÓ cửa sổ, dựng từng màn hình UI thật,
## chụp PNG ra user://ui_shots/ để soi bằng mắt.
##
## Chạy:
##   godot --position -3000,-3000 --quit-after 3000 res://tests/ui_shots.tscn

const OUT_DIR: String = "user://ui_shots"
const WARMUP_FRAMES: int = 8

var _shot_index: int = 0
var _errors: PackedStringArray = PackedStringArray()


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	print("=== UI SHOTS: ", ProjectSettings.globalize_path(OUT_DIR), " ===")
	Engine.time_scale = 1.0
	get_window().min_size = Vector2i(640, 360)

	# Nen chu de toi truoc moi man hinh.
	var bg := ColorRect.new()
	bg.name = "ProbeBG"
	bg.color = Color(0.09, 0.10, 0.14)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, 0)

	await _shot("main_menu", "res://scenes/ui/MainMenu.tscn")
	await _shot("settings", "res://scenes/ui/Settings.tscn", func(n: Node) -> void:
		if n.has_method(&"open"):
			n.call(&"open"))
	await _shot("main_menu_play", "res://scenes/ui/MainMenu.tscn", func(n: Node) -> void:
		var b: Button = n.find_child("PlayButton", true, false) as Button
		if b != null:
			b.pressed.emit())
	await _shot("main_menu_charsel", "res://scenes/ui/MainMenu.tscn", func(n: Node) -> void:
		var b: Button = n.find_child("CharacterButton", true, false) as Button
		if b != null:
			b.pressed.emit())
	await _shot("character_select", "res://scenes/ui/CharacterSelect.tscn", func(n: Node) -> void:
		if n.has_method(&"open"):
			n.call(&"open"))
	await _shot("character_select_next", "res://scenes/ui/CharacterSelect.tscn", func(n: Node) -> void:
		if n.has_method(&"open"):
			n.call(&"open")
		var next: Button = n.find_child("NextButton", true, false) as Button
		if next != null:
			next.pressed.emit())
	# Gan unlocked_level = 3 va stars gia lap de kiem tra quy tac khoa + so sao.
	await _shot("level_select", "res://scenes/ui/LevelSelect.tscn", func(n: Node) -> void:
		SaveManager.unlocked_level = 3
		SaveManager.stars = {"1": 3, "2": 2, "3": 1, "6": 2}
		n.call(&"refresh"))
	await _shot("pause_menu", "res://scenes/ui/PauseMenu.tscn", func(n: Node) -> void:
		if n.has_method(&"open"):
			n.call(&"open"))
	# Khong co Player trong harness -> nem tinh hieu de kiem tra HUD ve that.
	await _shot("hud", "res://scenes/ui/HUD.tscn", func(_n: Node) -> void:
		GameManager.score = 1230
		GameManager.shard_count = 4
		EventBus.player_hp_changed.emit(3, 5)
		EventBus.score_changed.emit(1230)
		EventBus.gates_changed.emit(2, 3)
		EventBus.shards_changed.emit(4, 10))
	await _shot("game_over", "res://scenes/ui/GameOver.tscn", func(_n: Node) -> void:
		GameManager.score = 12500
		EventBus.game_over.emit())
	await _shot("level_complete", "res://scenes/ui/LevelComplete.tscn", func(_n: Node) -> void:
		GameManager.score = 12500
		EventBus.level_completed.emit())

	print("")
	print("=== TONG: %d anh ===" % _shot_index)
	if _errors.is_empty():
		print("khong co loi nao khi dung man hinh")
	else:
		for e in _errors:
			print("LOI: ", e)
	get_tree().quit()


## Dung 1 scene, cho layout on dinh, chup lai.
func _shot(name: String, path: String, prepare: Callable = Callable()) -> void:
	if not ResourceLoader.exists(path):
		_errors.append("thieu scene: %s" % path)
		return
	var node: Node = (load(path) as PackedScene).instantiate()
	add_child(node)
	move_child(node, 1)
	for i in WARMUP_FRAMES:
		await get_tree().process_frame
	if prepare.is_valid():
		prepare.call(node)
		for i in WARMUP_FRAMES:
			await get_tree().process_frame

	_shot_index += 1
	var file: String = "%s/%02d_%s.png" % [OUT_DIR, _shot_index, name]
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err: int = img.save_png(file)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var worst: String = _overflow_report(node)
	print("%-18s %s  viewport=%s%s" % [
		name, "OK " if err == OK else "LOI", vp, worst])

	node.queue_free()
	Engine.time_scale = 1.0
	for i in 4:
		await get_tree().process_frame


## Bat ky Control nao lam man hinh tran khong -> bao loi.
func _overflow_report(node: Node) -> String:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var bad: PackedStringArray = PackedStringArray()
	for n in _all(node):
		var c := n as Control
		if c == null:
			continue
		if not c.is_visible_in_tree():
			continue
		var r: Rect2 = c.get_global_rect()
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		# Node full-recentroi man hinh thi can nhat khong phai loi.
		if is_equal_approx(r.size.y, vp.y) and is_equal_approx(r.position.y, 0.0):
			continue
		if r.end.y > vp.y + 0.5 or r.end.x > vp.x + 0.5:
			bad.append("%s(%.0f,%.0f %.0fx%.0f)" % [
				String(n.name), r.position.x, r.position.y, r.size.x, r.size.y])
	if bad.is_empty():
		return ""
	return "  <-- TRAN: " + ", ".join(bad.slice(0, 4))


func _all(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out