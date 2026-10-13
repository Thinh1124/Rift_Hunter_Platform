class_name UIButton
extends Button
## Nút UI chuẩn của game: luôn >= MIN_TOUCH_SIZE (48x48) trên viewport 640x360.
##
## 48px là ngưỡng chạm tối thiểu trên mobile; nút nhỏ hơn dễ bấm trượt.
## Nút lớn hơn (nút chính, nút full-width) vẫn giữ nguyên kích thước đã đặt.
##
## Dùng `pressed` signal như Button bình thường, không cần biết script:
##   button.pressed.connect(_on_play_pressed)

## Kích thước chạm tối thiểu (px trong không gian viewport 640x360).
const MIN_TOUCH_SIZE: Vector2 = Vector2(48.0, 48.0)


func _init() -> void:
	# KHÔNG set custom_minimum_size ở đây. Godot 4.7 gán property từ .tscn xong
	# mới chạy _init của script -> _init đè mất kích thước người dùng đặt trong
	# Inspector (nút 150x48 bị ép về 48x48, các nút lệch bề rộng theo chữ).
	# Chỉ ép tối thiểu ở _ready(), sau khi scene đã gán xong.
	# Không bật focus bằng bàn phím: trên mobile focus cũng làm nút sáng nhạt
	# dù không hề bấm. Điều hướng bằng cảm ứng, không phải focus ring.
	focus_mode = Control.FOCUS_NONE


func _ready() -> void:
	_enforce_min_size()
	resized.connect(_enforce_min_size)


## custom_minimum_size có thể bị đặt lại từ scene/script sau _init,
## nên ép lại ở _ready và mỗi lần resize.
func _enforce_min_size() -> void:
	var want := Vector2(
		maxf(custom_minimum_size.x, MIN_TOUCH_SIZE.x),
		maxf(custom_minimum_size.y, MIN_TOUCH_SIZE.y)
	)
	if not want.is_equal_approx(custom_minimum_size):
		custom_minimum_size = want