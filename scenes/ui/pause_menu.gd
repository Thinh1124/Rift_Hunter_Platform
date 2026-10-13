extends CanvasLayer
## Menu tạm dừng: Tiếp tục / Chơi lại / Cài đặt / Về menu.
##
## CanvasLayer 20 -> nằm trên HUD (5), TouchControls (10) và cả fade (128 chỉ
## lúc chuyển cảnh). process_mode = ALWAYS để nút bấm được khi cây đang pause.
##
## Mở/đóng bằng show()/hide(), KHÔNG đổi scene -> không mất trạng thái ải.
## Cây pause làm đóng băng Player, Enemy, Timer (PROCESS_MODE_INHERIT) đúng như
## cần; chỉ autoload + node ALWAYS còn chạy.

## Phát khi menu đóng (nút Đóng, phím pause, hoặc trước khi đổi scene).
## Hiện CHƯA có ai lắng nghe - giữ làm API công khai cho UI sau này.
signal closed

@export var level_select_scene: String = "res://scenes/ui/LevelSelect.tscn"
@export var settings_scene: String = "res://scenes/ui/Settings.tscn"

@onready var _resume_button: UIButton = %ResumeButton
@onready var _restart_button: UIButton = %RestartButton
@onready var _settings_button: UIButton = %SettingsButton
@onready var _quit_button: UIButton = %QuitButton
@onready var _shade: ColorRect = %Shade
@onready var _center: CenterContainer = %Center

## Popup cài đặt, dựng 1 lần rồi ẩn/hiện. KHÔNG đổi scene -> giữ nguyên
## trạng thái ải đang chơi, và cây vẫn pause nên Settings cần process ALWAYS.
var _settings_overlay: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	# HUD tìm menu qua group, không đoán đường dẫn node.
	add_to_group(&"pause_menu")
	visible = false

	_resume_button.pressed.connect(_on_resume_pressed)
	_restart_button.pressed.connect(_on_restart_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)


## Bật/tắt menu (nút trên HUD, hoặc phím pause).
func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	if visible:
		return
	# Slow-mo còn dính từ GameOver -> hủy trước khi pause, nếu không game
	# đóng băng ở tốc độ 0.3.
	Engine.time_scale = 1.0
	visible = true
	_set_menu_content_visible(true)
	get_tree().paused = true
	AudioManager.set_music_duck(AudioManager.PAUSE_DUCK)


## Đóng menu + bỏ pause + trả nhạc về đủ. Phát `closed` cho ai cần theo dõi.
func close() -> void:
	if not visible:
		return
	visible = false
	_set_menu_content_visible(false)
	get_tree().paused = false
	AudioManager.unduck_music()
	closed.emit()


## Chỉ bật/tắt phần NỘI DUNG của menu (lớp Shade + Center).
##
## KHÔNG được set `visible = false` trên chính CanvasLayer: Settings được nhét
## làm CON của PauseMenu, mà CanvasLayer.visible = false ẩn luôn mọi con ->
## popup bấm được nhưng không bao giờ hiện lên.
func _set_menu_content_visible(value: bool) -> void:
	_shade.visible = value
	_center.visible = value


func _unhandled_input(event: InputEvent) -> void:
	# Bấm pause lần nữa -> đóng menu. HUD cũng bắt action này nhưng chỉ MỞ khi
	# menu đang đóng, nên hai handler chạy cùng lúc vẫn ra kết quả "đóng".
	if not visible:
		return
	# Đang mở popup cài đặt -> để Settings tự bắt phím pause, không đóng 2 tầng.
	if _settings_overlay != null and _settings_overlay.visible:
		return
	if event.is_action_pressed(&"pause"):
		close()
		get_viewport().set_input_as_handled()


func _on_resume_pressed() -> void:
	AudioManager.play_sfx(&"ui_back")
	close()


func _on_restart_pressed() -> void:
	AudioManager.play_sfx(&"ui_select")
	# Bỏ pause TRƯỚC khi đổi cảnh, nếu không scene mới vào sẽ đứng im.
	close()
	GameManager.restart_level()


func _on_settings_pressed() -> void:
	AudioManager.play_sfx(&"ui_select")
	_ensure_settings_overlay()
	if _settings_overlay == null:
		return
	_settings_overlay.call(&"open")
	# Ẩn phần nội dung PauseMenu cho khỏi chồng, nhưng CỐ TÌNH không gọi
	# close(): close() bỏ pause -> Settings (process ALWAYS) sẽ đứng im.
	# Và không set visible của CanvasLayer, xem _set_menu_content_visible.
	_set_menu_content_visible(false)


## Settings đóng -> hiện lại PauseMenu. open() an toàn khi cây đang pause vì
## open() chỉ set paused = true (đã true sẵn), không đụng time_scale của gameplay.
func _on_settings_closed() -> void:
	if not visible:
		open()


func _ensure_settings_overlay() -> void:
	if _settings_overlay != null and is_instance_valid(_settings_overlay):
		return
	if not ResourceLoader.exists(settings_scene):
		push_error("PauseMenu: không thấy Settings tại '%s'." % settings_scene)
		return
	var packed: PackedScene = load(settings_scene) as PackedScene
	if packed == null:
		push_error("PauseMenu: '%s' không load được." % settings_scene)
		return
	var overlay: Control = packed.instantiate() as Control
	if overlay == null:
		push_error("PauseMenu: Settings phải là Control.")
		return
	overlay.set(&"overlay_mode", true)
	overlay.visible = false
	add_child(overlay)
	# Menu chủ nghe signal `closed`, không cần biết đường dẫn node.
	if overlay.has_signal(&"closed"):
		overlay.connect(&"closed", _on_settings_closed)
	_settings_overlay = overlay


func _on_quit_pressed() -> void:
	AudioManager.play_sfx(&"ui_back")
	close()
	GameManager.go_to_menu()