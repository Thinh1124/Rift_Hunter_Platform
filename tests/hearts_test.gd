extends Node
## Nghiệm thu HUD tim: đúng số tim, đúng số tim ĐẦY, theo từng nhân vật.
##
## Bug đã gặp: HealthComponent._ready() chạy trước Player._ready nên nạp
## current = max_health GỐC (3). apply_character() đổi max_health theo nhân vật
## nhưng không nạp lại current -> vào màn xong nhân vật 5 máu chỉ còn 3.

const PLAYER_SCENE: String = "res://scenes/player/Player.tscn"
const HUD_SCENE: String = "res://scenes/ui/HUD.tscn"
## Level thật để kiểm tra đúng luồng vào màn, không chỉ dựng Player trần.
const LEVEL_SCENE: String = "res://scenes/levels/Level0.tscn"

## Số tim MONG ĐỢI của từng nhân vật (max_hp gốc 3 + max_hp_bonus).
const EXPECTED: Dictionary[String, int] = {
	"pink_man": 3,
	"virtual_guy": 5,
	"mask_dude": 4,
	"ninja_frog": 2,
}

var checks: int = 0
var fails: int = 0


func _ready() -> void:
	await _run()
	print("%s (%d/%d)" % ["PASS" if fails == 0 else "FAIL", checks - fails, checks])
	get_tree().quit()


func _check(condition: bool, label: String, detail: String = "") -> void:
	checks += 1
	if not condition:
		fails += 1
		print("   FAIL  ", label, ("  " + detail) if detail != "" else "")


func _run() -> void:
	print("=== HUD TIM THEO NHAN VAT ===")
	# Bảo đảm mỗi lần vào đều bắt đầu đầy máu, không dính lượt trước.
	for id: String in EXPECTED:
		var data: CharacterData = GameManager.load_character(id)
		_check(data != null, "load được nhân vật '%s'" % id)
		if data == null:
			continue
		GameManager.selected_character = data

		var player: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
		add_child(player)
		# HUD.tscn gốc là CanvasLayer, KHÔNG phải Control.
		var hud: CanvasLayer = (load(HUD_SCENE) as PackedScene).instantiate() as CanvasLayer
		add_child(hud)
		for i in 12:
			await get_tree().process_frame

		var want: int = EXPECTED[id]
		var got_max: int = maxi(player.health.max_health, 0)
		var got_cur: int = player.health.current
		var row: PipRow = hud.find_child("HeartsBox", true, false) as PipRow
		var icons: int = 0
		var filled: int = 0
		var dim: Color = row.dim_color if row != null else Color(0, 0, 0, 0)
		if row != null:
			for c in row.get_children():
				var tr := c as TextureRect
				if tr == null:
					continue
				icons += 1
				if tr.modulate != dim:
					filled += 1

		print("  %-12s HP %d/%d  tim %d (dau %d)  -> can %d (dau %d)" % [
			id, got_cur, got_max, icons, filled, want, want])
		_check(got_max == want, "%s: max_health phải bằng %d" % [id, want], str(got_max))
		_check(got_cur == want, "%s: vào màn phải ĐẦY máu (%d)" % [id, want], str(got_cur))
		_check(icons == want, "%s: HUD phải vẽ đủ %d tim" % [id, want], str(icons))
		_check(filled == want, "%s: tất cả %d tim phải ĐẦY lúc vào màn" % [id, want], str(filled))

		# Bắn vào giữa: mất 1 máu -> đúng 1 tim tắt.
		player.health.take_damage(1, Vector2.ZERO)
		for i in 4:
			await get_tree().process_frame
		var filled2: int = 0
		if row != null:
			for c in row.get_children():
				var tr := c as TextureRect
				if tr != null and tr.modulate != dim:
					filled2 += 1
		_check(filled2 == want - 1,
			"%s: mất 1 máu -> còn %d tim đầy" % [id, want - 1], str(filled2))

		player.queue_free()
		hud.queue_free()
		for i in 3:
			await get_tree().process_frame

	await _check_real_levels()


## Cùng phép kiểm nhưng chạy trong LEVEL thật (Level0): đây mới là đường người
## chơi đi. Bắt được lỗi mà dựng Player trần không thấy.
func _check_real_levels() -> void:
	print("")
	print("=== TRONG LEVEL THAT (Level0) ===")
	for id: String in EXPECTED:
		var data: CharacterData = GameManager.load_character(id)
		if data == null:
			continue
		GameManager.selected_character = data

		var level: Node = (load(LEVEL_SCENE) as PackedScene).instantiate() as Node
		add_child(level)
		for i in 20:
			await get_tree().process_frame

		var player: Player = get_tree().get_first_node_in_group(&"player") as Player
		var hud: CanvasLayer = level.get_node_or_null(^"HUD") as CanvasLayer
		var want: int = EXPECTED[id]
		if player == null or hud == null:
			_check(false, "%s: level phai co Player + HUD" % id)
			level.queue_free()
			continue

		var row: PipRow = hud.find_child("HeartsBox", true, false) as PipRow
		var icons: int = 0
		var filled: int = 0
		var dim: Color = row.dim_color if row != null else Color(0, 0, 0, 0)
		if row != null:
			for c in row.get_children():
				var tr := c as TextureRect
				if tr == null:
					continue
				icons += 1
				if tr.modulate != dim:
					filled += 1

		print("  %-12s maxHP=%d current=%d | HUD: %d tim (%d dau)" % [
			id, player.health.max_health, player.health.current, icons, filled])
		_check(player.health.max_health == want,
			"[level] %s: max_health = %d" % [id, want], str(player.health.max_health))
		_check(player.health.current == want,
			"[level] %s: vào màn phải ĐẦY máu (%d)" % [id, want], str(player.health.current))
		_check(icons == want, "[level] %s: HUD vẽ đủ %d tim" % [id, want], str(icons))
		_check(filled == want, "[level] %s: HUD %d tim đều ĐẦY" % [id, want], str(filled))

		level.queue_free()
		for i in 4:
			await get_tree().process_frame