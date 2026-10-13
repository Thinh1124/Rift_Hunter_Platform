extends Node
## Chẩn đoán: TouchScreenButton có nhận InputEventScreenTouch hay không.

var touch: TouchControls
var log_lines: Array[String] = []


func _ready() -> void:
	touch = $TouchControls
	var buttons: Array[TouchScreenButton] = [
		touch.get_node("Root/Left"), touch.get_node("Root/Right"),
		touch.get_node("Root/Jump"), touch.get_node("Root/Attack"),
		touch.get_node("Root/Interact")]
	for b in buttons:
		b.button_down.connect(func() -> void: print("  button_down  ", b.action, " @", b.get_global_transform_with_canvas().origin))
		b.button_up.connect(func() -> void: print("  button_up    ", b.action))
	print("=== DIAG ===")
	await get_tree().process_frame
	await get_tree().process_frame

	var vp: Vector2 = get_viewport().get_visible_rect().size
	var win: Vector2 = Vector2(DisplayServer.window_get_size())
	print("viewport      : ", vp)
	print("window_get_size: ", win)
	print("screen size   : ", Vector2(DisplayServer.screen_get_size()))
	print("stretch       : ", get_viewport().get_screen_transform())

	var rb: TouchScreenButton = touch.get_node("Root/Right")
	print("Right node pos        : ", rb.position)
	print("Right global pos      : ", rb.global_position)
	print("Right global+canvas   : ", rb.get_global_transform_with_canvas().origin)
	print("Right shape_rect      : ", rb.get_shape_rect())
	print("Right shape_centered  : ", rb.shape_centered)
	print("Right texture size    : ", rb.texture_normal.get_size() if rb.texture_normal else "null")

	# Thu toạ độ để biết engine mong đợi không gian nào
	print("--- gui/global to local ---")
	var local: Vector2 = rb.get_global_transform_with_canvas().affine_inverse() * touch.button_center(&"move_right")
	print("button_center           : ", touch.button_center(&"move_right"))
	print("-> local cua tam        : ", local)

	print("--- gui input co phai noi dung khong ---")
	var probe := Control.new()
	probe.set_anchors_preset(Control.PRESET_FULL_RECT)
	probe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(probe)
	probe.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventScreenTouch:
			print("  Control.gui_input nhan ScreenTouch pressed=", (e as InputEventScreenTouch).pressed))

	await get_tree().process_frame
	_send(0, touch.button_center(&"move_right"), true)
	for i in 10:
		await get_tree().process_frame
	print("sau 10 frame: move_right=", Input.is_action_pressed(&"move_right"))
	_send(0, touch.button_center(&"move_right"), false)
	for i in 10:
		await get_tree().process_frame
	print("sau release: move_right=", Input.is_action_pressed(&"move_right"))
	print("=== DIAG DONE ===")
	await get_tree().create_timer(0.3).timeout
	get_tree().quit()


func _send(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	Input.parse_input_event(e)
