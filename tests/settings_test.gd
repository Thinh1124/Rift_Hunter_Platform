extends Node
## Nghiệm thu Settings popup:
##   1. Control full-rect + process ALWAYS (bấm được khi cây đang pause)
##   2. Đủ 5 control + khoảng min/max đúng spec
##   3. Kéo slider áp dụng NGAY (AudioManager + TouchControls)
##   4. Lưu khi đóng -> tắt/mở lại game vẫn giữ (load_data() từ disk)
##   5. Đọc giá trị hiện tại lúc mở (đổi save bên ngoài rồi open())
##
## Ghi chú: harness MCP không bơm được sự kiện chuột xuống cửa sổ game, nên
## thao tác kéo/thu được giả lập bằng cách gán .value và gọi .pressed.emit()
## - đúng đường đi thật của Control khi người chơi dùng chuột/cảm ứng.

var settings: Control
var touch: TouchControls

var checks: int = 0
var fails: int = 0

## MCP game_helper log bị xen kẽ thứ tự, nên test ghi thêm 1 bản báo cáo có thứ tự
## vào file để đọc lại cho chắc.
const REPORT_PATH: String = "user://settings_test_report.txt"
const SAVE_PATH: String = "user://save.json"
var _log_buffer: PackedStringArray = PackedStringArray()
## Test đụng vào save thật của người chơi -> sao lưu rồi trả lại nguyên trạng.
var _save_backup: PackedByteArray = PackedByteArray()
var _had_save: bool = false


func _backup_save() -> void:
	_had_save = FileAccess.file_exists(SAVE_PATH)
	if _had_save:
		_save_backup = FileAccess.get_file_as_bytes(SAVE_PATH)


func _restore_save() -> void:
	if _had_save:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_buffer(_save_backup)
			file.close()
	elif FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

## Giá trị sẽ ép vào slider trước khi mở, để kiểm tra open() nạp lại từ save.
const MUSIC_EXPECT: float = 0.35
const SFX_EXPECT: float = 0.45
const OPACITY_EXPECT: float = 0.7
const SCALE_EXPECT: float = 1.2


func _log(...args: Array) -> void:
	var line: String = ""
	for i in args.size():
		if i > 0:
			line += " "
		line += str(args[i])
	_log_buffer.append(line)
	print(line)


func _ready() -> void:
	settings = $Settings
	touch = $TouchControls
	_backup_save()
	await get_tree().process_frame

	_log("=== SETTINGS TEST ===")
	# PHẢI await từng hàm: các hàm test có await bên trong, không await thì
	# chúng fire-and-forget và phần log chạy lẫn vào nhau.
	await _test_full_rect_and_process_mode()
	await _test_controls_and_ranges()
	await _test_apply_immediately()
	await _test_save_on_close()
	await _test_persistence_after_reload()
	await _test_reads_current_on_open()
	await _test_min_touch_size()
	await _test_from_pause_menu()

	_log("--- ket qua ---")
	_log("PASS" if fails == 0 else "FAIL (%d/%d)" % [fails, checks])
	_log("=== SETTINGS TEST DONE ===")

	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_log_buffer))
		file.close()
		_log("report -> ", ProjectSettings.globalize_path(REPORT_PATH))

	_restore_save()
	await get_tree().create_timer(0.3).timeout
	get_tree().quit()


# --- 1. Full rect + ALWAYS --------------------------------------------------

func _test_full_rect_and_process_mode() -> void:
	_log("--- 1. anchors full-rect + process_mode ALWAYS ---")
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_log("anchor_right=%.1f anchor_bottom=%.1f size=%s" % [
		settings.anchor_right, settings.anchor_bottom, settings.size])
	_check("anchor_right = 1.0", is_equal_approx(settings.anchor_right, 1.0))
	_check("anchor_bottom = 1.0", is_equal_approx(settings.anchor_bottom, 1.0))
	_check("phu het viewport %s" % vp, settings.size.distance_to(vp) < 1.0)
	_check("process_mode = ALWAYS", settings.process_mode == Node.PROCESS_MODE_ALWAYS,
		str(settings.process_mode))

	# LƯU ý: harness headless không định tuyến được sự kiện chuột vào Control
	# (xem tests/touch_test.gd). Nên chỉ assert process_mode đúng ALWAYS - đó
	# chính là điều khiến GUI input chạy được lúc cây pause. Việc dò tay
	# PauseMenu -> Settings nên kiểm bằng mắt trong editor.
	get_tree().paused = true
	await get_tree().process_frame
	_log("paused=true -> Settings.process_mode = %d (ALWAYS)" % settings.process_mode)
	_check("giữ process_mode ALWAYS khi cây pause",
		settings.process_mode == Node.PROCESS_MODE_ALWAYS)
	get_tree().paused = false


# --- 2. Control + khoảng giá trị -------------------------------------------

func _test_controls_and_ranges() -> void:
	_log("--- 2. thanh phan + khoang gia tri ---")
	var music := settings.get_node(^"%MusicSlider") as HSlider
	var sfx := settings.get_node(^"%SfxSlider") as HSlider
	var vibe := settings.get_node(^"%VibrationCheck") as CheckButton
	var opacity := settings.get_node(^"%TouchOpacitySlider") as HSlider
	var scale := settings.get_node(^"%TouchScaleSlider") as HSlider
	var close_btn := settings.get_node(^"%CloseButton") as Button

	_check("HSlider Nhạc tồn tại", music != null)
	_check("HSlider SFX tồn tại", sfx != null)
	_check("CheckButton Rung tồn tại", vibe != null)
	_check("HSlider Độ mờ nút ảo tồn tại", opacity != null)
	_check("HSlider Kích thước nút ảo tồn tại", scale != null)
	_check("nút Đóng tồn tại", close_btn != null)

	_log("Music  %.2f..%.2f | SFX %.2f..%.2f" % [music.min_value, music.max_value, sfx.min_value, sfx.max_value])
	_log("Opacity %.2f..%.2f | Scale %.2f..%.2f" % [
		opacity.min_value, opacity.max_value, scale.min_value, scale.max_value])
	_check("Nhạc 0.0 - 1.0", is_equal_approx(music.min_value, 0.0) and is_equal_approx(music.max_value, 1.0))
	_check("SFX 0.0 - 1.0", is_equal_approx(sfx.min_value, 0.0) and is_equal_approx(sfx.max_value, 1.0))
	_check("Độ mờ nút ảo 0.2 - 1.0",
		is_equal_approx(opacity.min_value, 0.2) and is_equal_approx(opacity.max_value, 1.0))
	_check("Kích thước nút ảo 0.8 - 1.3",
		is_equal_approx(scale.min_value, 0.8) and is_equal_approx(scale.max_value, 1.3))

	# Safe area: nội dung phải nằm trong vùng an toàn, không dồn sát mép.
	var panel := settings.get_node(^"SafeArea/Panel") as Control
	_log("Panel rect trong viewport: ", panel.get_global_rect())
	_check("panel nằm trong viewport",
		panel.get_global_rect().position.x >= 0.0 and panel.get_global_rect().end.y <= vp_size().y)


# --- 3. Kéo slider áp dụng ngay --------------------------------------------

func _test_apply_immediately() -> void:
	_log("--- 3. keo slider ap dung NGAY ---")
	var music := settings.get_node(^"%MusicSlider") as HSlider
	var sfx := settings.get_node(^"%SfxSlider") as HSlider
	var vibe := settings.get_node(^"%VibrationCheck") as CheckButton
	var opacity := settings.get_node(^"%TouchOpacitySlider") as HSlider
	var scale := settings.get_node(^"%TouchScaleSlider") as HSlider

	# value_changed phát khi Control đổi .value -> giống hệt lúc người chơi kéo.
	music.value = 0.3
	await get_tree().process_frame
	_check("kéo Nhạc -> AudioManager nhận", is_equal_approx(AudioManager.get_music_volume(), 0.3),
		str(AudioManager.get_music_volume()))
	_check("kéo Nhạc -> SaveManager nhận", is_equal_approx(SaveManager.music_vol, 0.3))

	sfx.value = 0.6
	await get_tree().process_frame
	_check("kéo SFX -> AudioManager nhận", is_equal_approx(AudioManager.get_sfx_volume(), 0.6),
		str(AudioManager.get_sfx_volume()))
	_check("kéo SFX -> SaveManager nhận", is_equal_approx(SaveManager.sfx_vol, 0.6))

	opacity.value = 0.8
	scale.value = 1.25
	await get_tree().process_frame
	_log("TouchControls modulate.a=%.2f button_scale=%.2f" % [
		touch.get_node(^"Root/Jump").modulate.a, touch.button_scale])
	_check("kéo Độ mờ -> TouchControls đổi ngay",
		is_equal_approx(touch.get_node(^"Root/Jump").modulate.a, 0.8))
	_check("kéo Cỡ nút -> TouchControls đổi ngay", is_equal_approx(touch.button_scale, 1.25))
	_check("kéo Độ mờ -> SaveManager nhận", is_equal_approx(SaveManager.touch_opacity, 0.8))
	_check("kéo Cỡ nút -> SaveManager nhận", is_equal_approx(SaveManager.touch_scale, 1.25))

	# Tắt rung -> Player sẽ bỏ qua Input.vibrate_handheld().
	vibe.button_pressed = false
	vibe.toggled.emit(false)
	await get_tree().process_frame
	_check("tắt Rung -> SaveManager.vibration = false", SaveManager.vibration == false)
	vibe.button_pressed = true
	vibe.toggled.emit(true)
	await get_tree().process_frame
	_check("bật Rung -> SaveManager.vibration = true", SaveManager.vibration == true)


# --- 4. Lưu khi đóng -------------------------------------------------------

func _test_save_on_close() -> void:
	_log("--- 4. luu SaveManager khi dong ---")
	var opacity := settings.get_node(^"%TouchOpacitySlider") as HSlider
	opacity.value = 0.65
	await get_tree().process_frame

	# overlay_mode=true -> nút Đóng chỉ ẩn popup, KHÔNG đổi scene.
	var close_btn := settings.get_node(^"%CloseButton") as Button
	var closed_signal: Array[int] = []
	settings.closed.connect(func() -> void: closed_signal.append(1))
	settings.overlay_mode = true
	close_btn.pressed.emit()
	await get_tree().process_frame

	_check("bấm Đóng -> phát signal closed", closed_signal.size() == 1)
	_check("bấm Đóng -> ẩn popup", settings.visible == false)
	_check("overlay_mode -> không đổi scene", get_tree().current_scene == self)
	_log("save.json trên disk có touch_opacity=", SaveManager.touch_opacity)


# --- 5. Tắt/mở lại game vẫn giữ --------------------------------------------

func _test_persistence_after_reload() -> void:
	_log("--- 5. NGHIEM THU: tat/mo lai game van giu cai dat ---")
	# Nghiệm thu bằng cách nạp lại save từ disk y như lúc khởi động game.
	SaveManager.load_data()
	_log("sau load_data(): music=%.2f sfx=%.2f vibe=%s opacity=%.2f scale=%.2f" % [
		SaveManager.music_vol, SaveManager.sfx_vol, SaveManager.vibration,
		SaveManager.touch_opacity, SaveManager.touch_scale])
	_check("giữ Nhạc", is_equal_approx(SaveManager.music_vol, 0.3))
	_check("giữ SFX", is_equal_approx(SaveManager.sfx_vol, 0.6))
	_check("giữ Rung", SaveManager.vibration == true)
	_check("giữ Độ mờ nút ảo", is_equal_approx(SaveManager.touch_opacity, 0.65))
	_check("giữ Cỡ nút ảo", is_equal_approx(SaveManager.touch_scale, 1.25))

	# Nút ảo dựng lại (giống vào ải mới) phải nhận giá trị đã lưu.
	var fresh: TouchControls = load("res://scenes/ui/TouchControls.tscn").instantiate()
	add_child(fresh)
	await get_tree().process_frame
	_log("TouchControls mới: modulate.a=%.2f button_scale=%.2f" % [
		fresh.get_node(^"Root/Jump").modulate.a, fresh.button_scale])
	_check("TouchControls mới nhận độ mờ đã lưu",
		is_equal_approx(fresh.get_node(^"Root/Jump").modulate.a, 0.65))
	_check("TouchControls mới nhận cỡ nút đã lưu", is_equal_approx(fresh.button_scale, 1.25))
	fresh.queue_free()


# --- 6. Đọc giá trị hiện tại lúc mở ---------------------------------------

func _test_reads_current_on_open() -> void:
	_log("--- 6. doc gia tri hien tai luc mo ---")
	# Giả lập người chơi đổi cài đặt ở nơi khác (vd menu khác) rồi mở lại popup.
	SaveManager.set_music_volume(MUSIC_EXPECT)
	SaveManager.set_sfx_volume(SFX_EXPECT)
	SaveManager.set_touch_opacity(OPACITY_EXPECT)
	SaveManager.set_touch_scale(SCALE_EXPECT)
	SaveManager.set_vibration(false)

	settings.open()
	await get_tree().process_frame
	_log("mở lại -> hiện: music=%.2f sfx=%.2f opacity=%.2f scale=%.2f vibe=%s" % [
		_node(^"%MusicSlider").value, _node(^"%SfxSlider").value,
		_node(^"%TouchOpacitySlider").value, _node(^"%TouchScaleSlider").value,
		_node(^"%VibrationCheck").button_pressed])
	_check("hiện đúng Nhạc", is_equal_approx(_node(^"%MusicSlider").value, MUSIC_EXPECT))
	_check("hiện đúng SFX", is_equal_approx(_node(^"%SfxSlider").value, SFX_EXPECT))
	_check("hiện đúng Độ mờ", is_equal_approx(_node(^"%TouchOpacitySlider").value, OPACITY_EXPECT))
	_check("hiện đúng Cỡ nút", is_equal_approx(_node(^"%TouchScaleSlider").value, SCALE_EXPECT))
	_check("hiện đúng Rung", _node(^"%VibrationCheck").button_pressed == false)
	_check("popup hiện lên", settings.visible == true)


# --- 7. Nút chạm tối thiểu 48x48 -------------------------------------------

func _test_min_touch_size() -> void:
	_log("--- 7. nut cham toi thieu 48x48 ---")
	var close_btn := settings.get_node(^"%CloseButton") as Control
	_log("CloseButton min size = ", close_btn.custom_minimum_size, " thực tế = ", close_btn.size)
	_check("nút Đóng >= 48x48",
		close_btn.size.x >= 48.0 and close_btn.size.y >= 48.0, str(close_btn.size))
	for button: Control in _find_buttons(settings):
		_check("%s >= 48x48" % button.name,
			button.size.x >= 48.0 and button.size.y >= 48.0, str(button.size))


# --- 8. Dùng được từ PauseMenu (overlay, không đổi scene) ------------------

func _test_from_pause_menu() -> void:
	print("--- 8. mo Settings tu PauseMenu ---")
	var pause: CanvasLayer = $PauseMenu
	var settings_btn: Button = pause.get_node(^"%SettingsButton")

	pause.call(&"open")
	await get_tree().process_frame
	_log("PauseMenu mở: visible=%s paused=%s" % [pause.visible, get_tree().paused])
	_check("PauseMenu mở và pause cây", pause.visible and get_tree().paused)

	settings_btn.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	var overlay: Control = pause.get_node_or_null(^"Settings") as Control
	_log("overlay = %s visible=%s | PauseMenu visible=%s paused=%s" % [
		overlay, overlay.visible if overlay else "-", pause.visible, get_tree().paused])
	_check("PauseMenu dựng được overlay Settings", overlay != null)
	if overlay != null:
		_check("overlay hiện lên", overlay.visible)
		_check("overlay là chính Settings.tscn", overlay.get_script() != null)
		_check("overlay chạy được lúc cây pause (ALWAYS)",
			overlay.process_mode == Node.PROCESS_MODE_ALWAYS)
		# PauseMenu chỉ ẩn phần NỘI DUNG (Shade + Center), KHÔNG set visible
		# của CanvasLayer: Settings là con của layer đó, ẩn layer là ẩn luôn
		# popup -> bấm SETTINGS không thấy gì hiện lên.
		var menu_shade: ColorRect = pause.get_node_or_null(^"%Shade") as ColorRect
		var menu_center: CenterContainer = pause.get_node_or_null(^"%Center") as CenterContainer
		_check("PauseMenu ẩn phần nội dung cho khỏi chồng",
			menu_shade != null and not menu_shade.visible
			and menu_center != null and not menu_center.visible)
		_check("overlay thật sự hiện trong cây (không bị CanvasLayer ẩn)",
			overlay.is_visible_in_tree())
		# QUAN TRỌNG: cây vẫn phải pause, nếu bỏ pause thì popup sẽ đứng im.
		_check("cây VẪN pause để popup nhận input", get_tree().paused)
		_check("không đổi scene (vẫn ở SettingsTest)", get_tree().current_scene == self)

		# Kéo slider trong lúc pause -> vẫn phải áp dụng được.
		overlay.get_node(^"%TouchScaleSlider").value = 0.9
		await get_tree().process_frame
		_check("kéo slider lúc pause vẫn áp dụng", is_equal_approx(touch.button_scale, 0.9))

		# Đóng -> PauseMenu phải hiện lại và cây vẫn pause
		overlay.get_node(^"%CloseButton").pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
		_log("đóng overlay: PauseMenu visible=%s paused=%s" % [pause.visible, get_tree().paused])
		_check("đóng overlay -> PauseMenu hiện lại", pause.visible)
		_check("đóng overlay -> cây vẫn pause", get_tree().paused)

	pause.call(&"close")
	await get_tree().process_frame
	_check("đóng PauseMenu -> bỏ pause", not get_tree().paused)
	SaveManager.set_touch_scale(SCALE_EXPECT)


# --- Helper ----------------------------------------------------------------

func _node(path: NodePath) -> Variant:
	return settings.get_node(path)


## Gom mọi Button/CheckButton trong popup để kiểm tra ngưỡng chạm.
func _find_buttons(node: Node) -> Array[Control]:
	var out: Array[Control] = []
	if node is Button or node is CheckButton:
		out.append(node as Control)
	for child in node.get_children():
		out.append_array(_find_buttons(child))
	return out


func vp_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _check(label: String, ok: bool, detail: String = "") -> void:
	checks += 1
	if ok:
		_log("   PASS  ", label)
	else:
		fails += 1
		_log("   FAIL  ", label, "  ", detail)