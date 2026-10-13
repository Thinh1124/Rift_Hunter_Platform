extends Node2D
## Nghiệm thu 2 cơ chế nhân vật mới:
##   1. Ninja Frog nhảy 2 lần trên không (ability_id = double_jump)
##   2. Mở khoá nhân vật theo màn đã vượt (Pink Man -> Virtual -> Mask -> Frog)

const GROUND_Y: float = 288.0
const TILE: float = 16.0

var failures: int = 0
var _saved_completed: int = 0


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


func _ground() -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = Vector2(300, GROUND_Y + 20.0)
	body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(900, 40)
	shape.shape = rect
	body.add_child(shape)
	add_child(body)
	return body


func _new_player() -> Player:
	var p: Player = (load("res://scenes/player/Player.tscn") as PackedScene).instantiate() as Player
	p.position = Vector2(120, GROUND_Y)
	add_child(p)
	p.camera.enabled = false
	return p


func _run() -> void:
	_saved_completed = SaveManager.levels_completed
	_ground()
	await _test_data()
	await _test_double_jump()
	await _test_other_characters_cannot_double_jump()
	await _test_unlock_rules()
	SaveManager.levels_completed = _saved_completed
	print("CharacterAbility checks complete: %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)


# --- 1. Dữ liệu -------------------------------------------------------------

func _test_data() -> void:
	var frog: CharacterData = GameManager.load_character("ninja_frog")
	_check(frog != null, "ninja_frog must load")
	if frog == null:
		return
	_check(frog.ability_id == &"double_jump",
		"Frog ability_id must be double_jump (got %s)" % String(frog.ability_id))
	_check(frog.unlock_level == 4, "Frog must unlock after level 4 (got %d)" % frog.unlock_level)
	_check(not frog.unlocked_by_default, "Frog must not be unlocked_by_default")
	var frames: SpriteFrames = frog.sprite_frames
	_check(frames != null and frames.has_animation(&"double_jump"),
		"Frog SpriteFrames must provide a \"double_jump\" animation")
	if frames != null and frames.has_animation(&"double_jump"):
		_check(frames.get_frame_count(&"double_jump") == 6,
			"double_jump must use all 6 frames of Double Jump sheet (got %d)"
			% frames.get_frame_count(&"double_jump"))
		_check(not frames.get_animation_loop(&"double_jump"),
			"double_jump must not loop")

	for id: String in ["pink_man", "virtual_guy", "mask_dude"]:
		var data: CharacterData = GameManager.load_character(id)
		_check(data != null, "%s must load" % id)
		if data == null:
			continue
		_check(data.ability_id == &"", "%s must have no ability_id" % id)
	_check(GameManager.load_character("pink_man").required_level() == 0,
		"Pink Man must be unlocked from the start")


# --- 2. Nhảy 2 lần trên không ----------------------------------------------

func _test_double_jump() -> void:
	var p: Player = _new_player()
	p.apply_character(GameManager.load_character("ninja_frog"))
	await _frames(4)

	_check(not p.can_air_jump(), "Air jump must not be available while still standing")

	# Cú 1 từ mặt đất.
	Input.action_press(&"jump")
	await _frames(3)
	Input.action_release(&"jump")
	await _frames(6)
	_check(p.last_jump_was_air == false, "Ground jump must not be flagged as air jump")
	_check(p.sprite.animation == &"jump", "Ground jump must play \"jump\"")
	_check(p.can_air_jump(), "Frog must be able to air jump while rising")
	_check(p.velocity.y < 0.0, "Frog must be rising before the air jump")

	# Cú 2 giữa không.
	var y_before: float = p.global_position.y
	Input.action_press(&"jump")
	await _frames(3)
	Input.action_release(&"jump")
	await _frames(2)
	_check(p.last_jump_was_air, "Second mid-air jump must be flagged as air jump")
	_check(p.sprite.animation == &"double_jump",
		"Air jump must play \"double_jump\" (got %s)" % String(p.sprite.animation))
	_check(p.velocity.y < 0.0, "Air jump must push the player upward again")
	_check(p.global_position.y < y_before + 6.0, "Air jump must gain height")
	_check(not p.can_air_jump(), "Air jump must be consumed after one use")

	# Cú 3 phải bị chặn.
	var vy_hold: float = p.velocity.y
	Input.action_press(&"jump")
	await _frames(3)
	Input.action_release(&"jump")
	await _frames(4)
	_check(not p.last_jump_was_air or p.can_air_jump() == false,
		"Third air jump must be refused")
	_check(p.velocity.y > vy_hold - 400.0, "Third jump must not reset velocity upward")
	_check(not p.can_air_jump(), "Air jump must stay consumed until landing")

	# Chạm đất -> nạp lại.
	for i in 120:
		await get_tree().physics_frame
		if p.is_on_floor():
			break
	_check(p.is_on_floor(), "Frog must land")
	await _frames(4)
	_check(p.can_air_jump() == false, "Air jump must reset on landing (standing)")
	Input.action_press(&"jump")
	await _frames(4)
	Input.action_release(&"jump")
	await _frames(5)
	_check(p.can_air_jump(), "Air jump must be available again after landing + new jump")
	p.queue_free()
	await _frames(2)


# --- 3. Nhân vật khác không nhảy 2 lần --------------------------------------

func _test_other_characters_cannot_double_jump() -> void:
	for id: String in ["pink_man", "virtual_guy", "mask_dude"]:
		var p: Player = _new_player()
		p.apply_character(GameManager.load_character(id))
		await _frames(4)
		Input.action_press(&"jump")
		await _frames(3)
		Input.action_release(&"jump")
		await _frames(8)
		_check(not p.can_air_jump(), "%s must not be able to air jump" % id)
		Input.action_press(&"jump")
		await _frames(3)
		Input.action_release(&"jump")
		await _frames(3)
		_check(p.sprite.animation != &"double_jump",
			"%s must not play double_jump" % id)
		p.queue_free()
		await _frames(2)


# --- 4. Mở khoá nhân vật -----------------------------------------------------

func _test_unlock_rules() -> void:
	## Bảng yêu cầu của thiết kế.
	var expected: Dictionary[String, int] = {
		"pink_man": 0, "virtual_guy": 2, "mask_dude": 3, "ninja_frog": 4,
	}
	for id: String in expected:
		var data: CharacterData = GameManager.load_character(id)
		_check(data.required_level() == expected[id],
			"%s must require level %d (got %d)" % [id, expected[id], data.required_level()])

	# Mới chơi: chỉ Pink Man.
	SaveManager.levels_completed = 0
	_check(GameManager.is_character_unlocked(GameManager.load_character("pink_man")),
		"Pink Man must be unlocked on a fresh save")
	for id: String in ["virtual_guy", "mask_dude", "ninja_frog"]:
		_check(not GameManager.is_character_unlocked(GameManager.load_character(id)),
			"%s must be locked on a fresh save" % id)

	# Vượt màn 2 -> Virtual Guy mở.
	SaveManager.levels_completed = 2
	_check(GameManager.is_character_unlocked(GameManager.load_character("virtual_guy")),
		"Beating level 2 must unlock Virtual Guy")
	_check(not GameManager.is_character_unlocked(GameManager.load_character("mask_dude")),
		"Mask Dude must stay locked after level 2")

	# Vượt màn 3 -> Mask Dude mở.
	SaveManager.levels_completed = 3
	_check(GameManager.is_character_unlocked(GameManager.load_character("mask_dude")),
		"Beating level 3 must unlock Mask Dude")
	_check(not GameManager.is_character_unlocked(GameManager.load_character("ninja_frog")),
		"Ninja Frog must stay locked after level 3")

	# Vượt màn 4 -> Frog mở.
	SaveManager.levels_completed = 4
	_check(GameManager.is_character_unlocked(GameManager.load_character("ninja_frog")),
		"Beating level 4 must unlock Ninja Frog")

	# Dòng nhắc trên đầu.
	SaveManager.levels_completed = 0
	_check(GameManager.character_lock_label(GameManager.load_character("virtual_guy")) == "UNLOCK LEVEL 2",
		"Locked Virtual Guy must show \"UNLOCK LEVEL 2\"")
	_check(GameManager.character_lock_label(GameManager.load_character("mask_dude")) == "UNLOCK LEVEL 3",
		"Locked Mask Dude must show \"UNLOCK LEVEL 3\"")
	_check(GameManager.character_lock_label(GameManager.load_character("ninja_frog")) == "UNLOCK LEVEL 4",
		"Locked Ninja Frog must show \"UNLOCK LEVEL 4\"")
	SaveManager.levels_completed = 4
	_check(GameManager.character_lock_label(GameManager.load_character("ninja_frog")) == "",
		"Unlocked characters must show no lock label")

	# mark_level_completed / is_level_completed.
	SaveManager.levels_completed = 0
	SaveManager.mark_level_completed(1)
	_check(SaveManager.is_level_completed(1), "mark_level_completed(1) must stick")
	SaveManager.mark_level_completed(3)
	_check(SaveManager.is_level_completed(2) and SaveManager.is_level_completed(3),
		"Beating level 3 must count every lower level as completed")
	SaveManager.mark_level_completed(2)
	_check(SaveManager.levels_completed == 3,
		"mark_level_completed must never move the counter backwards")