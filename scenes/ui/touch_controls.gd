class_name TouchControls
extends CanvasLayer
## Nút ảo đa chạm cho mobile. Dùng TouchScreenButton nên giữ Right + bấm Jump
## cùng lúc vẫn hoạt động (mỗi nút giữ 1 touch index riêng).
##
## TouchScreenButton là Node2D nên KHÔNG tự layout trong Control -
## vị trí được tính tay trong _layout() để trừ safe area.

## Settings tìm nút ảo qua group này để kéo slider là đổi ngay (không cần
## biết đường dẫn node), theo quy ước giao tiếp bằng group của AGENTS.md.
const GROUP: StringName = &"touch_controls"

@export_group("Visibility")
## true = hiện cả trên desktop (để test).
@export var show_on_desktop: bool = false
## true = ép hiện, bỏ qua cả show_on_desktop.
@export var force_visible: bool = false

@export_group("Look")
## Nạp từ SaveManager.touch_opacity lúc vào scene, đổi lại qua set_opacity().
@export_range(0.0, 1.0, 0.05) var opacity: float = 0.5
## Nạp từ SaveManager.touch_scale lúc vào scene, đổi lại qua set_button_scale().
@export_range(0.5, 2.0, 0.05) var button_scale: float = 1.0

@export_group("Layout")
@export var edge_margin: float = 24.0
@export var button_gap: float = 16.0
@export var move_button_size: float = 56.0
@export var jump_button_size: float = 64.0
@export var attack_button_size: float = 56.0
@export var interact_button_size: float = 48.0

# %Tên = unique name trong TouchControls.tscn -> không phụ thuộc đường dẫn node.
@onready var _left: TouchScreenButton = %Left
@onready var _right: TouchScreenButton = %Right
@onready var _jump: TouchScreenButton = %Jump
@onready var _attack: TouchScreenButton = %Attack
@onready var _interact: TouchScreenButton = %Interact

var _buttons: Array[TouchScreenButton] = []


func _ready() -> void:
	layer = 10
	add_to_group(GROUP)
	_buttons = [_left, _right, _jump, _attack, _interact]
	_read_look_from_save()
	_build_buttons()
	visible = _should_show()
	_layout()
	if not get_viewport().size_changed.is_connected(_layout):
		get_viewport().size_changed.connect(_layout)


func _should_show() -> bool:
	if force_visible or show_on_desktop:
		return true
	return OS.has_feature("mobile")


## Nạp độ mờ + kích thước nút ảo đã lưu. SaveManager đứng trước scene này
## trong autoload nên lúc _ready() save đã có giá trị.
func _read_look_from_save() -> void:
	opacity = clampf(SaveManager.touch_opacity, 0.0, 1.0)
	button_scale = clampf(SaveManager.touch_scale, 0.5, 2.0)


# --- Dựng nút --------------------------------------------------------------

func _build_buttons() -> void:
	# Màu đủ đậm để nhìn rõ trên nền sáng; viền sáng lên ở rìa nút.
	_setup(_left, move_button_size, Color(0.38, 0.50, 0.72))
	_setup(_right, move_button_size, Color(0.38, 0.50, 0.72))
	_setup(_jump, jump_button_size, Color(0.28, 0.76, 0.36))
	_setup(_attack, attack_button_size, Color(0.86, 0.30, 0.22))
	_setup(_interact, interact_button_size, Color(0.28, 0.56, 0.90))


func _setup(button: TouchScreenButton, size: float, tint: Color) -> void:
	# Godot 4: TouchScreenButton chỉ có shape / shape_centered / texture_*,
	# không có normal_offset (đó là API Godot 3).
	# shape_centered = true -> shape canh giữa texture, position của node là góc trên-trái.
	var circle := CircleShape2D.new()
	circle.radius = size * 0.5
	button.shape = circle
	button.shape_centered = true
	button.texture_normal = _circle_texture(size, tint)
	button.texture_pressed = _circle_texture(size, tint.lightened(0.38))
	button.visibility_mode = 0  # 0 = Always (enum của TouchScreenButton chưa export tên)
	button.modulate.a = opacity


## Hình tròn placeholder vẽ bằng code (chưa có icon).
func _circle_texture(size: float, tint: Color) -> ImageTexture:
	var px: int = maxi(int(round(size)), 8)
	var image := Image.create_empty(px, px, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := Vector2(float(px) * 0.5, float(px) * 0.5)
	var r_outer: float = float(px) * 0.5 - 1.0
	var r_inner: float = r_outer - 2.0
	var rim: Color = tint.lightened(0.55)
	for y in px:
		for x in px:
			var d: float = Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(center)
			if d <= r_inner:
				image.set_pixel(x, y, tint)
			elif d <= r_outer:
				image.set_pixel(x, y, rim)
	return ImageTexture.create_from_image(image)


# --- Bố cục ---------------------------------------------------------------

func _layout() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return
	var safe: Vector4 = SafeArea.viewport_insets(vp)
	var left: float = safe.x + edge_margin
	var bottom: float = vp.y - safe.z - edge_margin
	var right: float = vp.x - safe.w - edge_margin

	var move: float = maxf(move_button_size * button_scale, UIButton.MIN_TOUCH_SIZE.x)
	_left.position = Vector2(left, bottom - move)
	_right.position = Vector2(left + move + button_gap, bottom - move)
	_left.scale = Vector2.ONE * button_scale
	_right.scale = Vector2.ONE * button_scale

	var jump: float = maxf(jump_button_size * button_scale, UIButton.MIN_TOUCH_SIZE.x)
	var attack: float = maxf(attack_button_size * button_scale, UIButton.MIN_TOUCH_SIZE.x)
	var interact: float = maxf(interact_button_size * button_scale, UIButton.MIN_TOUCH_SIZE.x)
	var jump_pos := Vector2(right - jump, bottom - jump)
	_attack.position = Vector2(jump_pos.x - button_gap - attack, jump_pos.y + (jump - attack) * 0.5)
	_interact.position = Vector2(_attack.position.x + (attack - interact) * 0.5,
		_attack.position.y - button_gap - interact)
	_jump.position = jump_pos
	_jump.scale = Vector2.ONE * button_scale
	_attack.scale = Vector2.ONE * button_scale
	_interact.scale = Vector2.ONE * button_scale


# --- Tiện ích cho test / debug ---------------------------------------------

## Tâm nút trong toạ độ viewport - dùng để test đa chạm.
func button_center(action: StringName) -> Vector2:
	var button: TouchScreenButton = null
	match action:
		&"move_left": button = _left
		&"move_right": button = _right
		&"jump": button = _jump
		&"attack": button = _attack
		&"interact": button = _interact
	if button == null:
		return Vector2.ZERO
	var size: float = _button_size_for(action)
	return button.global_position + Vector2(size, size) * 0.5


## Cùng phép clamp với _layout(), nếu không tâm nút trả về sẽ lệch với
## vị trí vẽ thật khi export value < 48.
func _button_size_for(action: StringName) -> float:
	var raw: float = 0.0
	match action:
		&"move_left", &"move_right": raw = move_button_size
		&"jump": raw = jump_button_size
		&"attack": raw = attack_button_size
		&"interact": raw = interact_button_size
		_: return 0.0
	return maxf(raw * button_scale, UIButton.MIN_TOUCH_SIZE.x)


## Settings gọi khi kéo slider "Độ mờ nút ảo": đổi ngay cả khi cây đang pause
## (gọi hàm trực tiếp, không qua signal).
func set_opacity(value: float) -> void:
	opacity = clampf(value, 0.0, 1.0)
	for button: TouchScreenButton in _buttons:
		button.modulate.a = opacity


## Settings gọi khi kéo slider "Kích thước nút ảo". _layout() tính lại vị trí
## vì _layout() tự nhân với button_scale.
func set_button_scale(value: float) -> void:
	button_scale = clampf(value, 0.5, 2.0)
	_layout()
