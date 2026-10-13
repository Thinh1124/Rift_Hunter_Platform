extends Node
## Chuyển cảnh có fade 0.3s. Dùng MỘT ColorRect đen trong CanvasLayer cao nhất.
##
## Mọi lệnh đổi cảnh đi qua đây (GameManager.go_to_level/go_to_menu đã trỏ sang),
## nên không scene nào tự tạo fade riêng -> không đè lên nhau.
##
## CanvasLayer 128 > HUD (5), TouchControls (10): fade luôn nằm trên cùng.

signal transition_started(path: String)
signal transition_finished(path: String)

## 0.3s theo spec. 0 = chuyển cảnh tức thì (vẫn dùng chung hàm).
@export_range(0.0, 2.0, 0.05) var fade_time: float = 0.3
@export var fade_color: Color = Color(0, 0, 0, 1)
@export_range(1, 128, 1) var fade_layer_index: int = 128

var _layer: CanvasLayer
var _rect: ColorRect
var _busy: bool = false


func _ready() -> void:
	# Scene đang pause vẫn phải fade được.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build() -> void:
	if _rect != null:
		return
	_layer = CanvasLayer.new()
	_layer.name = "FadeLayer"
	_layer.layer = fade_layer_index
	add_child(_layer)

	_rect = ColorRect.new()
	_rect.name = "FadeRect"
	_rect.color = fade_color
	# Không nuốt input, không nuốt chạm -> nút bấm dưới fade vẫn an toàn.
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.modulate.a = 0.0
	_rect.visible = false
	_layer.add_child(_rect)


func _ensure_rect() -> void:
	if _rect == null:
		_build()


## true khi đang fade -> gọi change_scene() lần nữa sẽ bị bỏ qua.
func is_transitioning() -> bool:
	return _busy


## Fade ra, đổi cảnh, fade vào. Trả về ngay nếu đang chuyển hoặc path sai.
func change_scene(path: String) -> void:
	if _busy:
		return
	if path.is_empty() or not ResourceLoader.exists(path):
		push_error("SceneTransition: không tồn tại scene '%s'." % path)
		return

	_ensure_rect()
	_busy = true
	transition_started.emit(path)

	# Lưới an toàn: nếu scene cũ còn pause (PauseMenu) hoặc còn slow-mo
	# (GameOver) thì scene mới sẽ vào đứng im / chạy chậm. Bỏ trước khi đổi.
	if get_tree().paused:
		get_tree().paused = false
	if not is_equal_approx(Engine.time_scale, 1.0):
		Engine.time_scale = 1.0
	if AudioManager != null:
		AudioManager.unduck_music()

	await fade_out()
	var err: int = get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneTransition: change_scene_to_file('%s') lỗi mã %d." % [path, err])
	# Chờ 2 frame để scene mới dựng xong rồi mới mở fade -> không lóe trắng.
	await get_tree().process_frame
	await get_tree().process_frame
	transition_finished.emit(path)

	await fade_in()
	_busy = false


## duration < 0 -> dùng fade_time.
func fade_out(duration: float = -1.0) -> void:
	await _fade(_pick(duration), 1.0)


## duration < 0 -> dùng fade_time.
func fade_in(duration: float = -1.0) -> void:
	await _fade(_pick(duration), 0.0)


func _pick(duration: float) -> float:
	return fade_time if duration < 0.0 else maxf(duration, 0.0)


func _fade(duration: float, target_alpha: float) -> void:
	_ensure_rect()
	if _rect == null:
		return
	if duration <= 0.0:
		_rect.modulate.a = target_alpha
		_rect.visible = target_alpha > 0.0
		return

	_rect.visible = true
	var tween := create_tween()
	tween.tween_property(_rect, "modulate:a", target_alpha, duration)
	await tween.finished
	_rect.modulate.a = target_alpha
	_rect.visible = target_alpha > 0.0
