extends Control
## Scene khởi động (main scene): logo fade-in -> giữ -> fade-out, rồi vào MainMenu.
##
## Timeline tổng 1.5s:
##   0.0s  logo bắt đầu hiện (alpha 0)
##   0.5s  logo hiện hết, giữ nguyên 0.5s (đọc save + nạp scene trong lúc này)
##   1.5s  logo mờ hết -> SceneTransition.change_scene(MainMenu)
##
## SaveManager đã tự load_data() trong _ready của nó, nhưng Boot gọi lại để chắc
## chắn (nếu save bị sửa ngoài lúc chạy) và đúng theo spec: load + preload scene
## diễn ra TRONG lúc logo đang chạy.

## Tên game hiện ở logo. Đổi text trong Inspector, không cần sửa scene.
@export var game_title: String = "SPACE BUNNY"
## Scene đích, nạp sẵn trong lúc chờ để vào game không bị giật.
@export var main_menu_scene: String = "res://scenes/ui/MainMenu.tscn"

@export_group("Timing")
@export_range(0.0, 3.0, 0.05) var logo_fade_time: float = 0.5
@export_range(0.0, 3.0, 0.05) var logo_hold_time: float = 0.5

@onready var _logo: Label = %Logo
@onready var _bar: ProgressBar = %LoadBar

var _menu_scene: PackedScene
var _done: bool = false


func _ready() -> void:
	_logo.text = game_title
	# Bắt đầu ẩn hẳn rồi mới fade lên, tránh 1 frame nháy logo.
	_logo.modulate.a = 0.0
	_bar.value = 0.0
	_run()


func _run() -> void:
	# 1) Logo vào -> giữ -> ra.
	var total: float = logo_fade_time * 2.0 + logo_hold_time
	var tween := create_tween()
	tween.tween_property(_logo, "modulate:a", 1.0, logo_fade_time)
	tween.tween_interval(logo_hold_time)
	tween.tween_property(_logo, "modulate:a", 0.0, logo_fade_time)

	# 2) Thanh giả tải chạy song song.
	_bar.max_value = maxf(total, 0.001)
	var bar_tween := create_tween()
	bar_tween.tween_property(_bar, "value", total, total)

	# 3) Trong lúc đó: đọc save + nạp sẵn scene menu.
	SaveManager.load_data()
	_menu_scene = _preload_menu()

	# 4) Chờ hết timeline rồi mới chuyển.
	await tween.finished
	await bar_tween.finished
	_go_to_menu()


func _preload_menu() -> PackedScene:
	if not ResourceLoader.exists(main_menu_scene):
		push_error("Boot: không thấy MainMenu tại '%s'." % main_menu_scene)
		return null
	var packed: Resource = load(main_menu_scene)
	if packed is PackedScene:
		return packed
	push_error("Boot: '%s' không phải PackedScene." % main_menu_scene)
	return null


## Menu có load xong không - MainMenu nên báo lỗi nếu scene hỏng.
func menu_loaded() -> bool:
	return _menu_scene != null


func _go_to_menu() -> void:
	if _done:
		return
	_done = true
	# SceneTransition tự fade 0.3s + đổi cảnh, không cần fade thêm ở đây.
	SceneTransition.change_scene(main_menu_scene)