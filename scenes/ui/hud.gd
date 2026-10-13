class_name GameHUD
extends CanvasLayer
## HUD trong màn chơi: tim/mạng, điểm, cổng, trái cây, thanh boss, nút pause.
##
## Mọi cập nhật đến từ EventBus, không đọc trực tiếp Player/Enemy.
## Riêng trạng thái BAN ĐẦU đọc từ GameManager + group, vì tín hiệu có thể đã
## phát trước khi HUD kịp _ready (Player._ready chạy trước HUD trong scene).
##
## CỐ TÌNH: HUD chỉ chiếm dải TRÊN màn hình. TouchControls nằm ở hai góc dưới
## nên phần giữa dưới (BossBar) đặt ngay dưới dải trên, không lấn vùng chạm.

## Số chữ số tối đa của label điểm ("000000").
@export_range(4, 10, 1) var score_digits: int = 6
## Thời gian đếm điểm tăng dần (giây).
@export_range(0.05, 2.0, 0.05) var score_roll_time: float = 0.3
## Đủ GameManager.SHARDS_REQUIRED shard mới báo mở cổng ra.
@export var gates_open_text: String = "Exit open!"
## Chờ bao lâu sau boss chết mới ẩn thanh (giây).
@export_range(0.0, 3.0, 0.05) var boss_hide_delay: float = 1.0

# %Tên = unique name trong HUD.tscn -> đổi cây node không làm hỏng script.
@onready var hearts_box: PipRow = %HeartsBox
@onready var score_label: Label = %ScoreLabel
@onready var gates_icon: TextureRect = %GatesIcon
@onready var gates_label: Label = %GatesLabel
@onready var shard_icon: TextureRect = %ShardIcon
@onready var shard_label: Label = %ShardLabel
@onready var pause_button: Button = %PauseButton
@onready var boss_bar: TextureProgressBar = %BossBar
@onready var boss_label: Label = %BossLabel

## Màu nhấp nháy khi đã mở hết cổng.
const FLASH_COLOR: Color = Color(0.35, 1.0, 0.45)
const GATES_CLOSED_COLOR: Color = Color(0.925, 0.784, 0.557, 1)

var _pause_menu: CanvasLayer
var _max_hp: int = 1
var _score: int = 0
var _score_shown: float = 0.0
var _score_tween: Tween
var _flash_tween: Tween
var _boss_tween: Tween


func _ready() -> void:
	add_to_group(&"hud")

	score_label.text = _format_score(0)
	gates_icon.texture = UIIcons.get_icon(UIIcons.GATE)
	shard_icon.texture = UIIcons.shard_icon(14)
	boss_bar.visible = false
	# Phải ẩn CẢ nhãn "BOSS", không chỉ thanh: nếu không chữ hồng sẽ hiện ở
	# mọi ải, cạnh một thanh vô hình.
	boss_label.visible = false
	boss_bar.texture_under = UIIcons.progress_background()

	# Pause chạy cả khi game pause (nút phải bấm được khi đang tạm dừng).
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_button.pressed.connect(_on_pause_pressed)

	EventBus.player_hp_changed.connect(_on_hp_changed)
	EventBus.score_changed.connect(_on_score_changed)
	EventBus.gates_changed.connect(_on_gates_changed)
	EventBus.shards_changed.connect(_on_shards_changed)
	EventBus.boss_hp_changed.connect(_on_boss_hp_changed)
	EventBus.boss_defeated.connect(_on_boss_defeated)

	_sync_initial_state()


## Đọc trạng thái hiện tại từ GameManager/group cho trường hợp đã lỡ mất tín hiệu.
##
## CỐ TÌNH KHÔNG sync cổng ở đây: _ready của node CHẠY TRƯỚC _ready của LevelBase,
## lúc đó GameManager còn mang số cổng của ải TRƯỚC -> HUD nháy xanh
## "Mo cong thoat!" rồi mới đúng. GameManager.register_gates() luôn phát
## gates_changed ngay sau đó nên không cần đồng bộ thủ công.
func _sync_initial_state() -> void:
	_on_shards_changed(GameManager.shard_count, GameManager.SHARDS_REQUIRED)
	# Điểm đặt THẲNG, không qua tween: đồng bộ trạng thái không phải chuyển
	# động, tween 0.3s sẽ khiến chữ sai ngay frame đầu.
	_score = maxi(GameManager.score, 0)
	_score_shown = float(_score)
	_set_score_text(_score_shown)

	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player != null and player.health != null:
		_on_hp_changed(player.health.current, player.health.max_health)

	var boss := get_tree().get_first_node_in_group(&"boss")
	var boss_hp := _health_of(boss)
	if boss_hp != null:
		_on_boss_hp_changed(boss_hp.current, boss_hp.max_health)


## Boss/Player đều có field `health: HealthComponent` -> đọc bằng get() cho an toàn.
func _health_of(node: Node) -> HealthComponent:
	if node == null:
		return null
	return node.get(&"health") as HealthComponent


# --- Tim / mạng -------------------------------------------------------------

## 1 tim = 1 điểm máu. Số tim bằng đúng max_hp của NHÂN VẬT ĐANG CHỌN
## (mỗi người một max_hp khác nhau qua CharacterData.max_hp_bonus), nên nhìn
## HUD là biết còn bao nhiêu máu mà không cần đọc số.
##
## max_hp có thể lên tới 5+ (Virtual Guy +2) -> hàng tim dài hơn ô 48px của nút
## pause một chút, nhưng nằm trong `Left` (HBox co giãn) nên không bị cắt.
func _on_hp_changed(cur: int, maximum: int) -> void:
	_max_hp = maxi(maximum, 1)
	var filled: int = clampi(cur, 0, _max_hp)
	var icons: Array[Texture2D] = []
	for _i in _max_hp:
		icons.append(UIIcons.get_icon(UIIcons.HEART))
	hearts_box.set_items(icons, filled)


# --- Điểm -------------------------------------------------------------------

## Điểm đếm tăng dần trong score_roll_time thay vì nhảy thẳng cho khỏi giật.
## Điểm đếm tăng dần trong score_roll_time. Không await: signal có thể đến dồn khi
## nhặt nhiều trái cây liên tiếp, await sẽ để mấy tween chồng lên nhau.
func _on_score_changed(value: int) -> void:
	_score = maxi(value, 0)
	if _score_tween != null and _score_tween.is_valid():
		_score_tween.kill()
	_score_tween = create_tween()
	_score_tween.tween_method(_set_score_text, _score_shown, float(_score), score_roll_time)
	_score_tween.tween_callback(_snap_score)


## Tween bị kill giữa chừng (điểm vừa tăng tiếp) -> chốt lại số đúng, tránh
## điểm dừng lệch ở giá trị cũ.
func _snap_score() -> void:
	_score_shown = float(_score)
	_set_score_text(_score_shown)


func _set_score_text(value: float) -> void:
	_score_shown = value
	score_label.text = _format_score(roundi(value))


## Điểm luôn hiện đủ score_digits chữ số ("000120"), dễ so mà không phải tới.
func _format_score(value: int) -> String:
	return str(absi(value)).pad_zeros(score_digits)


# --- Cổng -------------------------------------------------------------------

## Đủ shard -> chữ xanh + nhấp nháy thông báo cổng ra đã mở.
func _on_gates_changed(remaining: int, total: int) -> void:
	var done: bool = GameManager.shards_complete()
	if done:
		gates_label.text = gates_open_text
		gates_label.add_theme_color_override(&"font_color", FLASH_COLOR)
		_start_flash()
	else:
		gates_label.text = "Gates %d/%d" % [remaining, total]
		gates_label.add_theme_color_override(&"font_color", GATES_CLOSED_COLOR)
		_stop_flash()


func _start_flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween().set_loops()
	_flash_tween.tween_property(gates_label, "modulate:a", 0.25, 0.4)
	_flash_tween.tween_property(gates_label, "modulate:a", 1.0, 0.4)


func _stop_flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	gates_label.modulate.a = 1.0


# --- Mảnh Rift --------------------------------------------------------------

## Hiển thị số shard đã thu trên tổng số cần để mở cổng cuối màn.
func _on_shards_changed(collected: int, required: int) -> void:
	shard_label.text = "%d/%d" % [collected, required]
	_on_gates_changed(GameManager.remaining_gates, GameManager.total_gates)


# --- Boss -------------------------------------------------------------------

## maximum <= 0 nghĩa là không có boss thật -> không hiện thanh.
## boss.gd phát boss_hp_changed ngay trong _ready với cur == max (máu đầy), nên
## thanh hiện sẵn khi vào ải boss, đúng ý "hiện BossBar lần đầu".
func _on_boss_hp_changed(cur: int, maximum: int) -> void:
	if maximum <= 0:
		return
	boss_bar.max_value = maximum
	boss_bar.value = clampi(cur, 0, maximum)
	boss_label.visible = true
	boss_bar.visible = true


## Giữ thanh thêm boss_hide_delay giây rồi ẩn, để người chơi thấy boss đã gục.
func _on_boss_defeated() -> void:
	if _boss_tween != null and _boss_tween.is_valid():
		_boss_tween.kill()
	_boss_tween = create_tween()
	_boss_tween.tween_interval(boss_hide_delay)
	_boss_tween.tween_callback(_hide_boss)


func _hide_boss() -> void:
	boss_bar.visible = false
	boss_label.visible = false


# --- Pause ------------------------------------------------------------------

## Nút pause trên HUD, hoặc phím pause (Esc/P) -> cùng một menu.
## PauseMenu là CanvasLayer riêng (layer 20), tìm qua group "pause_menu".
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		_on_pause_pressed()


## KHÔNG dùng toggle() ở đây. Cả HUD và PauseMenu đều bắt action "pause", nên
## nếu cả hai cùng chạy (thứ tự truyền input đổi, menu bị spawn muộn...) thì
## toggle sẽ đóng xong lại mở -> kẹt. Thay vào đó: đang mở thì ĐÓNG, đang đóng
## thì MỞ. Như vậy cả 2 handler chạy cùng lúc vẫn ra kết quả "đóng".
func _on_pause_pressed() -> void:
	if _pause_menu == null:
		_pause_menu = _find_pause_menu()
	if _pause_menu == null:
		push_error("GameHUD: không tìm thấy PauseMenu trong group 'pause_menu'.")
		return
	if _pause_menu.visible:
		_pause_menu.call(&"close")
		return
	AudioManager.play_sfx(&"ui_select")
	_pause_menu.call(&"open")


func _find_pause_menu() -> CanvasLayer:
	return get_tree().get_first_node_in_group(&"pause_menu") as CanvasLayer
