extends Node
## Điều phối vòng chơi: nhân vật đã chọn, điểm, mạng, mảnh rift, cổng, chuyển màn.
## BẢNG THƯỞNG/PHẠT nằm ở đây (Player chỉ cung cấp hàm: heal/add_shield/respawn):
##   Mảnh Rift    -> +50 điểm, shard_count+1; đủ SHARDS_REQUIRED -> mở cổng ra
##   Tim           -> +1 HP (tối đa max_hp)
##   Khiên         -> add_shield(8)
##   Hạ quái       -> +200 điểm (boss +2000)
##   Rơi KillZone  -> -1 mạng, respawn (Player tự gọi lose_life)
##   Hết mạng      -> game_over
##   Hoàn thành ải -> 3 sao HP đầy / 2 sao HP>=2 / 1 sao còn lại

const LEVEL_COUNT: int = 6
## Ải hướng dẫn, chỉ chạy lần đầu (SaveManager.tutorial_completed).
const TUTORIAL_LEVEL: int = 0
const BOSS_LEVEL: int = 6
const START_LIVES: int = 3
## Số mảnh Rift cần thu trong một màn để mở cánh cổng ra.
const SHARDS_REQUIRED: int = 5
const SHARD_SCORE: int = 50
const ENEMY_KILL_SCORE: int = 200
const BOSS_KILL_SCORE: int = 2000
const SHIELD_DURATION: float = 8.0
const LEVEL_PATH_FORMAT: String = "res://scenes/levels/Level%d.tscn"
const DEFAULT_CHARACTER_PATH: String = "res://data/characters/default.tres"
const SILENT_DB: float = -80.0

@export_range(1, 6, 1) var default_level: int = 1
@export var main_menu_scene: String = "res://scenes/ui/MainMenu.tscn"
## Fade do SceneTransition lo (xem autoload/scene_transition.gd).

## Nhân vật đang chơi. Nạp từ res://data/characters/default.tres nếu file tồn tại.
var selected_character: CharacterData
var score: int = 0
var lives: int = START_LIVES
var total_gates: int = 0
var remaining_gates: int = 0
## Số mảnh Rift đã thu trong màn hiện tại (reset mỗi lần vào màn).
var shard_count: int = 0
var current_level: int = 1
var last_checkpoint: Vector2 = Vector2.ZERO
## Số lần chết trong ải hiện tại (NPC dùng để đổi thoại sang "hint").
var deaths_this_level: int = 0
## Số sao của màn vừa hoàn thành (lưu vào SaveManager).
var last_stars: int = 0




func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	selected_character = _load_default_character()
	# GameManager đứng sau SaveManager trong autoload -> lúc này save đã nạp xong,
	# mới áp được volume đã lưu cho AudioManager.
	AudioManager.apply_saved_volumes()
	EventBus.gate_closed.connect(_on_gate_closed)
	EventBus.checkpoint_reached.connect(_on_checkpoint_reached)
	EventBus.level_completed.connect(_on_level_completed)
	EventBus.score_changed.emit(score)
	EventBus.lives_changed.emit(lives)
	EventBus.shards_changed.emit(shard_count, SHARDS_REQUIRED)


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


## Nhân vật này đã mở khoá chưa.
## Mở sẵn -> true. Ngược lại phải vượt qua đúng màn `required_level()`.
func is_character_unlocked(data: CharacterData) -> bool:
	if data == null:
		return false
	var need: int = data.required_level()
	if need <= 0:
		return true
	return SaveManager.is_level_completed(need)


## Dòng chữ hiện trên đầu nhân vật khi chưa mở khoá. Rỗng nếu đã mở.
func character_lock_label(data: CharacterData) -> String:
	if is_character_unlocked(data):
		return ""
	return "UNLOCK LEVEL %d" % data.required_level()


# --- BẢNG THƯỞNG / PHẠT ---------------------------------------------------

## Pickup gọi hàm này khi người chơi chạm vào.
func apply_pickup(kind: StringName, amount: int, by: Node) -> void:
	match kind:
		&"shard":
			collect_shard(maxi(amount, 1))
		&"shield":
			if shield_player(by, SHIELD_DURATION):
				AudioManager.play_sfx(&"shield")
		_:
			push_warning("GameManager: không biết loại đồ '%s'." % kind)


## Nhặt mảnh Rift: +SHARD_SCORE điểm, đếm vào màn hiện tại. Đủ SHARDS_REQUIRED
## -> phát shards_changed để ExitGate mở cánh.
func collect_shard(amount: int = 1) -> void:
	var n: int = maxi(amount, 0)
	if n == 0:
		return
	add_score(SHARD_SCORE * n)
	add_shards(n)
	AudioManager.play_sfx(&"pickup")


func add_shards(amount: int = 1) -> void:
	shard_count = maxi(shard_count + maxi(amount, 0), 0)
	EventBus.shards_changed.emit(shard_count, SHARDS_REQUIRED)
	AudioManager.play_sfx(&"one_up") if shard_count == SHARDS_REQUIRED else null


## true khi đã thu đủ mảnh Rift của màn.
func shards_complete() -> bool:
	return shard_count >= SHARDS_REQUIRED


## Hạ quái (boss = true -> +2000).
func report_enemy_killed(is_boss: bool = false) -> void:
	add_score(BOSS_KILL_SCORE if is_boss else ENEMY_KILL_SCORE)


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
	# Xong ải hướng dẫn -> từ lần sau vào game bỏ qua Level0.
	if current_level == TUTORIAL_LEVEL:
		SaveManager.mark_tutorial_completed()
	# Đã VƯỢT màn này -> mở khoá nhân vật tương ứng.
	SaveManager.mark_level_completed(current_level)
	# Mở ải KẾ TIẾP (không phải ải vừa chơi - xem ghi chú go_to_level).
	SaveManager.unlock(current_level + 1)


# --- Điểm / mạng -----------------------------------------------------------

func add_score(n: int) -> void:
	score = maxi(score + n, 0)
	EventBus.score_changed.emit(score)


func lose_life() -> void:
	deaths_this_level += 1
	lives = maxi(lives - 1, 0)
	EventBus.lives_changed.emit(lives)
	if lives == 0:
		EventBus.game_over.emit()


func reset_run() -> void:
	score = 0
	lives = START_LIVES
	shard_count = 0
	last_checkpoint = Vector2.ZERO
	deaths_this_level = 0
	EventBus.score_changed.emit(score)
	EventBus.lives_changed.emit(lives)
	EventBus.shards_changed.emit(shard_count, SHARDS_REQUIRED)


# --- Chuyển màn ------------------------------------------------------------

func level_path(level: int) -> String:
	return LEVEL_PATH_FORMAT % level


func is_boss_level(level: int) -> bool:
	return level == BOSS_LEVEL


## Vào ải. KHÔNG unlock ở đây: ải tiếp theo chỉ mở khi _on_level_completed()
## (tức người chơi đã thắng), nếu không sẽ mở sẵn cả 6 ải ngay lần đầu.
## TUTORIAL_LEVEL (0) được phép vào: clamp từ 0 chứ không từ 1.
func go_to_level(level: int) -> void:
	current_level = clampi(level, TUTORIAL_LEVEL, LEVEL_COUNT)
	last_checkpoint = Vector2.ZERO
	deaths_this_level = 0
	var path: String = level_path(current_level)
	if not ResourceLoader.exists(path):
		push_error("GameManager: chưa có scene ải '%s' (cần tạo %s)." % [path, path])
		return
	shard_count = 0
	EventBus.shards_changed.emit(shard_count, SHARDS_REQUIRED)
	_change_scene(path)


func restart_level() -> void:
	last_checkpoint = Vector2.ZERO
	go_to_level(current_level)


func go_to_menu() -> void:
	_change_scene(main_menu_scene)


func _change_scene(path: String) -> void:
	SceneTransition.change_scene(path)
