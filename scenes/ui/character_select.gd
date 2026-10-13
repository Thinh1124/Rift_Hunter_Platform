class_name CharacterSelect
extends Control
## Lưới chọn nhân vật: đọc MỌI CharacterData (*.tres) trong res://data/characters/.
## Thêm 1 file .tres mới -> tự xuất hiện ở đây, KHÔNG cần sửa code.
## Bấm 1 thẻ -> GameManager.selected_character + SaveManager.selected_character_id.
##
## MainMenu gắn scene này, bấm nút "Nhân vật" -> show(), chọn xong -> chosen.

## Người chơi chọn xong (đã lưu vào GameManager + SaveManager).
signal chosen(data: CharacterData)
## Bấm nút Back.
signal closed

@export_range(1, 8, 1) var columns: int = 3
@export var card_size: Vector2 = Vector2(150.0, 110.0)
@export var icon_size: Vector2 = Vector2(48.0, 48.0)
@export var selected_border: Color = Color(1.0, 0.85, 0.25)

@onready var _grid: GridContainer = %Grid
@onready var _title: Label = %Title
@onready var _back: Button = %Back

var _cards: Dictionary[StringName, Button] = {}


func _ready() -> void:
	_back.pressed.connect(_on_back_pressed)
	_ensure_full_rect()
	refresh()


## Khi scene được add dưới Node2D (không phải Control) thì rect gốc = 0 -> ép full màn hình.
func _ensure_full_rect() -> void:
	var vp: Vector2 = get_viewport_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return
	if size.x < 1.0 or size.y < 1.0:
		set_deferred(&"size", vp)


## Dựng lại lưới từ đĩa (gọi lại sau khi vừa thêm .tres mới).
func refresh() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_cards.clear()
	_grid.columns = maxi(columns, 1)
	for data: CharacterData in GameManager.all_characters():
		if not data.unlocked_by_default:
			continue
		var card := _make_card(data)
		_cards[data.id] = card
		_grid.add_child(card)
	_title.text = "CHỌN NHÂN VẬT  (%d)" % _cards.size()
	_highlight(GameManager.selected_character)


func _make_card(data: CharacterData) -> Button:
	var card := Button.new()
	card.custom_minimum_size = card_size
	card.focus_mode = Control.FOCUS_NONE
	card.tooltip_text = "%s\n%s" % [data.display_name, data.stats_line()]
	card.pressed.connect(_on_card_pressed.bind(data))

	# Button không tự bố trí con -> dùng VBoxContainer neo full-rect.
	var box := VBoxContainer.new()
	box.name = "Box"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(box)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = icon_size
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = data.icon
	box.add_child(icon)

	var name_label := Label.new()
	name_label.name = "Name"
	name_label.text = data.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)

	var stats := Label.new()
	stats.name = "Stats"
	stats.text = data.stats_line()
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override(&"font_size", 8)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(stats)

	return card


func _on_card_pressed(data: CharacterData) -> void:
	GameManager.select_character(data)
	_highlight(data)
	AudioManager.play_sfx(&"ui_select")
	chosen.emit(data)


func _on_back_pressed() -> void:
	AudioManager.play_sfx(&"ui_back")
	closed.emit()


func _highlight(data: CharacterData) -> void:
	if data == null:
		return
	for id: StringName in _cards:
		_apply_border(_cards[id], id == data.id)


func _apply_border(card: Button, selected: bool) -> void:
	if card == null:
		return
	if selected:
		card.add_theme_stylebox_override(&"normal", _style(Color(0.22, 0.26, 0.34), selected_border, 2))
		card.add_theme_stylebox_override(&"hover", _style(Color(0.28, 0.32, 0.42), selected_border, 2))
	else:
		card.add_theme_stylebox_override(&"normal", _style(Color(0.16, 0.18, 0.24), Color(0.45, 0.45, 0.5), 1))
		card.add_theme_stylebox_override(&"hover", _style(Color(0.24, 0.26, 0.34), Color(0.7, 0.7, 0.75), 1))


func _style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(4)
	box.content_margin_left = 6.0
	box.content_margin_right = 6.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	return box