class_name PipRow
extends HBoxContainer
## Hàng icon lặp lại: tim cho HP, kiếm cho ATK.
##
## Node Pip khai báo sẵn trong PipRow.tscn (nên thấy trong Scene dock).
## Script chỉ nhân bản Pip ra cho từng icon cần hiện rồi gán texture.
##
## set_items([]) -> ẩn cả hàng, không chiếm chỗ.

@export_range(4, 32, 1) var pip_size: int = 12
@export_range(0, 8, 1) var separation: int = 2
## Màu của icon "chưa đầy" (tim rỗng, sao chưa thắng).
@export var dim_color: Color = Color(0.45, 0.45, 0.5, 1)

@onready var _template: TextureRect = %Pip

var _textures: Array[Texture2D] = []
var _filled_count: int = -1


func _ready() -> void:
	# "theme_override_constants/separation" chi hop le trong .tscn; trong GDScript
	# dau / bi hieu thanh phep chia nen phai goi API.
	add_theme_constant_override(&"separation", separation)
	_apply_template_size()
	_rebuild()


## Gán danh sách icon. Rỗng -> ẩn hàng.
## filled_count >= 0 -> chỉ `filled_count` icon đầu hiện bình thường, phần còn
## lại dùng dim_color (dùng cho tim rỗng). -1 -> mọi icon đều bình thường.
func set_items(items: Array[Texture2D], filled_count: int = -1) -> void:
	_textures = items
	_filled_count = filled_count
	visible = not items.is_empty()
	if is_node_ready():
		_apply_template_size()
		_rebuild()


func _apply_template_size() -> void:
	if _template == null:
		return
	_template.custom_minimum_size = Vector2(pip_size, pip_size)
	_template.size = _template.custom_minimum_size


func _rebuild() -> void:
	for child in get_children():
		if child != _template:
			remove_child(child)
			child.queue_free()
	for _i in maxi(_textures.size() - 1, 0):
		var copy: TextureRect = _template.duplicate() as TextureRect
		if copy == null:
			continue
		# Bản sao không được giữ cờ unique, nếu không sẽ trùng tên Pip.
		copy.set_unique_name_in_owner(false)
		add_child(copy)
	_apply()


func _apply() -> void:
	var pips: Array[TextureRect] = []
	for child in get_children():
		var pip := child as TextureRect
		if pip != null:
			pips.append(pip)
	for i in pips.size():
		var pip := pips[i]
		pip.custom_minimum_size = Vector2(pip_size, pip_size)
		pip.size = pip.custom_minimum_size
		pip.texture = _textures[i] if i < _textures.size() else null
		pip.modulate = Color.WHITE
		if _filled_count >= 0 and i >= _filled_count:
			pip.modulate = dim_color