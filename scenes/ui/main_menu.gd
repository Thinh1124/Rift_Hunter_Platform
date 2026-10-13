extends Control
## Menu chính: Chơi / Chọn màn / Cài đặt / Thoát.
##
## Nút dùng signal `pressed` nối trong MainMenu.tscn, không đụng đường dẫn node.
## LevelSelect đi qua SceneTransition (có fade); Settings là popup nhét vào đây
## nên không đổi scene, nhạc menu không bị cắt.
##
## Ải chưa tồn tại sẽ báo lỗi rõ ràng thay vì mở màn hình đen.

@export var level_select_scene: String = "res://scenes/ui/LevelSelect.tscn"
@export var settings_scene: String = "res://scenes/ui/Settings.tscn"
@export var character_select_scene: String = "res://scenes/ui/CharacterSelect.tscn"
## Tên game hiện trên logo. Giữ giống game_title của Boot.tscn để 2 màn khớp.
@export var game_title: String = "SPACE BUNNY"
## Nhạc nền menu. Để trống nếu chưa có file -> không phát, không lỗi.
@export var menu_music: AudioStream
## Vùng preview bên phải: Sprite nằm giữa SubViewport rồi scale.
@export_range(1.0, 4.0, 0.25) var preview_scale: float = 2.0

@onready var _title_label: Label = %Title
@onready var _play_button: UIButton = %PlayButton
@onready var _settings_button: UIButton = %SettingsButton
@onready var _quit_button: UIButton = %QuitButton
@onready var _character_button: UIButton = %CharacterButton
@onready var _character_name: Label = %CharacterName
@onready var _preview_sprite: AnimatedSprite2D = %Sprite

## Popup cài đặt, dựng 1 lần rồi ẩn/hiện (không đổi scene -> không mất nhạc).
var _settings_overlay: Control
## Popup đổi nhân vật, dựng 1 lần rồi ẩn/hiện.
var _character_overlay: Control
## Panel chọn ải. Bấm PLAY ở đây -> mở panel này, không đổi scene.
var _level_overlay: Control


func _ready() -> void:
	_title_label.text = game_title
	# Ẩn nút Thoát trên mobile (không có cách thoát app kiểu desktop).
	_quit_button.visible = not OS.has_feature("mobile")

	_play_button.pressed.connect(_on_play_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_character_button.pressed.connect(_on_character_pressed)

	_refresh_preview()

	# play_music tự bỏ qua nếu stream đang phát, nên gọi lại mỗi lần vào menu
	# không làm cắt nhạc đang chạy.
	AudioManager.play_music(menu_music if menu_music != null else AudioManager.music_from_file("20 - Good Time.ogg"))


## Vẽ animation idle của nhân vật đang chọn lên vùng preview bên phải.
func _refresh_preview() -> void:
	var data: CharacterData = GameManager.selected_character
	_preview_sprite.scale = Vector2(preview_scale, preview_scale)
	if data == null:
		_preview_sprite.sprite_frames = null
		_character_name.text = "-"
		return
	_character_name.text = data.display_name
	_preview_sprite.sprite_frames = data.validated_sprite_frames()
	_preview_sprite.animation = data.animation_or_idle(&"idle")
	_preview_sprite.play()


## Bấm PLAY -> mở panel chọn ải. Không vào thẳng ải nào: người chơi phải tự
## chọn (và ải chưa vượt qua thì vẫn khoá).
## Ải hướng dẫn (Level0) được LevelSelect xử lý khi bấm vào ải ở lần đầu.
func _on_play_pressed() -> void:
	AudioManager.play_sfx(&"ui_select")
	if _level_overlay == null:
		_level_overlay = _spawn_overlay(level_select_scene, "LevelSelect")
		if _level_overlay == null:
			return
	_level_overlay.call(&"open")


func _on_settings_pressed() -> void:
	AudioManager.play_sfx(&"ui_select")
	if _settings_overlay == null:
		_settings_overlay = _spawn_settings_overlay()
	if _settings_overlay == null:
		return
	_settings_overlay.call(&"open")


## Dựng Settings.tscn làm CON của MainMenu và bật overlay_mode -> bấm "Đóng"
## chỉ ẩn đi, MainMenu vẫn nguyên.
func _spawn_settings_overlay() -> Control:
	return _spawn_overlay(settings_scene, "Settings")


func _on_character_pressed() -> void:
	AudioManager.play_sfx(&"ui_select")
	if _character_overlay == null:
		_character_overlay = _spawn_overlay(character_select_scene, "CharacterSelect")
		if _character_overlay == null:
			return
		# Đóng cửa sổ thì vẽ lại preview bên phải (người chơi vừa đổi nhân vật).
		_character_overlay.connect(&"closed", _refresh_preview)
	_character_overlay.call(&"open")


## Dựng scene làm CON của MainMenu và bật overlay_mode -> nút "Đóng" chỉ ẩn đi,
## MainMenu vẫn nguyên. Dùng chung cho Settings và CharacterSelect.
func _spawn_overlay(scene_path: String, label: String) -> Control:
	if not ResourceLoader.exists(scene_path):
		push_error("MainMenu: không thấy %s tại '%s'." % [label, scene_path])
		return null
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_error("MainMenu: '%s' không load được." % scene_path)
		return null
	var overlay: Control = packed.instantiate() as Control
	if overlay == null:
		push_error("MainMenu: %s phải là Control." % label)
		return null
	overlay.set(&"overlay_mode", true)
	overlay.visible = false
	# Đặt SAU các nút khác để popup nằm trên cùng.
	add_child(overlay)
	return overlay


func _on_quit_pressed() -> void:
	AudioManager.play_sfx(&"ui_back")
	SaveManager.save()
	get_tree().quit()
