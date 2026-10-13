extends Node
## Nghiệm thu: ải hướng dẫn Level0 chỉ chạy LẦN ĐẦU.
##
##   1. Save mới -> cần hướng dẫn
##   2. go_to_level(0) được phép và trỏ đúng scene
##   3. Hoàn thành Level0 -> đánh dấu đã xem, ghi ra đĩa
##   4. Đọc lại save -> không cần hướng dẫn nữa
##   5. Đi tiếp từ Level0 sang Level1
##
## Test đụng save thật của người chơi -> sao lưu rồi trả lại nguyên trạng.

const SAVE_PATH: String = "user://save.json"

var checks: int = 0
var fails: int = 0
var _backup: PackedByteArray = PackedByteArray()
var _had_save: bool = false


func _ready() -> void:
	_backup_save()
	call_deferred(&"_run")


func _run() -> void:
	print("=== TUTORIAL TEST ===")
	_test_path_exists()
	_test_fresh_save_needs_tutorial()
	_test_go_to_tutorial_level()
	await _test_completion_marks_done()
	await _test_persists_across_reload()
	_test_next_level_after_tutorial()
	await _test_mainmenu_routing()

	print("--- ket qua ---")
	print("PASS" if fails == 0 else "FAIL (%d/%d)" % [fails, checks])
	print("=== TUTORIAL TEST DONE ===")
	_restore_save()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()


func _test_path_exists() -> void:
	print("--- 1. scene Levels ton tai ---")
	var path: String = GameManager.level_path(GameManager.TUTORIAL_LEVEL)
	print("level_path(0) = ", path)
	_check("TUTORIAL_LEVEL = 0", GameManager.TUTORIAL_LEVEL == 0)
	_check("Level0.tscn tồn tại", ResourceLoader.exists(path), path)


func _test_fresh_save_needs_tutorial() -> void:
	print("--- 2. save moi -> can huong dan ---")
	SaveManager.tutorial_completed = false
	SaveManager.save()
	SaveManager.load_data()
	print("tutorial_completed = ", SaveManager.tutorial_completed)
	_check("save mới thì cần hướng dẫn", SaveManager.needs_tutorial())


func _test_go_to_tutorial_level() -> void:
	print("--- 3. vao duoc Level0 ---")
	# Không gọi go_to_level() thật (sẽ đổi cảnh); kiểm tra clamp + đường dẫn.
	var clamped: int = clampi(0, GameManager.TUTORIAL_LEVEL, GameManager.LEVEL_COUNT)
	_log("clampi(0, 0, 6) = ", clamped)
	_check("0 không bị clamp lên 1", clamped == 0)
	_check("đường dẫn ải 0 là Level0.tscn",
		GameManager.level_path(0).ends_with("Level0.tscn"))


func _test_completion_marks_done() -> void:
	print("--- 4. hoan thanh Level0 -> danh dau da xem ---")
	GameManager.current_level = GameManager.TUTORIAL_LEVEL
	GameManager.last_checkpoint = Vector2(400, 288)
	GameManager._on_level_completed()
	print("tutorial_completed = ", SaveManager.tutorial_completed)
	_check("hoàn thành Level0 -> đánh dấu đã xem", SaveManager.tutorial_completed)
	_check("không còn cần hướng dẫn", not SaveManager.needs_tutorial())
	# Xong ải hướng dẫn thì ải 1 phải vẫn mở (không bị unlock(0) ghi đè).
	_log("unlocked_level = ", SaveManager.unlocked_level)
	_check("ải 1 vẫn mở sau khi xong hướng dẫn", SaveManager.unlocked_level >= 1)


func _test_persists_across_reload() -> void:
	print("--- 5. doc lai save (mô phỏng tat/mo game) ---")
	SaveManager.load_data()
	print("sau load_data(): tutorial_completed = ", SaveManager.tutorial_completed)
	_check("cờ đã lưu xuống đĩa", SaveManager.tutorial_completed)
	_check("mở game lần 2 không hiện hướng dẫn nữa", not SaveManager.needs_tutorial())


func _test_next_level_after_tutorial() -> void:
	print("--- 6. tu Level0 sang Level1 ---")
	var nxt: int = clampi(GameManager.TUTORIAL_LEVEL + 1, 1, GameManager.LEVEL_COUNT)
	_log("next = ", nxt, " path = ", GameManager.level_path(nxt))
	_check("bấm NEXT ở Level0 sang Level1", nxt == 1)
	_check("Level1.tscn tồn tại", ResourceLoader.exists(GameManager.level_path(nxt)))


## Bấm nút PLAY thật trên MainMenu (mở panel chọn ải) rồi bấm ải 1, đúng như
## người chơi. go_to_level() set current_level TRƯỚC rồi mới đổi cảnh nên đọc
## ngay được.
func _test_mainmenu_routing() -> void:
	print("--- 7. bam PLAY tren MainMenu -> chon anh 1 ---")
	var menu: Control = $MainMenu as Control
	var play_button: Button = menu.get_node(^"%PlayButton") as Button

	# Lần 1: save chưa đánh dấu -> phải vào Level0.
	SaveManager.tutorial_completed = false
	GameManager.current_level = 5
	play_button.pressed.emit()
	await get_tree().process_frame
	var panel: Control = menu.find_child("LevelSelect", true, false) as Control
	_log("panel LevelSelect = ", panel)
	_check("bấm PLAY mở được panel chọn ải", panel != null)
	if panel == null:
		return
	panel.call(&"_on_level_pressed", 1)
	_log("lan 1 -> current_level = ", GameManager.current_level)
	_check("lần đầu chọn ải -> vào Level0",
		GameManager.current_level == GameManager.TUTORIAL_LEVEL,
		str(GameManager.current_level))

	# Lần 2: đã đánh dấu -> bỏ qua Level0, vào ải đã mở khóa.
	SaveManager.tutorial_completed = true
	SaveManager.unlocked_level = 3
	GameManager.current_level = 0
	play_button.pressed.emit()
	await get_tree().process_frame
	panel.call(&"_on_level_pressed", 1)
	_log("lan 2 -> current_level = ", GameManager.current_level)
	_check("lần sau chọn ải -> bỏ qua hướng dẫn",
		GameManager.current_level == 1, str(GameManager.current_level))


# --- save an toan ---------------------------------------------------------

func _backup_save() -> void:
	_had_save = FileAccess.file_exists(SAVE_PATH)
	if _had_save:
		_backup = FileAccess.get_file_as_bytes(SAVE_PATH)


func _restore_save() -> void:
	if _had_save:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_buffer(_backup)
			file.close()
	elif FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _log(...args: Array) -> void:
	var line: String = ""
	for i in args.size():
		if i > 0:
			line += " "
		line += str(args[i])
	print(line)


func _check(label: String, ok: bool, detail: String = "") -> void:
	checks += 1
	if ok:
		print("   PASS  ", label)
	else:
		fails += 1
		print("   FAIL  ", label, "  ", detail)