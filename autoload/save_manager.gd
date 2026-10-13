extends Node
## Lưu/đọc tiến độ bằng JSON ở user://save.json.

const SAVE_PATH: String = "user://save.json"
const MAX_STARS: int = 3

var unlocked_level: int = 1
var best_score: int = 0
var stars: Dictionary[String, int] = {}
var selected_character_id: String = ""
var music_vol: float = 0.8
var sfx_vol: float = 1.0
var vibration: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_data()


func default_data() -> Dictionary:
	return {
		"unlocked_level": 1,
		"best_score": 0,
		"stars": {},
		"selected_character_id": "",
		"music_vol": 0.8,
		"sfx_vol": 1.0,
		"vibration": true,
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
		"best_score": best_score,
		"stars": stars_out,
		"selected_character_id": selected_character_id,
		"music_vol": music_vol,
		"sfx_vol": sfx_vol,
		"vibration": vibration,
	}


func _from_dictionary(source: Dictionary) -> void:
	unlocked_level = maxi(int(source.get("unlocked_level", 1)), 1)
	best_score = maxi(int(source.get("best_score", 0)), 0)
	selected_character_id = String(source.get("selected_character_id", ""))
	music_vol = clampf(float(source.get("music_vol", 0.8)), 0.0, 1.0)
	sfx_vol = clampf(float(source.get("sfx_vol", 1.0)), 0.0, 1.0)
	vibration = bool(source.get("vibration", true))
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


func reset_save() -> void:
	load_data()
	save()