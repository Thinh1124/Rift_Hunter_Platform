extends Node2D

## Vị trí bên trong / ngoài TalkZone (NPC ở 300,220 -> vùng x 278..322).
const INSIDE: Vector2 = Vector2(305, 230)
const OUTSIDE: Vector2 = Vector2(100, 230)

var failures: int = 0


func _ready() -> void:
	call_deferred(&"_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
	await get_tree().process_frame


func _run() -> void:
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(300, 240)
	var floor_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(900, 20)
	floor_shape.shape = rectangle
	floor_body.add_child(floor_shape)
	add_child(floor_body)

	# --- Dữ liệu thoại --------------------------------------------------
	DialogueDB.clear()
	var default_lines := DialogueDB.lines("npc_guide", "default")
	_check(default_lines.size() == 2, "dialogues.json must load the npc_guide default lines")
	_check(default_lines[0] == "Hello there!", "First default line must match dialogues.json")
	_check(DialogueDB.lines("npc_guide", "hint").size() == 1, "dialogues.json must provide the hint line")
	_check(DialogueDB.lines("npc_guide", "after_gates").size() == 1, "dialogues.json must provide the after_gates line")
	_check(DialogueDB.lines("khong_ton_tai", "default").is_empty(), "An unknown dialogue_id must return no lines")

	GameManager.lives = 3
	GameManager.last_checkpoint = Vector2(100, 230)
	GameManager.total_gates = 2
	GameManager.remaining_gates = 2
	GameManager.deaths_this_level = 0
	var npc := preload("res://scenes/objects/NPC.tscn").instantiate() as NPC
	npc.position = Vector2(300, 220)
	add_child(npc)
	await _frames(3)
	_check(npc.is_in_group(&"npc"), "NPC must join group \"npc\"")
	_check(npc.talk_zone.collision_mask == 2, "TalkZone must watch the Player layer")
	_check(npc.sprite.sprite_frames.has_animation(&"idle") and npc.sprite.is_playing(), "NPC must play its idle animation")
	_check(not npc.exclaim_icon.visible, "ExclaimIcon must start hidden")
	_check(not npc.bubble.is_open(), "Bubble must start closed")

	var player := preload("res://scenes/player/Player.tscn").instantiate() as Player
	player.position = OUTSIDE
	add_child(player)
	player.camera.enabled = false
	var camera := Camera2D.new()
	camera.position = Vector2(300, 320)
	add_child(camera)
	camera.make_current()
	await _frames(4)
	_check(not npc.is_talking(), "NPC must stay silent while the player is away")

	# --- Vào vùng -> thoại "default" -------------------------------------
	_check(npc.current_key() == "default", "With gates remaining and no deaths the NPC must use \"default\"")
	player.position = INSIDE
	player.velocity = Vector2.ZERO
	await _frames(8)
	_check(npc.is_talking(), "Entering TalkZone must open the bubble")
	_check(npc.bubble.current_line() == "Hello there!", "First line must be the default greeting")
	_check(not npc.sprite.flip_h, "NPC must face the player standing on its right")

	# Typewriter: chưa hiện hết ngay khi mở.
	await _frames(10)
	_check(npc.bubble.label.text.length() > 0, "Bubble must start showing text")
	_check(npc.bubble.label.text.length() < "Hello there!".length(), "Text must type in gradually rather than appear at once")
	npc.bubble.tap()
	await _frames(1)
	_check(npc.bubble.label.text == "Hello there!", "A tap during typing must reveal the whole line")

	# Chạm lần nữa -> sang câu 2.
	npc.bubble.tap()
	await _frames(1)
	_check(npc.bubble.current_line() == "Please close the monster gates!", "A tap must advance to the next line")

	# Hết câu -> tự đóng sau auto_close_delay.
	npc.bubble.auto_close_delay = 0.2
	npc.bubble.tap()
	await _frames(2)
	_check(npc.is_talking(), "Bubble must wait on the final line before auto-closing")
	await _frames(30)
	_check(not npc.is_talking(), "Bubble must auto-close after the last line")
	_check(npc.exclaim_icon.visible, "ExclaimIcon must show once the bubble closes while the player waits")

	# Rời rồi vào lại -> mở thoại mới.
	npc.bubble.auto_close_delay = 2.0
	player.position = OUTSIDE
	player.velocity = Vector2.ZERO
	await _frames(6)
	_check(not npc.is_talking(), "Leaving TalkZone must close the bubble")
	player.position = INSIDE
	player.velocity = Vector2.ZERO
	await _frames(8)
	_check(npc.is_talking(), "Re-entering the zone must open the dialogue again")
	_check(not npc.exclaim_icon.visible, "ExclaimIcon must hide while the bubble is open")

	# Vào/ra liên tục không được lặp lại câu đang hiện.
	npc.bubble.tap()
	await _frames(1)
	var line_before := npc.bubble.current_line()
	var text_before := npc.bubble.label.text
	await _frames(20)
	_check(npc.bubble.current_line() == line_before and npc.bubble.label.text == text_before, "Staying inside must not restart the dialogue")

	player.position = OUTSIDE
	player.velocity = Vector2.ZERO
	await _frames(6)
	_check(not npc.is_talking(), "Leaving TalkZone must close the bubble")

	# --- Đổi thoại theo trạng thái ---------------------------------------
	_check(npc.current_key() == "default", "Zero deaths must use \"default\"")
	GameManager.deaths_this_level = 3
	_check(npc.current_key() == "hint", "Deaths reaching hint_after_deaths must use \"hint\"")
	player.position = INSIDE
	player.velocity = Vector2.ZERO
	await _frames(8)
	_check(npc.bubble.current_line() == "Try stomping on their heads!", "Hint line must replace the default line once deaths hit the threshold")

	GameManager.deaths_this_level = 0
	GameManager.remaining_gates = 0
	_check(npc.current_key() == "after_gates", "Clearing all gates must use \"after_gates\"")
	GameManager.remaining_gates = 2
	GameManager.total_gates = 0
	_check(npc.current_key() == "default", "A level with no gates must not use after_gates")
	GameManager.total_gates = 2
	GameManager.remaining_gates = 0
	player.position = OUTSIDE
	player.velocity = Vector2.ZERO
	await _frames(6)
	player.position = INSIDE
	player.velocity = Vector2.ZERO
	await _frames(8)
	_check(npc.bubble.current_line() == "Thanks for closing the gates!", "after_gates line must show once every gate is closed")

	# --- Bộ đếm chết của GameManager -------------------------------------
	GameManager.lives = 3
	GameManager.deaths_this_level = 0
	GameManager.lose_life()
	GameManager.lose_life()
	_check(GameManager.deaths_this_level == 2 and GameManager.lives == 1, "lose_life must count deaths and cost one life each")
	GameManager.current_level = 2
	GameManager.go_to_level(3)
	_check(GameManager.deaths_this_level == 0 and GameManager.current_level == 3, "Changing level must reset deaths_this_level")
	GameManager.reset_run()
	_check(GameManager.deaths_this_level == 0, "reset_run must reset deaths_this_level")
	print("NPC checks complete: %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)