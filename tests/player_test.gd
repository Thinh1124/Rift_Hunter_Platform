extends Node2D
## Nghiệm thu Player: chiều cao nhảy, jump cut, coyote, không kẹt tường.

const GROUND_Y: float = 288.0
const TILE: float = 16.0
const GAP_LEFT: float = 300.0
const GAP_RIGHT: float = 380.0
const WALL_LEFT: float = 592.0   # mép trái của bức tường
const PLAYER_R: float = 6.0      # bán kính capsule

var player: Player
var fails: int = 0


func _ready() -> void:
	player = $Player
	# Các phép so sánh vật lý (chiều cao nhảy, tốc độ chạy) viết theo NHÂN VẬT GỐC
	# (jump_mult / speed_mult = 1.0). Không ghim lại thì kết quả đổi theo nhân vật
	# đang lưu trong save của người chơi -> test fail lung tung.
	var base: CharacterData = GameManager.load_character("pink_man")
	if base != null:
		player.apply_character(base)
	print("=== PLAYER TEST ===")
	print("character      : ", player.character.display_name if player.character else "null", " (ghim de on dinh)")
	print("anim co idle/run/jump/fall/hit/dead: ", _has_all_anims())
	print("sprite_frames  : ", player.sprite.sprite_frames != null)
	print("hurtbox mask   : ", player.hurtbox.collision_mask, " (layer5|8 = 144)")
	await get_tree().physics_frame
	await test_full_jump()
	await test_jump_cut()
	await test_no_air_jump()
	await test_coyote()
	await test_wall()
	await report()


func _has_all_anims() -> bool:
	var frames := player.sprite.sprite_frames
	if frames == null:
		return false
	for anim in [&"idle", &"run", &"jump", &"fall", &"hit", &"dead"]:
		if not frames.has_animation(anim):
			print("  !! thieu anim: ", anim)
			return false
	return true


# --- Test -----------------------------------------------------------------

## Giữ jump trọn vòng lên xuống -> đo đỉnh.
func test_full_jump() -> void:
	await _place(Vector2(120, GROUND_Y))
	var height: float = await _measure_jump(90)
	var tiles: float = height / TILE
	print("1) Giu jump     : %.1fpx = %.2f tile" % [height, tiles])
	_check("full jump ~3 tile", absf(tiles - 3.0) < 0.25, "%.2f tile" % tiles)


## Tha jump sau 4 frame -> phai thap hon cua nhay day du.
func test_jump_cut() -> void:
	await _place(Vector2(120, GROUND_Y))
	var full: float = await _measure_jump(90)
	await _place(Vector2(120, GROUND_Y))
	var tap: float = await _measure_jump(4)
	print("2) Tha jump som : %.1fpx (day du %.1fpx)" % [tap, full])
	_check("jump cut thap hon", tap < full * 0.8, "tap=%.1f full=%.1f" % [tap, full])


## Bam jump khi dang bay, het coyote -> khong duoc nhay them.
func test_no_air_jump() -> void:
	await _place(Vector2(120, GROUND_Y))
	Input.action_press(&"jump")
	await _frames(6)
	Input.action_release(&"jump")
	await _frames(10)
	var mid_air_vy: float = player.velocity.y
	var mid_air_y: float = player.global_position.y
	# Bam jump them 1 lan nữa giữa chung
	Input.action_press(&"jump")
	await _frames(4)
	Input.action_release(&"jump")
	var after_vy: float = player.velocity.y
	print("3) Giua khong   : vy truoc=%.1f sau=%.1f  y=%.1f" % [mid_air_vy, after_vy, mid_air_y])
	_check("khong nhay them giua khong", after_vy >= mid_air_vy - 1.0,
		"vy khong bi reset ve -294")
	for i in 90:
		await get_tree().physics_frame
		if player.is_on_floor():
			break


## Chay roi mep roi bam jump trong cua coyote -> van duoc nhay.
func test_coyote() -> void:
	await _place(Vector2(240, GROUND_Y))
	Input.action_press(&"move_right")
	var airborne: bool = false
	var coyote_alive: bool = false
	var height: float = 0.0
	for i in 120:
		await get_tree().physics_frame
		if not player.is_on_floor() and not airborne:
			airborne = true
		if airborne and not coyote_alive and not player.coyote_timer.is_stopped():
			coyote_alive = true
			# Bam jump ngay khi con coyote, GIU MOT LUC de do chieu cao that
			Input.action_press(&"jump")
			for k in 40:
				await get_tree().physics_frame
				height = maxf(height, GROUND_Y - player.global_position.y)
			Input.action_release(&"jump")
			break
	Input.action_release(&"move_right")
	for i in 150:
		await get_tree().physics_frame
		height = maxf(height, GROUND_Y - player.global_position.y)
		if i > 20 and player.is_on_floor():
			break
	print("4) Coyote       : hen=%.2fpx = %.2f tile (roi mep roi nhay)" % [height, height / TILE])
	_check("coyote nhay duoc", height / TILE > 2.5, "%.2f tile" % (height / TILE))
	_check("roi ve duoc dat", player.is_on_floor(), "y=%.1f x=%.1f" % [player.global_position.y, player.global_position.x])


## Cham tuong roi nhay sat tuong -> khong bi dinh vao tuong.
func test_wall() -> void:
	await _place(Vector2(500, GROUND_Y))
	var contact_x: float = WALL_LEFT - PLAYER_R
	Input.action_press(&"move_right")
	for i in 120:
		await get_tree().physics_frame
		if player.global_position.x >= contact_x - 1.0:
			break
	var at_wall: bool = player.global_position.x >= contact_x - 1.5
	var max_x_air: float = player.global_position.x
	Input.action_press(&"jump")
	for i in 8:
		await get_tree().physics_frame
	Input.action_release(&"jump")
	for i in 60:
		await get_tree().physics_frame
		max_x_air = maxf(max_x_air, player.global_position.x)
		if player.is_on_floor():
			break
	Input.action_release(&"move_right")
	var back_on_ground: bool = player.is_on_floor()
	print("5) Tuong        : cham=%s x=%.1f (can=%.1f) x_max_khong=%0.f ve_dat=%s"
		% [at_wall, player.global_position.x, contact_x, max_x_air, back_on_ground])
	_check("cham duoc tuong", at_wall, "x=%.1f can=%.1f" % [player.global_position.x, contact_x])
	_check("khong dinh tuong", max_x_air <= contact_x + 1.0, "x_max=%.1f can=%.1f" % [max_x_air, contact_x])
	_check("roi ve duoc dat", back_on_ground, "y=%.1f" % player.global_position.y)


# --- Helper ---------------------------------------------------------------

func _measure_jump(hold_frames: int) -> float:
	var start_y: float = player.global_position.y
	var peak: float = 0.0
	Input.action_press(&"jump")
	for i in hold_frames:
		await get_tree().physics_frame
		peak = maxf(peak, start_y - player.global_position.y)
	Input.action_release(&"jump")
	for i in 150:
		await get_tree().physics_frame
		peak = maxf(peak, start_y - player.global_position.y)
		if i > 8 and player.is_on_floor():
			break
	return peak


func _place(pos: Vector2) -> void:
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	Input.action_release(&"jump")
	player.velocity = Vector2.ZERO
	player.global_position = pos
	player.state_machine.change_state(&"Idle")
	player.control_enabled = true
	for i in 8:
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("   PASS  ", label)
	else:
		fails += 1
		print("   FAIL  ", label, "  ", detail)


func report() -> void:
	print("--- ket qua ---")
	print("PASS" if fails == 0 else "FAIL (%d)" % fails)
	print("=== PLAYER TEST DONE ===")
	await get_tree().create_timer(0.3).timeout
	get_tree().quit()
