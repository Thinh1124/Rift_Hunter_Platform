extends Node2D
## Nghiệm thu cơ chế MẢNH RIFT (thay Trái cây cũ):
##   1. Nhặt RiftShard -> +SHARD_SCORE điểm, shard_count tăng, phát shards_changed
##   2. Thân không thuộc group "player" không được nhặt
##   3. Nhặt xong node tự hủy, tín hiệu phát đúng 1 lần
##   4. Khiên không cộng điểm, không cộng mảnh
##   5. Quái chết rơi mảnh; đủ SHARDS_REQUIRED thì ExitGate mở cánh

const SHARD_SCENE: String = "res://scenes/objects/RiftShard.tscn"
const PLAYER_SCENE: String = "res://scenes/player/Player.tscn"
const ENEMY_SCENE: String = "res://scenes/enemies/RockGrunt.tscn"
const GATE_SCENE: String = "res://scenes/objects/ExitGate.tscn"

var failures: int = 0
var shard_events: Array[Vector2i] = []
var collected_events: int = 0


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


func _spawn(scene: PackedScene, at: Vector2) -> Node:
	var pickup := scene.instantiate() as Node
	(pickup as Pickup).position = at
	(pickup as Pickup).bob_height = 0.0
	add_child(pickup)
	return pickup


## Số RiftShard đang nằm trên sân (chưa ai nhặt).
func _shards_on_ground() -> int:
	var n: int = 0
	for node in get_tree().get_nodes_in_group(&"pickup"):
		if node is RiftShard:
			n += 1
	return n


func _run() -> void:
	EventBus.shards_changed.connect(func(c: int, r: int) -> void: shard_events.append(Vector2i(c, r)))
	GameManager.score = 0
	GameManager.shard_count = GameManager.SHARDS_REQUIRED - 1
	GameManager.reset_run()
	# reset_run() ghi shard_count = 0, nên đặt SAU khi reset.
	GameManager.shard_count = GameManager.SHARDS_REQUIRED - 1
	await _frames(2)

	var player: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.position = Vector2(120, 0)
	add_child(player)
	await _frames(4)

	print("=== PICKUP / MANH RIFT ===")
	print("SHARDS_REQUIRED = ", GameManager.SHARDS_REQUIRED)

	# --- 1. RiftShard: thuộc tính, rồi mới cho chạm để nhặt ---
	# Spawn xa Player trước: Area2D nhặt ngay khi chạm, không tách bước này thì
	# node đã bị queue_free trước khi kịp kiểm tra thuộc tính.
	var shard: Pickup = _spawn(load(SHARD_SCENE), Vector2(300, -8)) as Pickup
	shard.value = 275
	shard.collected.connect(func(_k: StringName, _a: int, _b: Node) -> void: collected_events += 1)
	await _frames(3)
	_check(shard.collision_layer == 32 and shard.collision_mask == 2, "RiftShard phải dùng layer 6, mask 2")
	_check((shard.get_node("CollisionShape2D").shape as CircleShape2D).radius == 7, "vòng nhặt rift shard phải bán kính 7")
	_check(shard.sprite.sprite_frames != null and shard.sprite.is_playing(), "RiftShard phải có animation 'spin' đang chạy")
	_check(is_instance_valid(shard) and GameManager.shard_count == GameManager.SHARDS_REQUIRED - 1,
		"chưa chạm thì chưa được nhặt")
	# Đưa tới Player -> nhặt.
	shard.global_position = player.global_position + Vector2(0, -8)
	await _frames(4)
	print("  sau khi chạm: shard_count = ", GameManager.shard_count, " | score = ", GameManager.score)
	_check(GameManager.shard_count == GameManager.SHARDS_REQUIRED, "nhặt mảnh -> shard_count tăng")
	_check(GameManager.shards_complete(), "đủ số mảnh -> shards_complete() true")
	_check(not is_instance_valid(shard), "mảnh đã nhặt phải tự hủy")
	_check(collected_events == 1, "tín hiệu collected phát đúng 1 lần")

	# --- 2. Khiên không cộng điểm, không cộng mảnh ---
	var score_before: int = GameManager.score
	var shards_before: int = GameManager.shard_count
	_spawn(load("res://scenes/objects/Shield.tscn"), Vector2(150, -8))
	await _frames(4)
	_check(GameManager.score == score_before, "Khiên không được cộng điểm")
	_check(GameManager.shard_count == shards_before, "Khiên không được cộng mảnh rift")

	# --- 3. Thân ngoài group player không nhặt được ---
	GameManager.score = 0
	var before_score: int = GameManager.score
	var stray: Pickup = _spawn(load(SHARD_SCENE), Vector2(400, -8)) as Pickup
	var body := StaticBody2D.new()
	body.collision_layer = 2
	body.position = Vector2(400, -8)
	add_child(body)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 16)
	shape.shape = rect
	body.add_child(shape)
	await _frames(4)
	_check(is_instance_valid(stray) and GameManager.score == before_score,
		"chỉ thân thuộc group 'player' mới nhặt được mảnh")
	# Dọn mảnh chưa nhặt, nếu không nó đứng trên sân và làm sai đếm ở bước sau.
	stray.queue_free()
	await _frames(2)

	# --- 4. Quái chết rơi mảnh ---
	GameManager.shard_count = 0
	var ground_before: int = _shards_on_ground()
	var enemy: Node2D = (load(ENEMY_SCENE) as PackedScene).instantiate() as Node2D
	enemy.position = Vector2(700, 0)
	add_child(enemy)
	await _frames(4)
	enemy.get(&"health").call(&"take_damage", 99, Vector2.ZERO)
	await _frames(6)
	var dropped: int = _shards_on_ground() - ground_before
	print("  quái chết -> số mảnh rơi xuống đất = ", dropped)
	_check(dropped == 1, "quái chết phải rơi 1 mảnh rift")

	# --- 5. Đủ mảnh -> cổng mở cánh ---
	var gate: Node = (load(GATE_SCENE) as PackedScene).instantiate() as Node
	gate.position = Vector2(900, 0)
	add_child(gate)
	await _frames(4)
	_check(int(gate.get(&"state")) == 0, "cổng phải KHOÁ khi chưa đủ mảnh")
	GameManager.shard_count = GameManager.SHARDS_REQUIRED
	EventBus.shards_changed.emit(GameManager.shard_count, GameManager.SHARDS_REQUIRED)
	await _frames(4)
	print("  đủ mảnh -> trạng thái cổng = ", gate.get(&"state"), " (1 = OPENING)")
	_check(int(gate.get(&"state")) != 0, "đủ mảnh rift -> cổng phải mở cánh")

	print("Pickup checks complete: %d failures" % failures)
	get_tree().quit()