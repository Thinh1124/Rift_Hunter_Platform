class_name DialogueBubble
extends Control
## Bong bóng thoại kiểu typewriter. Chạm để qua câu, hết câu tự đóng sau
## `auto_close_delay` giây.
##
## Dùng: bubble.open(DialogueDB.lines(id, key)) / bubble.close()

signal closed

enum Phase { CLOSED, TYPING, WAITING }

## Ký tự hiện mỗi giây.
@export_range(1.0, 120.0, 1.0) var chars_per_second: float = 30.0
## Chờ bao lâu rồi tự qua câu / đóng hội thoại.
@export_range(0.0, 10.0, 0.1) var auto_close_delay: float = 2.0
## Cỡ chữ trong bong bóng. 12 khớp default_font_size của theme.
## Nhỏ hơn 10 thì NinjaAdventure đọc không nổi ở viewport 640x360.
@export_range(6, 32, 1) var font_size: int = 12

@onready var label: Label = $Panel/Label

var _lines: PackedStringArray = PackedStringArray()
var _index: int = -1
var _typed: float = 0.0
var _wait_left: float = 0.0
var _phase: Phase = Phase.CLOSED


func _ready() -> void:
	label.add_theme_font_size_override(&"font_size", font_size)
	hide()
	set_process(false)


func is_open() -> bool:
	return _phase != Phase.CLOSED


func open(lines: PackedStringArray) -> void:
	if lines.is_empty():
		close()
		return
	_lines = lines
	_index = 0
	_typed = 0.0
	show()
	set_process(true)
	_set_phase(Phase.TYPING)


func close() -> void:
	_lines = PackedStringArray()
	_index = -1
	_typed = 0.0
	label.text = ""
	_set_phase(Phase.CLOSED)
	hide()
	set_process(false)
	closed.emit()


func current_line() -> String:
	if _index < 0 or _index >= _lines.size():
		return ""
	return _lines[_index]


## Phần chữ đã hiện của câu hiện tại.
func visible_text() -> String:
	var line := current_line()
	return line.substr(0, mini(int(_typed), line.length()))


## Có gì đang hiện không (dùng cho test và cho ExclaimIcon).
func has_visible_text() -> bool:
	return is_open() and not label.text.is_empty()


func _process(delta: float) -> void:
	match _phase:
		Phase.TYPING:
			_typed += chars_per_second * delta
			label.text = visible_text()
			if _typed >= float(current_line().length()):
				_set_phase(Phase.WAITING)
		Phase.WAITING:
			_wait_left -= delta
			if _wait_left <= 0.0:
				advance()


func _gui_input(event: InputEvent) -> void:
	if _phase == Phase.CLOSED:
		return
	var pressed := false
	if event is InputEventMouseButton:
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		pressed = event.pressed
	if pressed:
		tap()
		accept_event()


## Chạm lần 1 -> hiện hết câu đang gõ. Chạm lần 2 -> qua câu kế / đóng.
func tap() -> void:
	match _phase:
		Phase.TYPING:
			_typed = float(current_line().length())
			label.text = current_line()
			_set_phase(Phase.WAITING)
		Phase.WAITING:
			advance()


func advance() -> void:
	if _index + 1 < _lines.size():
		_index += 1
		_typed = 0.0
		label.text = ""
		_set_phase(Phase.TYPING)
	else:
		close()


func _set_phase(phase: Phase) -> void:
	_phase = phase
	_wait_left = auto_close_delay