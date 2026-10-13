extends Node
## Lưu/đọc tiến độ bằng JSON ở user://save.json.

const SAVE_PATH: String = "user://save.json"
const MAX_STARS: int = 3
## Giới hạn 2 slider "nút ảo" trong Settings (khớp min/max của HSlider trong scene).
const TOUCH_OPACITY_MIN: float = 0.2
const TOUCH_OPACITY_MAX: float = 1.0
const TOUCH_SCALE_MIN: float = 0.8
const TOUCH_SCALE_MAX: float = 1.3

var unlocked_level: int = 1
## Màn CAO NHẤT đã vượt qua (0 = chưa vượt màn nào).
## `unlocked_level` là màn lớn nhất được mở khoá, tức luôn = levels_completed + 1
## sau khi chơi từ đầu; nhưng nó cộng dồn theo cách khác nếu người chơi từng đổi
## save. Giữ 2 biến tách bạch: cái này trả lời "đã VƯỢT màn N chưa" — dùng cho
## mở khoá nhân vật.
var levels_completed: int = 0
var best_score: int = 0
var stars: Dictionary[String, int] = {}
var selected_character_id: String = ""
var music_vol: float = 0.8
var sfx_vol: float = 1.0
var vibration: bool = true
## Độ mờ nút cảm ứng (0.2 - 1.0).
var touch_opacity: float = 0.5
## Hệ số kích thước nút cảm ứng (0.8 - 1.3).
var touch_scale: float = 1.0
## true = đã xem xong ải hướng dẫn (Level0). Chỉ vào lần đầu.
var tutorial_completed: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_data()


func default_data() -> Dictionary:
	return {
		"unlocked_level": 1,
		"levels_completed": 0,
		"best_score": 0,
		"stars": {},
		"selected_character_id": "",
		"music_vol": 0.8,
		"sfx_vol": 1.0,
		"vibration": true,
		"touch_opacity": touch_opacity,
		"touch_scale": touch_scale,
		"tutorial_completed": tutorial_completed,
	}


func save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: không ghi được %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(to_dictionary(), "\t"))
	file.close()


func load_data() -> void:
	unlocked_level = 1
	best_score = 0
	stars = {}
	selected_character_id = ""
	music_vol = 0.8
	sfx_vol = 1.0
	vibration = true
	touch_opacity = 0.5
	touch_scale = 1.0
	tutorial_completed = false
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("SaveManager: không mở được %s" % SAVE_PATH)
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_from_dictionary(parsed)


func to_dictionary() -> Dictionary:
	var stars_out: Dictionary[String, int] = {}
	for key: String in stars:
		stars_out[key] = stars[key]
	return {
		"unlocked_level": unlocked_level,
		"levels_completed": levels_completed,
		"best_score": best_score,
		"stars": stars_out,
		"selected_character_id": selected_character_id,
		"music_vol": music_vol,
		"sfx_vol": sfx_vol,
		"vibration": vibration,
		"touch_opacity": touch_opacity,
		"touch_scale": touch_scale,
		"tutorial_completed": tutorial_completed,
	}


func _from_dictionary(source: Dictionary) -> void:
	unlocked_level = maxi(int(source.get("unlocked_level", 1)), 1)
	# Save cũ chưa có "levels_completed": suy ra từ unlocked_level (màn lớn nhất
	# được mở = màn vừa vượt + 1). Không suy ra thì người đã vượt màn 2 sẽ mất
	# nhân vật ngay khi cơ chế mở khoá được thêm vào.
	levels_completed = maxi(int(source.get("levels_completed", unlocked_level - 1)), 0)
	unlocked_level = maxi(unlocked_level, levels_completed + 1)
	best_score = maxi(int(source.get("best_score", 0)), 0)
	selected_character_id = String(source.get("selected_character_id", ""))
	music_vol = clampf(float(source.get("music_vol", 0.8)), 0.0, 1.0)
	sfx_vol = clampf(float(source.get("sfx_vol", 1.0)), 0.0, 1.0)
	vibration = bool(source.get("vibration", true))
	touch_opacity = clampf(float(source.get("touch_opacity", 0.5)), TOUCH_OPACITY_MIN, TOUCH_OPACITY_MAX)
	touch_scale = clampf(float(source.get("touch_scale", 1.0)), TOUCH_SCALE_MIN, TOUCH_SCALE_MAX)
	tutorial_completed = bool(source.get("tutorial_completed", false))
	stars = {}
	var raw_stars: Variant = source.get("stars", {})
	if raw_stars is Dictionary:
		for key: Variant in raw_stars:
			stars[String(key)] = clampi(int(raw_stars[key]), 0, MAX_STARS)


func unlock(level: int) -> void:
	if level <= unlocked_level:
		return
	unlocked_level = clampi(level, 1, 99)
	save()


func set_stars(level: int, n: int) -> void:
	stars[str(level)] = clampi(n, 0, MAX_STARS)
	save()


## Ghi nhận đã vượt qua màn `level` (dùng cho mở khoá nhân vật).
## Không gọi save() — _on_level_completed gọi unlock() ngay sau đó.
func mark_level_completed(level: int) -> void:
	if level > levels_completed:
		levels_completed = clampi(level, 0, 99)


## Đã vượt qua màn `level` chưa.
func is_level_completed(level: int) -> bool:
	return levels_completed >= level


func get_stars(level: int) -> int:
	return stars.get(str(level), 0)


func submit_score(score: int) -> void:
	if score <= best_score:
		return
	best_score = score
	save()


func set_music_volume(v: float) -> void:
	music_vol = clampf(v, 0.0, 1.0)
	save()


func set_sfx_volume(v: float) -> void:
	sfx_vol = clampf(v, 0.0, 1.0)
	save()


func set_vibration(enabled: bool) -> void:
	vibration = enabled
	save()


## Kéo slider Độ mờ nút ảo. Lưu ngay để kéo rồi tắt game vẫn giữ.
func set_touch_opacity(value: float) -> void:
	touch_opacity = clampf(value, TOUCH_OPACITY_MIN, TOUCH_OPACITY_MAX)
	save()


## Kéo slider Kích thước nút ảo. Lưu ngay để kéo rồi tắt game vẫn giữ.
func set_touch_scale(value: float) -> void:
	touch_scale = clampf(value, TOUCH_SCALE_MIN, TOUCH_SCALE_MAX)
	save()


## Đánh dấu đã xong ải hướng dẫn -> từ lần sau vào game bỏ qua Level0.
func mark_tutorial_completed() -> void:
	if tutorial_completed:
		return
	tutorial_completed = true
	save()


## true = cần chạy ải hướng dẫn trước khi vào ải thật.
func needs_tutorial() -> bool:
	return not tutorial_completed


func reset_save() -> void:
	load_data()
	save()