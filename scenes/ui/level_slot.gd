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
const TINT_LOCKED: Color = Color(0.62, 0.65, 0.72, 1)
const STAR_SIZE: int = 12
const BADGE_SIZE: int = 16

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


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	for child in _stars_box.get_children():
		var star := child as TextureRect
		if star != null:
			_star_icons.append(star)
	if _configured:
		_apply()


## Gọi trước hay sau add_child đều được: _ready tự áp lại nếu đã có dữ liệu.
func setup(p_level: int, p_unlocked: bool, p_is_boss: bool, p_stars: int) -> void:
	level = p_level
	unlocked = p_unlocked
	is_boss = p_is_boss
	stars = p_stars
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
	_icon.texture = level_icon(level)
	_number.text = str(level)
	_number.add_theme_color_override(&"font_color", NUMBER_OPEN if unlocked else NUMBER_LOCKED)
	_apply_stars()
	_apply_badge()
	_apply_tint()


func _apply_stars() -> void:
	# Ô khoá không cần sao (đã có ổ khoá), chỉ ải đã mở mới hiện sao thật.
	var shown: int = stars if unlocked else 0
	for i in _star_icons.size():
		var earned: bool = i < shown
		_star_icons[i].texture = PixelIcons.star(STAR_SIZE, earned, _star_color(earned))


func _apply_badge() -> void:
	# Badge dưới dãy sao: KHOÁ ưu tiên hơn boss. Ô boss chưa mở phải hiện ổ khoá,
	# không phải icon boss, nếu không người chơi tưởng đã vào được ải cuối.
	_badge.visible = is_boss or not unlocked
	if not unlocked:
		_badge.texture = PixelIcons.lock(BADGE_SIZE)
		_badge.modulate = Color(0.75, 0.78, 0.86, 1)
	else:
		_badge.texture = PixelIcons.boss(20)
		_badge.modulate = Color(1, 1, 1, 1)


func _star_color(earned: bool) -> Color:
	if earned:
		return Color(1.0, 0.84, 0.25, 1)
	# Sao rỗng: vẫn thấy hình ngôi sao để 3 ô nhìn đều nhau.
	return Color(0.3, 0.32, 0.4, 1)


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
