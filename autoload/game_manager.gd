extends Node
## Điều phối vòng chơi: nhân vật đã chọn, điểm, mạng, cổng, trái cây, chuyển màn.
## BẢNG THƯỞNG/PHẠT nằm ở đây (Player chỉ cung cấp hàm: heal/add_shield/respawn):
##   Trái cây      -> +100 điểm, fruit_count+1; đủ 50 quả -> +1 mạng
##   Tim           -> +1 HP (tối đa max_hp)
##   Khiên         -> add_shield(8)
##   Hạ quái       -> +200 điểm (boss +2000)
##   Rơi KillZone  -> -1 mạng, respawn (Player tự gọi lose_life)
##   Hết mạng      -> game_over
##   Hoàn thành ải -> 3 sao HP đầy / 2 sao HP>=2 / 1 sao còn lại

const LEVEL_COUNT: int = 6
const BOSS_LEVEL: int = 6
const START_LIVES: int = 3
const FRUIT_PER_LIFE: int = 50
const FRUIT_SCORE: int = 100
const ENEMY_KILL_SCORE: int = 200
const BOSS_KILL_SCORE: int = 2000
const SHIELD_DURATION: float = 8.0
const LEVEL_PATH_FORMAT: String = "res://scenes/levels/Level%d.tscn"
const DEFAULT_CHARACTER_PATH: String = "res://data/characters/default.tres"
const SILENT_DB: float = -80.0

@export_range(1, 6, 1) var default_level: int = 1
@export var main_menu_scene: String = "res://scenes/ui/MainMenu.tscn"
@export_range(0.0, 2.0, 0.05) var fade_time: float = 0.3

## Nhân vật đang chơi. Nạp từ res://data/characters/default.tres nếu file tồn tại.
var selected_character: CharacterData
var score: int = 0
var lives: int = START_LIVES
var total_gates: int = 0
var remaining_gates: int = 0
var fruit_count: int = 0
var current_level: int = 1
var last_checkpoint: Vector2 = Vector2.ZERO
## Số sao của màn vừa hoàn thành (lưu vào SaveManager).
var last_stars: int = 0

var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _changing_scene: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	selected_character = _load_default_character()
	EventBus.gate_closed.connect(_on_gate_closed)
	EventBus.checkpoint_reached.connect(_on_checkpoint_reached)
	EventBus.level_completed.connect(_on_level_completed)
	EventBus.score_changed.emit(score)
	EventBus.lives_changed.emit(lives)
	EventBus.fruit_collected.emit(fruit_count)


func _load_default_character() -> CharacterData:
	# Ưu tiên nhân vật đã lưu lần trước, không có thì default.tres.
	var saved := load_character(SaveManager.selected_character_id)
	if saved != null:
		return saved
	if not ResourceLoader.exists(DEFAULT_CHARACTER_PATH):
		return null
	var resource: CharacterData = ResourceLoader.load(DEFAULT_CHARACTER_PATH) as CharacterData
	if resource == null:
		push_warning("GameManager: không load được %s" % DEFAULT_CHARACTER_PATH)
	return resource


# --- Nhân vật --------------------------------------------------------------

func _first_player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player


## id rỗng -> ưu tiên default.tres, không có -> null.
func load_character(id: String) -> CharacterData:
	if id != "" and ResourceLoader.exists("res://data/characters/%s.tres" % id):
		var data: CharacterData = ResourceLoader.load("res://data/characters/%s.tres" % id) as CharacterData
		if data != null:
			return data
	if ResourceLoader.exists(DEFAULT_CHARACTER_PATH):
		return ResourceLoader.load(DEFAULT_CHARACTER_PATH) as CharacterData
	return null


func all_characters() -> Array[CharacterData]:
	var out: Array[CharacterData] = []
	var dir := DirAccess.open("res://data/characters/")
	if dir == null:
		return out
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var data: CharacterData = ResourceLoader.load("res://data/characters/%s" % file_name) as CharacterData
		if data != null:
			out.append(data)
	out.sort_custom(func(a: CharacterData, b: CharacterData) -> bool:
		return String(a.display_name) < String(b.display_name))
	return out


func select_character(data: CharacterData) -> void:
	if data == null:
		return
	selected_character = data
	SaveManager.selected_character_id = String(data.id)
	SaveManager.save()


# --- BẢNG THƯỞNG / PHẠT ---------------------------------------------------

## Pickup gọi hàm này khi người chơi chạm vào.
func apply_pickup(kind: StringName, amount: int, by: Node) -> void:
	match kind:
		&"fruit":
			collect_fruit(maxi(amount, 1))
		&"heart":
			if heal_player(by, maxi(amount, 1)) > 0:
				AudioManager.play_sfx(&"heart")
		&"shield":
			if shield_player(by, SHIELD_DURATION):
				AudioManager.play_sfx(&"shield")
		_:
			push_warning("GameManager: không biết loại đồ '%s'." % kind)


## +100 điểm mỗi quả; đủ FRUIT_PER_LIFE quả -> +1 mạng.
func collect_fruit(amount: int = 1) -> void:
	var n: int = maxi(amount, 0)
	if n == 0:
		return
	add_score(FRUIT_SCORE * n)
	fruit_count += n
	while fruit_count >= FRUIT_PER_LIFE:
		fruit_count -= FRUIT_PER_LIFE
		lives += 1
		EventBus.lives_changed.emit(lives)
		AudioManager.play_sfx(&"one_up")
	EventBus.fruit_collected.emit(fruit_count)
	AudioManager.play_sfx(&"fruit")


## Hạ quái (boss = true -> +2000).
func report_enemy_killed(is_boss: bool = false) -> void:
	add_score(BOSS_KILL_SCORE if is_boss else ENEMY_KILL_SCORE)


## Tim: trả về số HP thực sự hồi được.
func heal_player(player: Node, amount: int) -> int:
	var p := player as Player
	if p == null:
		return 0
	return p.heal(amount)


## Khiên: trả về true nếu áp dụng được.
func shield_player(player: Node, duration: float) -> bool:
	var p := player as Player
	if p == null:
		return false
	p.add_shield(duration)
	return true


## 3 sao HP đầy / 2 sao HP>=2 / 1 sao còn lại.
func compute_stars(cur_hp: int, max_hp: int) -> int:
	if max_hp <= 0 or cur_hp <= 0:
		return 1
	if cur_hp >= max_hp:
		return 3
	if cur_hp >= 2:
		return 2
	return 1


func stars_of(level: int) -> int:
	return SaveManager.get_stars(level)


# --- Cổng ------------------------------------------------------------------

## Đếm các node trong group "gate", bỏ qua BigGate (cổng boss).
func register_gates() -> void:
	var count: int = 0
	for node in get_tree().get_nodes_in_group(&"gate"):
		if _is_boss_gate(node):
			continue
		count += 1
	total_gates = count
	remaining_gates = total_gates
	EventBus.gates_changed.emit(remaining_gates, total_gates)


func _is_boss_gate(node: Node) -> bool:
	if node.get_script() != null and node.get_script().get_global_name() == &"BigGate":
		return true
	return node.get(&"is_boss_gate") == true


## GameManager chỉ đếm - ExitGate tự lắng nghe để phát level_completed.
func _on_gate_closed(_id: StringName) -> void:
	remaining_gates = maxi(remaining_gates - 1, 0)
	EventBus.gates_changed.emit(remaining_gates, total_gates)


# --- Checkpoint / sao ------------------------------------------------------

func reach_checkpoint(pos: Vector2) -> void:
	_on_checkpoint_reached(pos)


func _on_checkpoint_reached(pos: Vector2) -> void:
	last_checkpoint = pos


func _on_level_completed() -> void:
	var p: Player = _first_player()
	if p != null and p.health != null:
		last_stars = compute_stars(p.health.current, p.health.max_health)
	else:
		last_stars = 1
	SaveManager.set_stars(current_level, last_stars)
	SaveManager.submit_score(score)


# --- Điểm / mạng -----------------------------------------------------------

func add_score(n: int) -> void:
	score = maxi(score + n, 0)
	EventBus.score_changed.emit(score)


func lose_life() -> void:
	lives = maxi(lives - 1, 0)
	EventBus.lives_changed.emit(lives)
	if lives == 0:
		EventBus.game_over.emit()


func reset_run() -> void:
	score = 0
	lives = START_LIVES
	fruit_count = 0
	last_checkpoint = Vector2.ZERO
	EventBus.score_changed.emit(score)
	EventBus.lives_changed.emit(lives)
	EventBus.fruit_collected.emit(fruit_count)


# --- Chuyển màn ------------------------------------------------------------

func level_path(level: int) -> String:
	return LEVEL_PATH_FORMAT % level


func is_boss_level(level: int) -> bool:
	return level == BOSS_LEVEL


func go_to_level(level: int) -> void:
	current_level = clampi(level, 1, LEVEL_COUNT)
	last_checkpoint = Vector2.ZERO
	SaveManager.unlock(current_level)
	_change_scene(level_path(current_level))


func restart_level() -> void:
	last_checkpoint = Vector2.ZERO
	go_to_level(current_level)


func go_to_menu() -> void:
	_change_scene(main_menu_scene)


func _change_scene(path: String) -> void:
	if _changing_scene:
		return
	_changing_scene = true
	await _fade(fade_time, 1.0)
	var err: int = get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("GameManager: không load được scene '%s' (mã %d)." % [path, err])
	await get_tree().process_frame
	await get_tree().process_frame
	_changing_scene = false
	await _fade(fade_time, 0.0)


func _fade(duration: float, target_alpha: float) -> void:
	if duration <= 0.0:
		return
	_ensure_fade_rect()
	_fade_rect.visible = true
	_fade_rect.modulate.a = 1.0 - target_alpha
	var tween := create_tween()
	tween.tween_property(_fade_rect, "modulate:a", target_alpha, duration)
	await tween.finished
	_fade_rect.visible = false


func _ensure_fade_rect() -> void:
	if _fade_rect != null:
		return
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 128
	_fade_layer.name = "FadeLayer"
	add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.name = "FadeRect"
	_fade_rect.color = Color(0, 0, 0, 1)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_layer.add_child(_fade_rect)
