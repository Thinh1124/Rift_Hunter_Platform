class_name LevelSlot
extends Button
## Ô chọn 1 màn trong LevelSelect. LevelSelect chỉ nhân bản LevelSlot.tscn,
## cây node (Icon / Number / Stars / Badge) khai báo sẵn trong .tscn.
##
## Script chỉ đổi nội dung: ảnh màn, số màn, sao đã thắng, ổ khoá, viền.
##
## Ảnh màn: res://assets/Menu/Levels/NN.png (19x17 px, NN = 01..06).
## Thiếu ảnh -> ô chỉ hiện số màn, không báo lỗi.

const ICON_DIR: String = "res://assets/Menu/Levels"
const NUMBER_OPEN: Color = Color(0.85, 0.92, 1.0, 1)
const NUMBER_LOCKED: Color = Color(0.45, 0.48, 0.55, 1)
# Ô không tự vẽ StyleBox: nền / viền / padding lấy từ theme.
# Trạng thái ô phân biệt bằng modulate cho hợp với MỌI theme
# (kể cả 9-slice StyleBoxTexture không tô viền được).
const TINT_OPEN: Color = Color(1, 1, 1, 1)
const TINT_BOSS: Color = Color(1.0, 0.68, 0.68, 1)
## Ô khoá tối hơn nữa: ảnh màn (ô xanh viền đen) rất nổi, nếu chỉ tô 0.62 thì
## ảnh vẫn sáng hơn cái ổ khoá -> mắt dán vào ảnh chứ không phải chỗ khoá.
const TINT_LOCKED: Color = Color(0.40, 0.43, 0.50, 1)
const STAR_SIZE: int = 12
## 16px quá nhỏ trên nền ô 160x112, dễ bỏ sót. Ổ khoá là thứ duy nhất báo
## "chưa mở" nên phải đủ to để thấy ngay ở khoảng cách đọc bình thường.
const BADGE_SIZE: int = 28

@export var level: int = 1
@export var unlocked: bool = false
@export var is_boss: bool = false
@export_range(0, 3, 1) var stars: int = 0

@onready var _icon: TextureRect = %Icon
@onready var _number: Label = %Number
@onready var _stars_box: HBoxContainer = %Stars
@onready var _badge: TextureRect = %Badge

var _star_icons: Array[TextureRect] = []
var _configured: bool = false
## Đã từng vào chơi màn này chưa — quyết định có hiện hàng sao rỗng hay không.
var _played: bool = false


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	for child in _stars_box.get_children():
		var star := child as TextureRect
		if star != null:
			_star_icons.append(star)
	if _configured:
		_apply()


## Gọi trước hay sau add_child đều được: _ready tự áp lại nếu đã có dữ liệu.
## `p_played` = đã từng vượt qua màn này (dùng để ẩn hàng sao rỗng).
func setup(p_level: int, p_unlocked: bool, p_is_boss: bool, p_stars: int, p_played: bool = false) -> void:
	level = p_level
	unlocked = p_unlocked
	is_boss = p_is_boss
	stars = p_stars
	_played = p_played or p_stars > 0
	_configured = true
	if is_node_ready():
		_apply()


## Ảnh màn N: res://assets/Menu/Levels/NN.png. Không có -> null.
static func level_icon(p_level: int) -> Texture2D:
	var path: String = "%s/%02d.png" % [ICON_DIR, maxi(p_level, 0)]
	if not ResourceLoader.exists(path):
		return null
	return UIIcons.get_icon(path)


func _apply() -> void:
	name = "Level%d" % level
	disabled = not unlocked
	tooltip_text = "Level %d" % level
	var icon: Texture2D = level_icon(level)
	_icon.texture = icon
	# Ảnh màn res://assets/Menu/Levels/NN.png ĐÃ CÓ SỐ VẼ SẴN trong ảnh. Nếu vẫn
	# hiện Label số bên dưới thì màn nào cũng hiện số hai lần.
	_number.visible = icon == null
	_number.text = str(level)
	_number.add_theme_color_override(&"font_color", NUMBER_OPEN if unlocked else NUMBER_LOCKED)
	_apply_stars()
	_apply_badge()
	_apply_tint()


func _apply_stars() -> void:
	# Màn chưa từng chơi -> ẩn hẳn hàng sao. Ba ô sao rỗng nhìn như đã thua 0/3
	# và chiếm chỗ vô ích; chỉ hiện khi đã có kết quả để so sánh.
	_stars_box.visible = _played or not unlocked
	if not unlocked:
		return
	var shown: int = clampi(stars, 0, 3)
	for i in _star_icons.size():
		var earned: bool = i < shown
		_star_icons[i].texture = PixelIcons.star(STAR_SIZE, earned, _star_color(earned))


func _apply_badge() -> void:
	# Badge dưới dãy sao: KHOÁ ưu tiên hơn boss. Ô boss chưa mở phải hiện ổ khoá,
	# không phải icon boss, nếu không người chơi tưởng đã vào được ải cuối.
	_badge.visible = is_boss or not unlocked
	if not unlocked:
		_badge.texture = PixelIcons.lock(BADGE_SIZE)
		_badge.modulate = Color(1, 1, 1, 1)
	else:
		_badge.texture = PixelIcons.boss(BADGE_SIZE - 6)
		_badge.modulate = Color(1, 1, 1, 1)


func _star_color(earned: bool) -> Color:
	if earned:
		return Color(1.0, 0.84, 0.25, 1)
	# Sao rỗng: vẫn thấy hình ngôi sao để 3 ô nhìn đều nhau.
	return Color(0.12, 0.12, 0.16, 1)


func _apply_tint() -> void:
	# Không tạo StyleBox nữa -> nền/viền/padding do theme lo.
	# Ô khoá xám lạnh, ải boss ửng đỏ, ô thường giữ màu gốc.
	# (disabled = true ở _apply() đã làm tối thêm lần nữa cho ô khoá.)
	if not unlocked:
		self_modulate = TINT_LOCKED
	elif is_boss:
		self_modulate = TINT_BOSS
	else:
		self_modulate = TINT_OPEN
