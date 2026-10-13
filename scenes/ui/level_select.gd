extends Control
## Panel chọn ải 3x2, căn giữa màn hình. Mỗi ô là 1 bản sao LevelSlot.tscn
## (nhân bản từ @export slot_scene), script chỉ truyền số ải + trạng thái save,
## phần còn lại do ô lo.
##
## Quy tắc khoá: ải N chỉ mở khi đã VƯỢT QUA ải N-1. SaveManager.unlocked_level
## chỉ tăng trong GameManager._on_level_completed -> SaveManager.unlock(), nên
## chỉ vượt qua mới mở khoá được ải kế tiếp. Ô khoá: tối màu + ổ khoá và KHÔNG
## nối `pressed` -> không bấm được.
##
## Lần đầu vào game: bấm ải bất kỳ sẽ chạy ải hướng dẫn (Level0) trước.
##
## Thêm ải mới: thêm LevelN.tscn + GameManager.LEVEL_COUNT, ảnh lấy tự động
## theo số ải (res://assets/Menu/Levels/NN.png).

## Phát khi panel đóng (nút BACK khi đang là overlay).
signal closed

@export var main_menu_scene: String = "res://scenes/ui/MainMenu.tscn"
@export var slot_scene: PackedScene = preload("res://scenes/ui/LevelSlot.tscn")
@export_range(1, 6, 1) var columns: int = 3
## true  -> MainMenu nhét làm CON, BACK chỉ ẩn panel đi.
## false -> chạy như scene chính, BACK về MainMenu (mặc định).
@export var overlay_mode: bool = false

@onready var _grid: GridContainer = %Grid
@onready var _back_button: UIButton = %BackButton


func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	refresh()


## Mở lại thì đọc save mới nhất (sau khi vừa thắng ải) để sao cập nhật ngay.
func open() -> void:
	refresh()
	visible = true


## Dựng lại lưới từ save hiện tại. Gọi lại sau khi đổi save để cập nhật ngay.
func refresh() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()

	_grid.columns = maxi(columns, 1)
	for level in range(1, GameManager.LEVEL_COUNT + 1):
		var unlocked: bool = level <= SaveManager.unlocked_level
		var stars: int = SaveManager.get_stars(level)
		var slot := slot_scene.instantiate() as LevelSlot
		# `played` = đã từng vượt qua. Màn chưa chơi hiện 3 sao rỗng trông như
		# "đã thua 0/3" — ẩn hẳn cho tới khi có kết quả.
		var played: bool = SaveManager.is_level_completed(level)
		slot.setup(level, unlocked, level == GameManager.BOSS_LEVEL, stars, played)
		# Ô khoá: KHÔNG nối pressed -> không đường nào bấm vào được
		# (LevelSlot._apply() cũng đặt disabled = true).
		if unlocked:
			slot.pressed.connect(_on_level_pressed.bind(level))
		_grid.add_child(slot)


func _on_level_pressed(level: int) -> void:
	# Chặn lần nữa ở đây: không phụ thuộc việc scene có nối signal hay không.
	if level > SaveManager.unlocked_level:
		push_warning("LevelSelect: ảnh %d vẫn khoá." % level)
		return
	AudioManager.play_sfx(&"ui_select")
	GameManager.reset_run()
	# Lần đầu vào game -> chạy ải hướng dẫn (Level0) cho biết di chuyển, đánh
	# quái, checkpoint và cách qua cổng. Xong ải đó SaveManager tự đánh dấu.
	if SaveManager.needs_tutorial():
		GameManager.go_to_level(GameManager.TUTORIAL_LEVEL)
		return
	# go_to_level chỉ vào chơi, không mở khoá: ải kế tiếp chỉ mở khi thắng ải này.
	GameManager.go_to_level(level)


func _on_back_pressed() -> void:
	AudioManager.play_sfx(&"ui_back")
	if overlay_mode:
		visible = false
		closed.emit()
		return
	SceneTransition.change_scene(main_menu_scene)