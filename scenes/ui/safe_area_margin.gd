class_name SafeAreaMargin
extends MarginContainer
## MarginContainer tự trừ safe area (DisplayServer.get_display_safe_area).
##
## Thay vì mỗi scene tự tính tay: bọc 1 node này quanh UI, các con tự nằm trong
## vùng an toàn. Cập nhật lại khi viewport đổi kích thước (xoay màn hình, resize).
##
## Margin tối thiểu luôn >= MIN_MARGIN để UI không dồn sát mép trên desktop.

@export var safe_area_enabled: bool = true
@export_range(0, 64, 1) var extra_margin: int = 0

const MIN_MARGIN: int = 8


func _ready() -> void:
	# Không nuốt chạm: SafeAreaMargin chỉ lề, con bên trong tự xử lý input.
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(_update_margins)
	if not get_viewport().size_changed.is_connected(_update_margins):
		get_viewport().size_changed.connect(_update_margins)
	call_deferred(&"_update_margins")


func _update_margins() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var insets: Vector4 = Vector4(MIN_MARGIN, MIN_MARGIN, MIN_MARGIN, MIN_MARGIN)
	if safe_area_enabled:
		insets = SafeArea.viewport_insets_min(vp, Vector4(MIN_MARGIN, MIN_MARGIN, MIN_MARGIN, MIN_MARGIN))

	add_theme_constant_override(&"margin_left", roundi(insets.x) + extra_margin)
	add_theme_constant_override(&"margin_top", roundi(insets.y) + extra_margin)
	add_theme_constant_override(&"margin_right", roundi(insets.z) + extra_margin)
	add_theme_constant_override(&"margin_bottom", roundi(insets.w) + extra_margin)