extends Node
## Nghiệm thu hướng nhìn trái/phải của nhân vật.
##
## Sprite vẽ sẵn nhìn sang PHẢI, nên:
##   đi sang phải -> flip_h = false
##   đi sang trái -> flip_h = true
##
## Trước đây Player KHÔNG hề set flip_h -> luôn nhìn phải.

var player: Player
var checks: int = 0
var fails: int = 0


func _ready() -> void:
	player = $Player
	player.camera.enabled = false
	await get_tree().physics_frame
	await get_tree().physics_frame

	print("=== FACING TEST ===")
	_test_default_facing()
	await _test_flip_right()
	await _test_flip_left()
	await _test_release_keeps_direction()
	await _test_projectile_uses_facing()

	print("--- ket qua ---")
	print("PASS" if fails == 0 else "FAIL (%d/%d)" % [fails, checks])
	print("=== FACING TEST DONE ===")
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()


## Chờ n physics frame để Player._physics_process() đọc input.
func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _press(action: StringName) -> void:
	Input.action_press(action)


func _release(action: StringName) -> void:
	Input.action_release(action)


func _flip() -> bool:
	return player.sprite.flip_h


func _test_default_facing() -> void:
	print("--- 1. mac dinh ---")
	print("facing=%d flip_h=%s" % [player.facing, _flip()])
	_check("mặc định nhìn phải (facing = 1)", player.facing == 1)
	_check("mặc định không lật hình (flip_h = false)", _flip() == false)


func _test_flip_right() -> void:
	print("--- 2. di sang PHAI ---")
	_press(&"move_right")
	await _frames(6)
	print("facing=%d flip_h=%s input_dir=%.1f" % [player.facing, _flip(), player.input_dir])
	_check("bấm phải -> facing = 1", player.facing == 1)
	_check("bấm phải -> sprite KHÔNG lật", _flip() == false)
	_release(&"move_right")
	await _frames(2)


func _test_flip_left() -> void:
	print("--- 3. di sang TRAI ---")
	_press(&"move_left")
	await _frames(6)
	print("facing=%d flip_h=%s input_dir=%.1f" % [player.facing, _flip(), player.input_dir])
	_check("bấm trái -> facing = -1", player.facing == -1)
	_check("bấm trái -> sprite LẬT hình (flip_h = true)", _flip() == true)
	_check("bấm trái -> chạy sang trái (velocity.x < 0)", player.velocity.x < 0.0,
		str(player.velocity.x))


func _test_release_keeps_direction() -> void:
	print("--- 4. tha phim ---")
	_release(&"move_left")
	await _frames(4)
	print("facing=%d flip_h=%s" % [player.facing, _flip()])
	# Thả phim không được đảo hướng: nhân vật đứng yên nhìn về hướng vừa đi.
	_check("thả phim -> giữ nguyên hướng", player.facing == -1 and _flip() == true)


func _test_projectile_uses_facing() -> void:
	print("--- 5. dan phai theo huong nhin ---")
	player.projectile_scene = load("res://scenes/objects/Projectile.tscn") as PackedScene
	player.attack_cooldown_timer.stop()
	# throw_projectile() tự add đạn vào parent của Player, nên lấy theo giá trị
	# trả về thay vì dò lại cây node.
	var projectile: Projectile = player.throw_projectile()
	if projectile == null:
		_check("bắn được đạn", false, "throw_projectile() trả null")
		return
	var direction: int = projectile.direction
	print("projectile direction=%d  facing=%d" % [direction, player.facing])
	_check("đạn bắn sang trái khi đang nhìn trái", direction == -1, str(direction))
	projectile.queue_free()


func _check(label: String, ok: bool, detail: String = "") -> void:
	checks += 1
	if ok:
		print("   PASS  ", label)
	else:
		fails += 1
		print("   FAIL  ", label, "  ", detail)