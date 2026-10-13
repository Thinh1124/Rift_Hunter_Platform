extends Node
## DỰNG SpriteFrames CHO KẺ ĐỊCH TỪ ẢNH TRONG assets/enemies/
##
## Chạy:
##   godot --headless --quit-after 900 res://tools/build_enemy_frames.tscn
##
## Vì sao dùng script: mỗi quái có 20-90 file PNG, viết tay AtlasTexture trong
## .tres sẽ hàng trăm dòng và dễ sai. Script quét thư mục, tự sắp frame theo số
## thứ tự rồi lưu .tres.
##
## Quy ước game: Enemy.play_anim() chỉ cần 4 animation --
##   idle / walk / hit / dead
## Thiếu thì play_anim() fallback về idle (quái đứng đơ). Script luôn tạo đủ 4,
## kể cả khi art không có (dùng frame tĩnh) để không bao giờ bị rơi về idle.
##
## Hướng: art có cặp _L_ và _R_. Lấy _R_ (nhìn sang phải), engine tự flip_h
## khi quái quay trái -> không cần nhân bả 2 hướng.

const OUT_DIR: String = "res://assets/frames"
## Phai khop CHINH XAC hoa/thuong voi thu muc tren dia.
## Godot tren Windows chay duoc ca hai, nhung khi export ra Android/Linux
## (phan biet hoa/thuong) thi sai case se mat sach anh.
const ROOT: String = "res://assets/Enemies"

## frames = true  -> ảnh là DẢI ngang, cắt đều thành N frame
## frames = int   -> số frame muốn cắt (<=0 = cả dải)
const ENEMIES: Dictionary = {
	"mushroom": {
		"frame_px": 24,
		"idle": {"dir": "Mushroom/Mushroom_1/Idle", "glob": "Idle_R_*.png", "fps": 6.0},
		"walk": {"dir": "Mushroom/Mushroom_1/Walk", "glob": "Walk_R_*.png", "fps": 10.0},
		"hit": {"dir": "Mushroom/Mushroom_1/Attack", "glob": "Attack_R_*.png", "fps": 12.0},
		"dead": {"dir": "Mushroom/Mushroom_1/Squash", "glob": "Squash_R_*.png", "fps": 10.0, "loop": false},
	},
	"bomb": {
		"frame_px": 24,
		"idle": {"dir": "Bomb/Idle_1", "glob": "Idle_1_R_*.png", "fps": 6.0},
		"walk": {"dir": "Bomb/Walk_1", "glob": "Walk_1_R_*.png", "fps": 12.0},
		"hit": {"dir": "Bomb/Jump_1", "glob": "Jump_1_R_*.png", "fps": 12.0},
		"dead": {"dir": "Bomb/Explode", "glob": "Explode_R_*.png", "fps": 14.0, "loop": false},
	},
	"brickhead": {
		"frame_px": 48,
		# Art chi co Idle (nhieu huong) + Attack, KHONG co walk that.
		# Idle_3 khong co mat - do la frame CHOP MAT, dung no o idle/walk se
		# thay mot cuc gach trong suot, nguoi cham coi nhu bug. Dung Idle_*_F
		# (chinh dien) vi mat no o chinh dien nhìn ro nhat; hinh doi xung nen
		# flip_h khong gay van de gi. Giu Idle_3 cho chop mat / chet.
		# Attack_12 giong het Idle nen khong phai hinh chet.
		"idle": {"files": [
			"Brickhead/Brickhead_1/Idle_1/Idle_1_F.png",
			"Brickhead/Brickhead_1/Idle_1/Idle_1_F.png",
			"Brickhead/Brickhead_1/Idle_3/Idle_3.png",
			"Brickhead/Brickhead_1/Idle_1/Idle_1_F.png",
		], "fps": 5.0},
		"walk": {"files": [
			"Brickhead/Brickhead_1/Idle_1/Idle_1_F.png",
			"Brickhead/Brickhead_1/Idle_2/Idle_2_F.png",
			"Brickhead/Brickhead_1/Idle_4/Idle_4_F.png",
			"Brickhead/Brickhead_1/Idle_1/Idle_1_F.png",
		], "fps": 10.0},
		"hit": {"files": [
			"Brickhead/Brickhead_1/Idle_1/Idle_1_F.png",
			"Brickhead/Brickhead_1/Idle_3/Idle_3.png",
		], "fps": 9.0},
		"dead": {"files": [
			"Brickhead/Brickhead_1/Idle_1/Idle_1_F.png",
			"Brickhead/Brickhead_1/Idle_3/Idle_3.png",
			"Brickhead/Brickhead_1/Idle_3/Idle_3.png",
		], "fps": 6.0, "loop": false},
	},
	"balloon": {
		"frame_px": 32,
		"idle": {"dir": "Balloon/Balloon_1/Idle_2", "glob": "Idle_2_R_*.png", "fps": 5.0},
		"walk": {"dir": "Balloon/Balloon_1/Dash", "glob": "Dash_R_*.png", "fps": 14.0},
		"hit": {"dir": "Balloon/Balloon_1/Idle_3", "glob": "Idle_3_R_*.png", "fps": 12.0},
		"dead": {"dir": "Balloon/Balloon_1/Explode", "glob": "Explode_R_*.png", "fps": 16.0, "loop": false},
	},
	"bee": {
		"frame_px": 24,
		"idle": {"dir": "Bee/Idle_2", "glob": "Idle_2_R_*.png", "fps": 10.0},
		"walk": {"dir": "Bee/Idle_4", "glob": "Idle_4_R_*.png", "fps": 16.0},
		"hit": {"dir": "Bee/Attack_1", "glob": "Attack_1_R_*.png", "fps": 14.0},
		"dead": {"dir": "Bee/Attack_2", "glob": "Attack_2_R_*.png", "fps": 14.0, "loop": false},
	},
	"cactus": {
		"frame_px": 24,
		"idle": {"dir": "Cactus/Cactus_1/Idle_1", "glob": "Idle_1_R_*.png", "fps": 5.0},
		"walk": {"dir": "Cactus/Cactus_1/Idle_3", "glob": "Idle_3_R_*.png", "fps": 10.0},
		"hit": {"dir": "Cactus/Cactus_1/Attack_1", "glob": "Attack_1_R_*.png", "fps": 12.0},
		"dead": {"dir": "Cactus/Cactus_1/Attack_3", "glob": "Attack_3_R_*.png", "fps": 10.0, "loop": false},
	},
	"demon_a": {
		"frame_px": 100,
		"idle": {"sheet": "Demon_A/Demon_A_Idle.png", "fps": 8.0},
		"walk": {"sheet": "Demon_A/Demon_A_Walk.png", "fps": 12.0},
		"hit": {"sheet": "Demon_A/Demon_A_Hurt.png", "fps": 10.0},
		"dead": {"sheet": "Demon_A/Demon_A_Death.png", "fps": 8.0, "loop": false},
	},
}

## Thứ tự ưu tiên khi tìm frame dự phòng cho animation thiếu.
const FALLBACK_CHAIN: Array[String] = ["idle", "walk"]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	print("=== DUNG SPRITEFRAMES TU res://assets/enemies ===\n")
	var problems: PackedStringArray = PackedStringArray()
	for id: String in ENEMIES:
		var cfg: Dictionary = ENEMIES[id]
		var frames := SpriteFrames.new()
		frames.remove_animation(&"default")
		for anim: String in ["idle", "walk", "hit", "dead"]:
			var list: Array[Texture2D] = _textures_for(id, cfg, anim, problems)
			if list.is_empty():
				list = _fallback_for(id, cfg, anim, problems)
			frames.add_animation(StringName(anim))
			frames.set_animation_speed(StringName(anim), float(cfg.get(anim, {}).get("fps", 8.0)))
			frames.set_animation_loop(StringName(anim), bool(cfg.get(anim, {}).get("loop", anim != "dead")))
			for tex: Texture2D in list:
				frames.add_frame(StringName(anim), tex)
		var out_path: String = "%s/%s_frames.tres" % [OUT_DIR, id]
		var err: int = ResourceSaver.save(frames, out_path)
		var total: int = 0
		for anim: String in ["idle", "walk", "hit", "dead"]:
			total += frames.get_frame_count(StringName(anim))
		print("  %-12s -> %-44s %s  (%d frame)" % [
			id, out_path.get_file(), "OK " if err == OK else "LOI", total])

	if problems.is_empty():
		print("\nKhong co thieu file nao.")
	else:
		print("\nCANH BAO (%d):" % problems.size())
		for p in problems:
			print("  - %s" % p)
	print("Xong.")
	get_tree().quit()


## Gom texture cho 1 animation. Tra ve mang rong neu khong tim duoc.
func _textures_for(id: String, cfg: Dictionary, anim: String, problems: PackedStringArray) -> Array[Texture2D]:
	var spec: Dictionary = cfg.get(anim, {})
	if spec.is_empty():
		return []
	var out: Array[Texture2D] = []

	# Dải ngang: cắt đều theo chiều rộng, ROI cắt sát nội dung từng frame.
	if spec.has("sheet"):
		var sheet_path: String = "%s/%s" % [ROOT, spec["sheet"]]
		var sheet: Texture2D = _load_tex(sheet_path)
		if sheet == null:
			problems.append("%s/%s: khong tim thay %s" % [id, anim, spec["sheet"]])
			return []
		var img: Image = sheet.get_image()
		if img == null:
			problems.append("%s/%s: khong doc duoc anh %s" % [id, anim, spec["sheet"]])
			return []
		if img.is_compressed():
			if img.decompress() != OK:
				problems.append("%s/%s: khong giai nen duoc %s" % [id, anim, spec["sheet"]])
				return []
		# So vung chua pixel trong TOAN bo sheet.
		var used: Rect2i = img.get_used_rect()
		if used.size.x <= 0 or used.size.y <= 0:
			problems.append("%s/%s: %s hoan toan trong suot" % [id, anim, spec["sheet"]])
			return []
		var fw: int = maxi(int(cfg.get("frame_px", 0)), 1)
		var count: int = int(spec.get("frames", 0))
		if count <= 0:
			# Dem theo CHIEU RONG THAT cua anh, khong theo vung co pixel.
			# Frame dau/cuoi co the trong suot mot phan nen vung used se hep
			# lai -> tinh so frame se thieu o hai dau.
			count = maxi(img.get_width() / fw, 1)
		print("    [%s/%s] %dx%d -> %d frame, vung co pixel x=%d..%d y=%d..%d" % [
			id, anim, img.get_width(), img.get_height(), count,
			used.position.x, used.position.x + used.size.x,
			used.position.y, used.position.y + used.size.y])
		for i in count:
			# O frame lay theo luoi cua ca anh (0, fw, 2*fw ...), khong dua theo
			# vung trong suot - neu dua theo used thi frame se lech mat 1 phia.
			var cell := Rect2i(i * fw, 0, fw, img.get_height())
			# Cat sat phan co pixel cua chinh frame do.
			var tight: Rect2i = img.get_region(cell).get_used_rect()
			var clip: Rect2i = Rect2i(cell.position + tight.position, tight.size)
			if clip.size.x <= 0 or clip.size.y <= 0:
				problems.append("%s/%s: frame %d trong %s bi trong suot" % [id, anim, i + 1, spec["sheet"]])
				continue
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(clip)
			atlas.filter_clip = true
			out.append(atlas)
		return out

	# Danh sach file co dinh.
	if spec.has("files"):
		for f: String in spec["files"]:
			var p: String = "%s/%s" % [ROOT, f]
			var tex: Texture2D = _load_tex(p)
			if tex == null:
				problems.append("%s/%s: thieu %s" % [id, anim, f])
			else:
				out.append(tex)
		return out

	# Quet thu muc theo glob.
	var dir_path: String = "%s/%s" % [ROOT, spec.get("dir", "")]
	var d := DirAccess.open(dir_path)
	if d == null:
		problems.append("%s/%s: khong mo duoc thu muc %s" % [id, anim, dir_path])
		return []
	# PackedStringArray KHONG co sort_custom -> phai qua Array thuong truoc.
	var found: PackedStringArray = PackedStringArray()
	for file_name: String in d.get_files():
		if file_name.ends_with(".png") and String(file_name).match(spec.get("glob", "*.png")):
			found.append(file_name)
	var names: Array[String] = []
	for f: String in found:
		names.append(f)
	names.sort_custom(_natural_less)
	for file_name: String in names:
		var tex: Texture2D = _load_tex("%s/%s" % [dir_path, file_name])
		if tex != null:
			out.append(tex)
	if out.is_empty():
		problems.append("%s/%s: khong co file nao khop '%s' trong %s" % [
			id, anim, spec.get("glob", "*"), dir_path])
	return out


func _fallback_for(id: String, cfg: Dictionary, anim: String, problems: PackedStringArray) -> Array[Texture2D]:
	for key: String in FALLBACK_CHAIN:
		if key == anim:
			continue
		var alt: Array[Texture2D] = _textures_for(id, cfg, key, PackedStringArray())
		if not alt.is_empty():
			problems.append("%s/%s: KHONG co art -> dung lai frame cua '%s'" % [id, anim, key])
			return alt
	problems.append("%s/%s: KHONG co art va khong co animation du phong" % [id, anim])
	return []


func _load_tex(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## So sanh "X_2" < "X_10" (khong phai so sanh chuoi).
func _natural_less(a: String, b: String) -> bool:
	var num_a: int = _tail_number(a)
	var num_b: int = _tail_number(b)
	if num_a != num_b:
		return num_a < num_b
	return a < b


func _tail_number(s: String) -> int:
	var digits: String = ""
	for i in range(s.length() - 1, -1, -1):
		var c: String = s[i]
		if c.is_valid_int():
			digits = c + digits
		elif digits != "":
			break
	return int(digits) if digits != "" else -1