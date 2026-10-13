class_name CharacterSelect
extends Control
## Cửa sổ đổi nhân vật. MainMenu nhét scene này làm CON (overlay_mode = true),
## bấm CLOSE chỉ ẩn đi, MainMenu vẫn nguyên.
##
## Cây node khai báo sẵn trong CharacterSelect.tscn: Title / Stage (2 nút mũi tên
## + SubViewport phát animation idle) / NameLabel / StatsBox (HP, ATK, SPD, JMP,
## SKILL) / CloseButton. Script chỉ đổi nội dung, KHÔNG tạo node lúc chạy.
##
## Danh sách nhân vật đọc từ res://data/characters/*.tres nên thêm file .tres
## mới là tự xuất hiện, không phải sửa code.

## MainMenu đã chọn nhân vật khác (đóng cửa sổ).
signal closed

@export_group("Overlay")
## true  -> MainMenu nhét làm CON, bấm CLOSE chỉ ẩn đi.
## false -> chạy như scene chính, CLOSE về MainMenu (mặc định).
@export var overlay_mode: bool = false
@export var overlay_close_scene: String = "res://scenes/ui/MainMenu.tscn"

@export_group("Look")
## Vùng hiển thị animation. Sprite nằm ở giữa SubViewport rồi scale 2 lần.
@export var preview_scale: float = 2.0
@export var hp_icon_size: int = 11
@export var atk_icon_size: int = 11

@onready var _title: Label = %Title
@onready var _prev_button: UIButton = %PrevButton
@onready var _next_button: UIButton = %NextButton
@onready var _sprite: AnimatedSprite2D = %Sprite
@onready var _name_label: Label = %NameLabel
@onready var _hp_row: PipRow = %HpRow
@onready var _atk_row: PipRow = %AtkRow
@onready var _spd_value: Label = %SpdValue
@onready var _jmp_value: Label = %JmpValue
@onready var _ability_row: HBoxContainer = %AbilityRow
@onready var _ability_value: Label = %AbilityValue
@onready var _close_button: UIButton = %CloseButton

var _list: Array[CharacterData] = []
var _index: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sprite.scale = Vector2(preview_scale, preview_scale)
	_hp_row.pip_size = hp_icon_size
	_atk_row.pip_size = atk_icon_size

	_prev_button.pressed.connect(_on_prev_pressed)
	_next_button.pressed.connect(_on_next_pressed)
	_close_button.pressed.connect(close)

	_list = _collect()
	_index = _index_of(GameManager.selected_character)
	_show_current()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if overlay_mode and visible and event.is_action_pressed(&"pause"):
		close()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"move_left"):
		_step(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"move_right"):
		_step(1)
		get_viewport().set_input_as_handled()


func open() -> void:
	# Mở lại thì đồng bộ với nhân vật đang chọn (người chơi có thể đã đổi
	# từ chỗ khác trước đó).
	_index = _index_of(GameManager.selected_character)
	_show_current()
	visible = true


func close() -> void:
	AudioManager.play_sfx(&"ui_back")
	visible = false
	closed.emit()
	if not overlay_mode:
		SceneTransition.change_scene(overlay_close_scene)


## Nhân vật đang mở khoá và xuất hiện trong menu.
func _collect() -> Array[CharacterData]:
	var out: Array[CharacterData] = []
	for data: CharacterData in GameManager.all_characters():
		if data != null and data.unlocked_by_default:
			out.append(data)
	return out


func _index_of(data: CharacterData) -> int:
	if data != null:
		var found: int = _list.find(data)
		if found >= 0:
			return found
	return 0


func _step(delta: int) -> void:
	if _list.is_empty():
		return
	AudioManager.play_sfx(&"ui_select")
	# Vòng tròn: trước hết <-> sau cùng.
	_index = posmod(_index + delta, _list.size())
	_show_current()


func _on_prev_pressed() -> void:
	_step(-1)


func _on_next_pressed() -> void:
	_step(1)


func _show_current() -> void:
	if _list.is_empty():
		_title.text = "NO CHARACTER"
		_name_label.text = "-"
		_sprite.sprite_frames = null
		_hp_row.set_items([])
		_atk_row.set_items([])
		_ability_row.visible = false
		return
	var data: CharacterData = _list[_index]
	_name_label.text = data.display_name
	_title.text = "CHARACTER %d/%d" % [_index + 1, _list.size()]

	var frames: SpriteFrames = data.validated_sprite_frames()
	_sprite.sprite_frames = frames
	_sprite.animation = data.animation_or_idle(&"idle")
	_sprite.play()

	_hp_row.set_items(_hearts(data.hp_stars()))
	_atk_row.set_items(_swords(data.atk_stars()))
	_spd_value.text = "%.2fx" % data.speed_mult
	_jmp_value.text = "%.2fx" % data.jump_mult
	_ability_row.visible = data.ability.strip_edges() != ""
	_ability_value.text = data.ability

	GameManager.select_character(data)


func _hearts(count: int) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for _i in count:
		out.append(PixelIcons.heart(hp_icon_size, true, Color(1.0, 0.42, 0.52)))
	return out


func _swords(count: int) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for _i in count:
		out.append(PixelIcons.sword(atk_icon_size))
	return out
