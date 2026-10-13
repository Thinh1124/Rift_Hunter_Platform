extends Node
## XOÁ TOÀN BỘ TIẾN TRÌNH GAME — dùng cho test và demo.
##
## Chạy từ terminal (đóng game trước):
##   Xóa hết (kể cả cài đặt):
##     godot --headless --quit-after 600 res://tools/reset_progress.tscn
##
##   Giữ cài đặt âm lượng / rung / nút ảo, chỉ xóa tiến trình:
##     godot --headless --quit-after 600 -- --keep-settings res://tools/reset_progress.tscn
##
##   Chỉ XEM trạng thái hiện tại, không xóa:
##     godot --headless --quit-after 600 -- --dry-run res://tools/reset_progress.tscn
##
## Kết quả in ra console và ghi thêm vào user://reset_progress.log để dán khi
## báo lỗi.

const LOG_PATH: String = "user://reset_progress.log"

var _lines: PackedStringArray = PackedStringArray()


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var dry_run: bool = args.has("--dry-run")
	var keep_settings: bool = args.has("--keep-settings")

	_log("=== RESET TIEN TRINH RIFT HUNTER ===")
	_log("  save       : %s" % ProjectSettings.globalize_path(SaveManager.SAVE_PATH))
	_log("  ton tai    : %s" % FileAccess.file_exists(SaveManager.SAVE_PATH))
	_log("  che do     : %s" % ("XEM (khong xoa)" if dry_run else ("Giu cau hinh" if keep_settings else "XOA HET")))
	_log("")
	_log("TRUOC KHI XOA:")
	_log("  man da mo       : %d  (da thang: %s)" % [
		SaveManager.unlocked_level, _stars_text()])
	_log("  diem cao nhat   : %d" % SaveManager.best_score)
	_log("  nhan vat        : %s" % (SaveManager.selected_character_id if SaveManager.selected_character_id != "" else "(mac dinh)"))
	_log("  xem huong dan   : %s" % ("roi" if SaveManager.tutorial_completed else "chua"))
	if keep_settings:
		_log("  am luong / rung : %s" % [
			"music %.2f, sfx %.2f, rung %s" % [SaveManager.music_vol, SaveManager.sfx_vol,
				"bat" if SaveManager.vibration else "tat"]])
	_log("")

	if dry_run:
		_log("--> CHE DO XEM: khong co gi bi thay doi.")
		_finish()
		return

	_reset_progress(keep_settings)

	_log("SAU KHI XOA:")
	_log("  man da mo       : %d" % SaveManager.unlocked_level)
	_log("  diem cao nhat   : %d" % SaveManager.best_score)
	_log("  nhan vat        : %s" % (SaveManager.selected_character_id if SaveManager.selected_character_id != "" else "(mac dinh)"))
	_log("  xem huong dan   : %s" % ("roi" if SaveManager.tutorial_completed else "chua"))
	_log("")
	_log("SAU KHI XOA, MO LAI GAME se:")
	_log("  - chay lai anh huong dan Level0")
	_log("  - chi man 1 duoc mo")
	_log("  - tat ca 4 nhan vat chon duoc tu dau")
	_finish()


func _reset_progress(keep_settings: bool) -> void:
	# 1. Nap lai save tu dia. Neu keep_settings -> giu cau hinh, tra ve mac dinh.
	var music: float = SaveManager.music_vol
	var sfx: float = SaveManager.sfx_vol
	var vibrate: bool = SaveManager.vibration
	var opacity: float = SaveManager.touch_opacity
	var scale: float = SaveManager.touch_scale
	var character: String = SaveManager.selected_character_id

	SaveManager.unlocked_level = 1
	SaveManager.best_score = 0
	SaveManager.stars = {}
	SaveManager.selected_character_id = ""
	SaveManager.tutorial_completed = false
	if keep_settings:
		SaveManager.music_vol = music
		SaveManager.sfx_vol = sfx
		SaveManager.vibration = vibrate
		SaveManager.touch_opacity = opacity
		SaveManager.touch_scale = scale
		if not keep_settings:
			SaveManager.selected_character_id = character
	SaveManager.save()

	# 2. Trong RAM (quan trong neu chay chung voi game dang mo).
	GameManager.reset_run()
	GameManager.last_checkpoint = Vector2.ZERO
	GameManager.current_level = 1
	GameManager.total_gates = 0
	GameManager.remaining_gates = 0
	if not keep_settings:
		GameManager.selected_character = GameManager.load_character("")

	_log("  -> %d" % SaveManager.unlocked_level)


func _stars_text() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for key: String in SaveManager.stars:
		parts.append("%s:%d sao" % [key, SaveManager.stars[key]])
	return ", ".join(parts) if parts.size() > 0 else "(chua co)"


func _log(line: String) -> void:
	print(line)
	_lines.append(line)


func _finish() -> void:
	var file := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_lines) + "\n")
		file.close()
	print("  (ghi log: %s)" % ProjectSettings.globalize_path(LOG_PATH))
	get_tree().quit()