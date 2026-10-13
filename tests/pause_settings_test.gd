extends Node
## Nghiệm thu luồng Settings từ PauseMenu.
##
## Lỗi đã gặp: PauseMenu._on_settings_pressed() set `visible = false` trên chính
## CanvasLayer. Settings được nhét làm CON của layer đó, nên overlay.visible=true
## nhưng is_visible_in_tree()=false -> bấm SETTINGS không thấy gì hiện lên.
##
## Cách chạy: nhét PauseMenu vào cây, mở, bấm SettingsButton, kiểm tra popup thực
## sự hiển thị được khi cây đang paused.

const PAUSE_MENU: String = "res://scenes/ui/PauseMenu.tscn"

var checks: int = 0
var fails: int = 0


func _ready() -> void:
	await _run()
	get_tree().paused = false
	print("%s (%d/%d)" % ["PASS" if fails == 0 else "FAIL", checks - fails, checks])
	get_tree().quit()


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		fails += 1
		print("   FAIL  ", label)


func _run() -> void:
	var menu: CanvasLayer = (load(PAUSE_MENU) as PackedScene).instantiate() as CanvasLayer
	add_child(menu)
	for i in 8:
		await get_tree().process_frame

	menu.call(&"open")
	for i in 6:
		await get_tree().process_frame
	_check(get_tree().paused, "PauseMenu.open() phai pause cay")
	_check(menu.visible, "PauseMenu phai hien sau open()")

	var button: Button = menu.find_child("SettingsButton", true, false) as Button
	_check(button != null, "PauseMenu phai co nut SettingsButton")
	if button == null:
		return
	button.pressed.emit()
	for i in 10:
		await get_tree().process_frame

	var overlay: Control = _find_settings(menu)
	_check(overlay != null, "Settings phai duoc nhet vao PauseMenu")
	if overlay == null:
		return

	# Dòng quan trong nhat: overlay.visible=true chua du, phai hien trong cay.
	_check(overlay.visible, "Settings.visible phai true sau khi bam nut")
	_check(overlay.is_visible_in_tree(), "Settings phai hien THAT tren man hinh")
	_check(get_tree().paused, "cay van phai pause khi mo Settings")

	var panel: Control = overlay.find_child("Panel", true, false) as Control
	_check(panel != null and panel.is_visible_in_tree(), "Panel cua Settings phai hien")
	if panel != null:
		var vp: Vector2 = get_viewport().get_visible_rect().size
		_check(panel.get_global_rect().end.y <= vp.y + 0.5, "Settings phai nam trong man hinh")

	# Dong Settings -> PauseMenu phai hien lai, khong ket o trang thai 2 tang an.
	overlay.call(&"close")
	for i in 6:
		await get_tree().process_frame
	_check(menu.visible, "dong Settings phai hien lai PauseMenu")
	_check(not overlay.is_visible_in_tree(), "Settings phai an sau khi dong")


func _find_settings(n: Node) -> Control:
	for c in n.get_children():
		if c is Control and String(c.name) == "Settings":
			return c as Control
		var found: Control = _find_settings(c)
		if found != null:
			return found
	return null