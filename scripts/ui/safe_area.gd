class_name SafeArea
extends RefCounted
## Insets an toàn (trái, trên, phải, dưới) tính trong toạ độ viewport 640x360.
##
## DisplayServer trả toạ độ CỬA SỔ, còn UI Control sống trong VIEWPORT.
## Khi stretch mode = "viewport" + aspect "expand" (đang dùng) hai không gian lệch nhau,
## nên phải quy đổi qua hệ số scale mới dùng được cho Control.
##
## Dùng:
##   var insets: Vector4 = SafeArea.viewport_insets(get_viewport_rect().size)

## Nếu không lấy được safe area (desktop, headless) -> Vector4.ZERO.
const EMPTY: Vector4 = Vector4(0.0, 0.0, 0.0, 0.0)


## Trả Vector4(left, top, right, bottom) theo đơn vị viewport.
static func viewport_insets(viewport_size: Vector2) -> Vector4:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return EMPTY

	var window_size: Vector2 = Vector2(DisplayServer.window_get_size())
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return EMPTY

	var safe_rect := Rect2i(DisplayServer.get_display_safe_area())
	if safe_rect.size.x <= 0 or safe_rect.size.y <= 0:
		return EMPTY

	# Cửa sổ -> viewport.
	var scale_x: float = viewport_size.x / window_size.x
	var scale_y: float = viewport_size.y / window_size.y

	var left: float = maxf(float(safe_rect.position.x) * scale_x, 0.0)
	var top: float = maxf(float(safe_rect.position.y) * scale_y, 0.0)
	var right: float = maxf(viewport_size.x - float(safe_rect.position.x + safe_rect.size.x) * scale_x, 0.0)
	var bottom: float = maxf(viewport_size.y - float(safe_rect.position.y + safe_rect.size.y) * scale_y, 0.0)
	return Vector4(left, top, right, bottom)


## Cùng trên nhưng luôn >= minimum (px), tránh notch nhỏ lún UI vào mép.
static func viewport_insets_min(viewport_size: Vector2, minimum: Vector4 = Vector4(8.0, 8.0, 8.0, 8.0)) -> Vector4:
	var insets: Vector4 = viewport_insets(viewport_size)
	return Vector4(
		maxf(insets.x, minimum.x),
		maxf(insets.y, minimum.y),
		maxf(insets.z, minimum.z),
		maxf(insets.w, minimum.w)
	)


## Canh Control full-rect vào vùng an toàn bằng offset (dùng cho Node2D, không có MarginContainer).
## Chỉ đụng Control đang full-rect; nếu chưa full-rect thì ép trước rồi mới trừ.
static func apply_offsets(control: Control, viewport_size: Vector2 = Vector2.ZERO, minimum: Vector4 = Vector4(8.0, 8.0, 8.0, 8.0)) -> void:
	if control == null:
		return
	var vp: Vector2 = viewport_size
	if vp.x <= 0.0 or vp.y <= 0.0:
		vp = control.get_viewport_rect().size
	var insets: Vector4 = viewport_insets_min(vp, minimum)
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.offset_left += insets.x
	control.offset_top += insets.y
	control.offset_right -= insets.z
	control.offset_bottom -= insets.w