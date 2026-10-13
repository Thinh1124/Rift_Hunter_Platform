class_name TouchControls
extends CanvasLayer
## Nút ảo đa chạm cho mobile. Dùng TouchScreenButton nên giữ Right + bấm Jump
## cùng lúc vẫn hoạt động (mỗi nút giữ 1 touch index riêng).
##
## TouchScreenButton là Node2D nên KHÔNG tự layout trong Control -
## vị trí được tính tay trong _layout() để trừ safe area.

@export_group("Visibility")
## true = hiện cả trên desktop (để test).
@export var show_on_desktop: bool = false
## true = ép hiện, bỏ qua cả show_on_desktop.
@export var force_visible: bool = false

@export_group("Look")
## Đọc từ SaveManager.touch_opacity nếu property đó tồn tại.
@export_range(0.0, 1.0, 0.05) var opacity: float = 0.5
@export_range(0.5, 2.0, 0.05) var button_scale: float = 1.0

@export_group("Layout")
@export var edge_margin: float = 24.0
@export var button_gap: float = 16.0
@export var move_button_size: float = 56.0
@export var jump_button_size: float = 64.0
@export var attack_button_size: float = 56.0
@export var interact_button_size: float = 48.0

@onready var _root: Control = $Root
@onready var _left: TouchScreenButton = $Root/Left
@onready var _right: TouchScreenButton = $Root/Right
@onready var _jump: TouchScreenButton = $Root/Jump
@onready var _attack: TouchScreenButton = $Root/Attack
@onready var _interact: TouchScreenButton = $Root/Interact


func _ready() -> void:
	layer = 10
	_read_opacity_from_save()
	_build_buttons()
	visible = _should_show()
	_layout()
	if not get_viewport().size_changed.is_connected(_layout):
		get_viewport().size_changed.connect(_layout)


func _should_show() -> bool:
	if force_visible or show_on_desktop:
		return true
	return OS.has_feature("mobile")


## SaveManager chưa có touch_opacity thì get() trả null -> giữ giá trị export.
func _read_opacity_from_save() -> void:
	if "touch_opacity" in SaveManager:
		var value: Variant = SaveManager.get(&"touch_opacity")
		if value is float or value is int:
			opacity = clampf(float(value), 0.0, 1.0)


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
	var safe: Vector4 = _safe_area(vp)
	var left: float = safe.x + edge_margin
	var bottom: float = vp.y - safe.z - edge_margin
	var right: float = vp.x - safe.w - edge_margin

	var move: float = move_button_size * button_scale
	_left.position = Vector2(left, bottom - move)
	_right.position = Vector2(left + move + button_gap, bottom - move)
	_left.scale = Vector2.ONE * button_scale
	_right.scale = Vector2.ONE * button_scale

	var jump: float = jump_button_size * button_scale
	var attack: float = attack_button_size * button_scale
	var interact: float = interact_button_size * button_scale
	var jump_pos := Vector2(right - jump, bottom - jump)
	_attack.position = Vector2(jump_pos.x - button_gap - attack, jump_pos.y + (jump - attack) * 0.5)
	_interact.position = Vector2(_attack.position.x + (attack - interact) * 0.5,
		_attack.position.y - button_gap - interact)
	_jump.position = jump_pos
	_jump.scale = Vector2.ONE * button_scale
	_attack.scale = Vector2.ONE * button_scale
	_interact.scale = Vector2.ONE * button_scale


## Insets an toàn ( trái, trên, phải, dưới ) tính trong không gian viewport.
func _safe_area(vp: Vector2) -> Vector4:
	var window: Vector2 = Vector2(DisplayServer.window_get_size())
	if window.x <= 0.0 or window.y <= 0.0:
		return Vector4.ZERO
	var rect := Rect2i(DisplayServer.get_display_safe_area())
	if rect.size.x <= 0 or rect.size.y <= 0:
		return Vector4.ZERO
	var sx: float = vp.x / window.x
	var sy: float = vp.y / window.y
	var inset_left: float = maxf(float(rect.position.x) * sx, 0.0)
	var inset_top: float = maxf(float(rect.position.y) * sy, 0.0)
	var inset_right: float = maxf(vp.x - float(rect.position.x + rect.size.x) * sx, 0.0)
	var inset_bottom: float = maxf(vp.y - float(rect.position.y + rect.size.y) * sy, 0.0)
	return Vector4(inset_left, inset_top, inset_right, inset_bottom)


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
	return button.global_position + Vector2(size, size) * 0.5 * button_scale


func _button_size_for(action: StringName) -> float:
	match action:
		&"move_left", &"move_right": return move_button_size
		&"jump": return jump_button_size
		&"attack": return attack_button_size
		&"interact": return interact_button_size
	return 0.0


func set_opacity(value: float) -> void:
	opacity = clampf(value, 0.0, 1.0)
	for button: TouchScreenButton in [_left, _right, _jump, _attack, _interact]:
		button.modulate.a = opacity
