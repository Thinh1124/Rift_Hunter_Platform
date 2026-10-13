extends Control
## Popup cài đặt. Mọi thay đổi áp dụng NGAY và ghi vào SaveManager.
##
## process_mode = ALWAYS nên bấm được cả khi cây đang pause (mở từ PauseMenu).
##
## Dùng được ở 2 kiểu:
##   overlay_mode = true  -> MainMenu / PauseMenu nhét scene này làm CON,
##                          bấm "Đóng" chỉ ẩn đi (không đổi scene, không mất
##                          nhạc đang phát, không mất tiến độ ải).
##   overlay_mode = false -> chạy như scene chính (mặc định), "Đóng" về MainMenu.
##
## Menu chủ gọi open() / close() qua signal `closed` - KHÔNG dùng đường dẫn node.
signal closed

@export var main_menu_scene: String = "res://scenes/ui/MainMenu.tscn"
@export var reset_confirm: bool = false
## true = đóng bằng cách ẩn, không đổi scene.
@export var overlay_mode: bool = false

## Rung thử khi bật CheckButton "Rung" (ms).
const VIBRATE_PREVIEW_MS: int = 200

@onready var _music_slider: HSlider = %MusicSlider
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _vibration_check: CheckButton = %VibrationCheck
@onready var _touch_opacity_slider: HSlider = %TouchOpacitySlider
@onready var _touch_scale_slider: HSlider = %TouchScaleSlider
@onready var _close_button: UIButton = %CloseButton
@onready var _reset_button: Button = %ResetButton

## Nút ảo đang có trong cây (mở Settings từ PauseMenu thì nằm trong ải hiện tại).
## Lấy qua group, không đoán đường dẫn node. Có thể null (ở MainMenu).
var _touch_controls: TouchControls


## Nút ảo hiện tại, tự dò lại nếu cache rỗng.
##
## KHÔNG được chỉ dò 1 lần ở _ready(): _ready của Settings có thể chạy TRƯỚC
## _ready của TouchControls (thứ tự node trong scene), lúc đó TouchControls chưa
## add_to_group -> dò ra null và 2 slider nút ảo sẽ chết lặng lẽ. Dò lại mỗi
## lần dùng để không phụ thuộc thứ tự, cũng xử lý được cả lúc đổi ải.
func _touch() -> TouchControls:
	if _touch_controls != null and is_instance_valid(_touch_controls):
		return _touch_controls
	_touch_controls = get_tree().get_first_node_in_group(TouchControls.GROUP) as TouchControls
	return _touch_controls


func _ready() -> void:
	# PauseMenu mở popup này khi get_tree().paused = true. Không có ALWAYS thì
	# slider/nút trong đây đứng im, không nhận input.
	process_mode = Node.PROCESS_MODE_ALWAYS

	# value_changed chỉ đổi âm lượng (mượt khi kéo);
	_music_slider.value_changed.connect(_on_music_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_vibration_check.toggled.connect(_on_vibration_toggled)
	_touch_opacity_slider.value_changed.connect(_on_touch_opacity_changed)
	_touch_scale_slider.value_changed.connect(_on_touch_scale_changed)
	_close_button.pressed.connect(_on_close_pressed)
	_reset_button.pressed.connect(_on_reset_pressed)

	# Chỉ hiện nút xóa save khi bật trong Inspector.
	_reset_button.visible = reset_confirm

	_sync_from_save()


## Hiện popup + nạp lại giá trị từ save (hợp l sau khi đổi ở nơi khác).
func open() -> void:
	_sync_from_save()
	visible = true


## Ẩn popup, giữ scene chủ nguyên trạng.
func close() -> void:
	visible = false
	closed.emit()


## Nạp trạng thái từ SaveManager vào control (âm lượng, rung, nút ảo).
func _sync_from_save() -> void:
	# Gán value SAU khi đã nối signal: _on_*_changed sẽ ghi lại đúng giá trị này,
	# nên AudioManager / TouchControls không bị lệch với save.
	_music_slider.value = SaveManager.music_vol
	_sfx_slider.value = SaveManager.sfx_vol
	_vibration_check.button_pressed = SaveManager.vibration
	_touch_opacity_slider.value = SaveManager.touch_opacity
	_touch_scale_slider.value = SaveManager.touch_scale


func _on_music_changed(value: float) -> void:
	AudioManager.set_music_volume(value)
	SaveManager.set_music_volume(value)


func _on_sfx_changed(value: float) -> void:
	AudioManager.set_sfx_volume(value)
	SaveManager.set_sfx_volume(value)


## Thả chuột mới phát 1 tiếng thử.
func _on_vibration_toggled(pressed: bool) -> void:
	SaveManager.set_vibration(pressed)
	# Bật rung -> thử rung luôn 1 lần để người chơi biết máy có rung không.
	# SaveManager.vibration đã cập nhật nên Player._vibrate_hit() dùng ngay giá trị này.
	if pressed:
		Input.vibrate_handheld(VIBRATE_PREVIEW_MS)


## Kéo slider Độ mờ nút ảo -> đổi ngay nút đang hiện (nếu đang ở trong ải).
func _on_touch_opacity_changed(value: float) -> void:
	SaveManager.set_touch_opacity(value)
	var touch := _touch()
	if touch != null:
		touch.set_opacity(value)


## Kéo slider Kích thước nút ảo -> nút to/nhỏ + bố cục tính lại ngay.
func _on_touch_scale_changed(value: float) -> void:
	SaveManager.set_touch_scale(value)
	var touch := _touch()
	if touch != null:
		touch.set_button_scale(value)


func _on_reset_pressed() -> void:
	# reset_save() nạp lại từ disk -> tiến độ, sao, âm lượng, cài đặt về mặc định.
	SaveManager.reset_save()
	AudioManager.set_music_volume(SaveManager.music_vol)
	AudioManager.set_sfx_volume(SaveManager.sfx_vol)
	var touch := _touch()
	if touch != null:
		touch.set_opacity(SaveManager.touch_opacity)
		touch.set_button_scale(SaveManager.touch_scale)
	_sync_from_save()


func _on_close_pressed() -> void:
	# Lưu khi đóng: kéo xong tắt luôn game cũng không mất cài đặt.
	SaveManager.save()
	if overlay_mode:
		close()
		return
	SceneTransition.change_scene(main_menu_scene)


func _unhandled_input(event: InputEvent) -> void:
	# Bấm pause đóng popup, nhưng CHỈ khi nó đang hiện.
	if overlay_mode and visible and event.is_action_pressed(&"pause"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()
