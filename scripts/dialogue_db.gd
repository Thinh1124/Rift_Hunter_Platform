class_name DialogueDB
extends RefCounted
## Nạp và cache res://data/dialogues.json.
## Cấu trúc: { "<dialogue_id>": { "<key>": ["câu 1", "câu 2"] } }
##
## Dùng: DialogueDB.lines("npc_guide", "default")

const PATH: String = "res://data/dialogues.json"

static var _cache: Dictionary = {}
static var _warned: bool = false


static func clear() -> void:
	_cache.clear()
	_warned = false


static func _db() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	if not FileAccess.file_exists(PATH):
		if not _warned:
			_warned = true
			push_warning("DialogueDB: không thấy %s" % PATH)
		return {}
	var text := FileAccess.get_file_as_string(PATH)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_cache = parsed
	else:
		push_error("DialogueDB: %s không phải JSON object hợp lệ." % PATH)
	return _cache


## Danh sách câu cho (dialogue_id, key). Trả về rỗng nếu thiếu dữ liệu.
static func lines(dialogue_id: String, key: String) -> PackedStringArray:
	var out := PackedStringArray()
	var entry: Variant = _db().get(dialogue_id, null)
	if not (entry is Dictionary):
		push_warning("DialogueDB: không có thoại '%s'." % dialogue_id)
		return out
	var raw: Variant = (entry as Dictionary).get(key, null)
	if not (raw is Array):
		return out
	for value in raw as Array:
		out.append(String(value))
	return out