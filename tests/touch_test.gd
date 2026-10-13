extends Node
## Nghiệm thu TouchControls.
##
## LƯU Ý: harness MCP không bơm được sự kiện chuột/cảm ứng xuống cửa sổ game
## (kể cả _input của node cũng không nhận), nên test này verify toàn bộ phần
## logic/bố cục/hit-area bằng code. Phần "giữ 2 nút cùng lúc" là hành vi do
## TouchScreenButton của engine đảm nhiệm - xem README ghi chú cuối file.

var touch: TouchControls
var checks: int = 0
var fails: int = 0

var _buttons: Dictionary[StringName, TouchScreenButton] = {}


func _ready() -> void:
	touch = $TouchControls
	await get_tree().process_frame
	await get_tree().process_frame

	print("=== TOUCH TEST ===")
	_collect()
	_test_visibility()
	_test_layout()
	_test_actions()
	_test_hit_area()
	_test_independent_regions()
	_test_opacity()
	_test_scale()

	print("--- ket qua ---")
	print("PASS" if fails == 0 else "FAIL (%d/%d)" % [fails, checks])
	print("=== TOUCH TEST DONE ===")
	await get_tree().create_timer(0.3).timeout
	get_tree().quit()


func _collect() -> void:
	for action: StringName in [&"move_left", &"move_right", &"jump", &"attack", &"interact"]:
		var path: String = _path_for(action)
		var button := touch.get_node(path) as TouchScreenButton
		_buttons[action] = button
		print("%-10s node=%-8s action=%-12s pos=%s" % [
			action, button.name, button.action, button.position])


func _path_for(action: StringName) -> String:
	match action:
		&"move_left": return "Root/Left"
		&"move_right": return "Root/Right"
		&"jump": return "Root/Jump"
		&"attack": return "Root/Attack"
		&"interact": return "Root/Interact"
	return ""


# --- 1. Hiển thị -----------------------------------------------------------

func _test_visibility() -> void:
	print("--- 1. hien thi ---")
	print("show_on_desktop = ", touch.show_on_desktop, " -> visible = ", touch.visible)
	_check("hien tren desktop khi bat show_on_desktop", touch.visible)

	var was_desktop: bool = touch.show_on_desktop
	touch.show_on_desktop = false
	touch._ready()   # noop, chi de doc lai
	touch.visible = false
	touch.force_visible = false
	print("OS.has_feature(mobile) = ", OS.has_feature("mobile"))
	print("=> tren may that khong bat show_on_desktop se an (mobile=", OS.has_feature("mobile"), ")")
	touch.show_on_desktop = was_desktop
	touch.visible = true


# --- 2. Bố cục -------------------------------------------------------------

func _test_layout() -> void:
	print("--- 2. bo cuc (viewport 640x360) ---")
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var left: TouchScreenButton = _buttons[&"move_left"]
	var right: TouchScreenButton = _buttons[&"move_right"]
	var jump: TouchScreenButton = _buttons[&"jump"]
	var attack: TouchScreenButton = _buttons[&"attack"]
	var interact: TouchScreenButton = _buttons[&"interact"]

	# Safe area tren desktop = 0 nen lech = edge_margin 24
	_check("Left tai (24, 280)", _eq(left.position, Vector2(24, 280)), str(left.position))
	_check("Right tai (96, 280) - cach 72px", _eq(right.position, Vector2(96, 280)), str(right.position))
	_check("Jump tai (552, 272)", _eq(jump.position, Vector2(552, 272)), str(jump.position))
	_check("Attack tai (480, 276)", _eq(attack.position, Vector2(480, 276)), str(attack.position))
	_check("Interact tai (484, 212)", _eq(interact.position, Vector2(484, 212)), str(interact.position))
	_check("canh le duoi 24px", _eqf(vp.y - (left.position.y + 56.0), 24.0))
	_check("canh le phai 24px", _eqf(vp.x - (jump.position.x + 64.0), 24.0))
	_check("Interact tren Attack 16px",
		_eqf(attack.position.y - (interact.position.y + 48.0), 16.0))


# --- 3. Action binding -----------------------------------------------------

func _test_actions() -> void:
	print("--- 3. action binding ---")
	var expect: Dictionary[StringName, StringName] = {
		&"move_left": &"move_left", &"move_right": &"move_right",
		&"jump": &"jump", &"attack": &"attack", &"interact": &"interact"}
	for key: StringName in expect:
		var button: TouchScreenButton = _buttons[key]
		_check("%s -> %s" % [button.name, expect[key]], button.action == expect[key],
			str(button.action))
		_check("%s co trong InputMap" % button.action, InputMap.has_action(button.action))


# --- 4. Vùng chạm khớp hình -----------------------------------------------

func _test_hit_area() -> void:
	print("--- 4. kich thuoc vung cham ---")
	var sizes: Dictionary[StringName, float] = {
		&"move_left": 56.0, &"move_right": 56.0,
		&"jump": 64.0, &"attack": 56.0, &"interact": 48.0}
	for key: StringName in sizes:
		var button: TouchScreenButton = _buttons[key]
		var expected: float = sizes[key]
		var circle := button.shape as CircleShape2D
		var tex_size: Vector2 = button.get_texture_normal().get_size()
		print("%-10s shape r=%.1f  texture=%s" % [key, circle.radius if circle else -1.0, tex_size])
		_check("%s shape radius = %.0f" % [key, expected * 0.5],
			circle != null and is_equal_approx(circle.radius, expected * 0.5))
		_check("%s texture = %.0fx%.0f" % [key, expected, expected],
			is_equal_approx(tex_size.x, expected) and is_equal_approx(tex_size.y, expected))
		_check("%s shape_centered" % key, button.is_shape_centered())


# --- 5. Vùng chạm độc lập (điều kiện để đa chạm) ---------------------------

func _test_independent_regions() -> void:
	print("--- 5. 5 vung cham doc lap, khong de nhau ---")
	var rects: Array[Rect2] = []
	var names: Array[String] = []
	for action: StringName in [&"move_left", &"move_right", &"jump", &"attack", &"interact"]:
		var button: TouchScreenButton = _buttons[action]
		var size: float = touch._button_size_for(action)
		rects.append(Rect2(button.position, Vector2(size, size)))
		names.append(String(action))
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if rects[i].intersects(rects[j]):
				_check("%s va %s khong de nhau" % [names[i], names[j]], false,
					"%s vs %s" % [rects[i], rects[j]])
			else:
				_check("%s / %s tach biet" % [names[i], names[j]], true)
	_check("5 node rieng (khong dung chung 1 Control)",
		_buttons[&"jump"].get_path() != _buttons[&"attack"].get_path())


# --- 6. Opacity / scale ----------------------------------------------------

func _test_opacity() -> void:
	print("--- 6. opacity ---")
	touch.set_opacity(0.25)
	await get_tree().process_frame
	var all_applied: bool = true
	for key: StringName in _buttons:
		var value: float = _buttons[key].modulate.a
		print("%-10s modulate.a = %.2f" % [key, value])
		if not is_equal_approx(value, 0.25):
			all_applied = false
	_check("opacity ap dung cho ca 5 nut", all_applied)
	touch.set_opacity(0.5)
	await get_tree().process_frame


func _test_scale() -> void:
	print("--- 7. button_scale = 1.5 ---")
	touch.button_scale = 1.5
	touch._layout()
	await get_tree().process_frame
	var left: TouchScreenButton = _buttons[&"move_left"]
	var jump: TouchScreenButton = _buttons[&"jump"]
	print("Left pos=", left.position, " scale=", left.scale, " | Jump pos=", jump.position)
	_check("scale nhan 1.5", is_equal_approx(left.scale.x, 1.5))
	_check("vi tri tinh lai theo scale (khong tran ra le)",
		left.position.x >= 24.0 and jump.position.x + 64.0 * 1.5 <= get_viewport().get_visible_rect().size.x)
	touch.button_scale = 1.0
	touch._layout()


# --- Helper ---------------------------------------------------------------

func _eq(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) < 0.5


func _eqf(a: float, b: float) -> bool:
	return absf(a - b) < 0.5


func _check(label: String, ok: bool, detail: String = "") -> void:
	checks += 1
	if ok:
		print("   PASS  ", label)
	else:
		fails += 1
		print("   FAIL  ", label, "  ", detail)
