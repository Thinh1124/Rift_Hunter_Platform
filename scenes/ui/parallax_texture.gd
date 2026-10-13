class_name ParallaxTexture
extends TextureRect
## Nền parallax ngang cho menu: texture lặp, tự cuộn và quay vòng vô hạn.
##
## Không dùng ParallaxBackground vì nó cần Camera2D, còn menu là UI thuần Control.
## Dùng 2 bản TextureRect ghép cạnh nhau: khi bản trái lọt hẳn ra ngoài màn hình
## thì đặt lại sang phải -> không bao giờ lộ khoảng trống.

@export_range(0.0, 200.0, 1.0) var speed: float = 12.0
## Cuộn sang trái thay vì sang phải.
@export var reverse: bool = false
@export var autostart: bool = true
## Làm chậm lại khi mở Settings để chữ dễ đọc.
@export_range(0.0, 8.0, 0.1) var idle_speed_scale: float = 0.0

var _running: bool = false
var _offset: float = 0.0
var _second: TextureRect


func _ready() -> void:
	_running = autostart
	# Lặp ngang, không méo khi cửa sổ đổi tỉ lệ.
	stretch_mode = TextureRect.STRETCH_TILE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_second = _make_second()
	if _second != null:
		add_child(_second)


## Bản sao neo full-rect vào CHÍNH NÓ -> size luôn khớp node cha, tự co theo
## cửa sổ. Không chụp `size` một lần trong _ready (lúc đó layout chưa xong,
## size có thể = 0 -> lộ khoảng trống khi cuộn).
func _make_second() -> TextureRect:
	if texture == null:
		return null
	var copy := TextureRect.new()
	copy.name = "ScrollCopy"
	copy.texture = texture
	copy.stretch_mode = TextureRect.STRETCH_TILE
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Dịch đúng 1 ô texture sang phải. Vì cha đã chuyển -_offset, toạ độ
	# toàn cục của bản sao = -_offset + ô, tức lặp liền mạch, và KHÔNG cần
	# cập nhật trong _process.
	var tile := _tile_width()
	copy.offset_left = tile
	copy.offset_right = tile
	return copy


func _tile_width() -> float:
	if texture == null:
		return 0.0
	return maxf(float(texture.get_width()), 1.0)


func _process(delta: float) -> void:
	if not _running or texture == null or _second == null:
		return
	var tile := _tile_width()

	var scale: float = 1.0
	if idle_speed_scale > 0.0 and get_tree().paused:
		scale = idle_speed_scale
	var dir: float = 1.0 if reverse else -1.0
	_offset = fposmod(_offset + speed * scale * delta * dir, tile)

	# Chỉ node cha di chuyển; bản sao đã neo sẵn ở toạ độ cục bộ +1 ô.
	position.x = -_offset


## Dừng/tiếp nền (gọi khi mở popup).
func set_running(value: bool) -> void:
	_running = value
