extends Node2D
## KIỂM TRA 3 QUÁI MỚI: Mushroom, Bomb, Bee.
##
## Mỗi quái phải: load được, đủ 4 animation, có collider đúng kích thước,
## di chuyển được, trúng đòn phản ứng, chết thì rơi rift shard.

var failures: int = 0

const NEEDED: Array[String] = ["idle", "walk", "hit", "dead"]

## Moi scene enemy duoc dua vao map.
const ALL: Array[String] = [
	"res://scenes/enemies/Mushroom.tscn",
	"res://scenes/enemies/Bomb.tscn",
	"res://scenes/enemies/Bee.tscn",
	"res://scenes/enemies/ShooterEnemy.tscn",
	"res://scenes/enemies/RockGrunt.tscn",
	"res://scenes/enemies/PatrolRockGrunt.tscn",
	"res://scenes/enemies/ChargerEnemy.tscn",
	"res://scenes/enemies/SummonedPatrolEnemy.tscn",
	"res://scenes/enemies/FlyingBug.tscn",
	"res://scenes/enemies/Boss.tscn",
]

const GROUND: Array[String] = [
	"res://scenes/enemies/Mushroom.tscn",
	"res://scenes/enemies/Bomb.tscn",
]

const FLYING: Array[String] = ["res://scenes/enemies/Bee.tscn"]


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


func _floor(at: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = at
	body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	body.add_child(shape)
	add_child(body)
	return body


func _run() -> void:
	# Moi scene enemy phai tro dung ve AnimatedSprite2D. Enemy.gd co fallback
	# nen scene quen gan `sprite` van hien duoc anh, nhung flip_h / modulate /
	# play_anim deu bi bo qua — phai chan truoc khi dua vao map.
	for path in ALL:
		var node: Enemy = (load(path) as PackedScene).instantiate() as Enemy
		add_child(node)
		await _frames(3)
		var label: String = path.get_file().get_basename()
		_check(node.sprite != null, "%s must resolve its AnimatedSprite2D reference" % label)
		if node.sprite != null:
			_check(node.sprite.sprite_frames != null, "%s must have sprite_frames assigned" % label)
		_check(node.health != null and node.hurtbox != null and node.contact_hitbox != null,
			"%s must resolve health, hurtbox and hitbox references" % label)
		# Enemy tu danh chet chinh minh khi collision_layer dung sai: ContactHitbox
		# dat nham tren layer ma chinh Hurtbox cua no dang monitor. Enemy 1 HP se
		# chet ngay luc spawn, enemy nhieu HP se mang sat thuong ngay.
		var self_hits: Array[int] = [0]
		node.health.damaged.connect(func(_a: int, _f: Vector2) -> void: self_hits[0] += 1)
		await _frames(36)
		_check(node.health.is_alive(), "%s must survive its own spawn" % label)
		_check(self_hits[0] == 0, "%s must not damage itself on spawn" % label)
		node.queue_free()
		await _frames(2)

	_floor(Vector2(0, 140), Vector2(600, 20))
	for path in GROUND:
		await _test_ground(path)
	await _test_flying(FLYING[0])
	print("EnemyLibrary checks complete: %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)


func _test_ground(path: String) -> void:
	var label: String = path.get_file().get_basename()
	var enemy: Enemy = (load(path) as PackedScene).instantiate() as Enemy
	enemy.position = Vector2(0, 128)
	add_child(enemy)
	await _frames(6)

	# --- Sprite ---
	var frames: SpriteFrames = enemy.sprite.sprite_frames
	_check(frames != null, "%s must have sprite_frames assigned" % label)
	for anim in NEEDED:
		_check(frames != null and frames.has_animation(StringName(anim))
			and frames.get_frame_count(StringName(anim)) > 0,
			"%s must provide animation \"%s\"" % [label, anim])
	_check(not frames.get_animation_loop(&"dead"), "%s dead animation must not loop" % label)

	# --- Collider khong bi de rong ---
	var body_shape: Shape2D = (enemy.get_node("CollisionShape2D") as CollisionShape2D).shape
	_check(body_shape is CapsuleShape2D and (body_shape as CapsuleShape2D).height > 16.0,
		"%s body collider must be a capsule wider than the 16px base" % label)

	# --- Di chuyen tren san ---
	enemy.state_machine.change_state(&"Patrol")
	var start_x: float = enemy.position.x
	await _frames(45)
	_check(absf(enemy.position.x - start_x) > 4.0, "%s must actually move while patrolling" % label)
	_check(enemy.sprite.animation == &"walk", "%s must play walk while patrolling" % label)

	# --- Dung san truoc khi cho state machine hoi ---
	var ledge := _floor(Vector2(-70, 60), Vector2(140, 16))
	await _frames(90)
	_check(enemy.global_position.x < 40.0, "%s must not walk off the ledge" % label)
	ledge.queue_free()

	# --- Trung don. Enemy 1 HP chet ngay nen khong co state Hurt; enemy nhieu HP
	# moi vao Hurt va phat animation "hit".
	# Moc so/phai chup TRUOC don dau: enemy 1 HP se chet ngay tai day, nen chup
	# sau se so sanh mot so da cong san.
	var shards_before: int = get_tree().get_nodes_in_group(&"pickup").size()
	var score_before: int = GameManager.score
	var hp_before: int = enemy.health.current
	enemy.take_damage(1, enemy.global_position + Vector2(30, 0))
	_check(enemy.health.current == hp_before - 1, "%s must lose 1 HP per hit" % label)
	if hp_before > 1:
		_check(enemy.current_state() == &"Hurt", "%s must enter Hurt when damaged" % label)
		_check(enemy.sprite.animation == &"hit", "%s must play hit animation when damaged" % label)
		enemy.health.reset()
		await _frames(3)
	elif enemy.dead:
		_check(enemy.sprite.animation == &"dead", "%s must play dead animation" % label)

	# --- Chet va roi manh ---
	while enemy.health.current > 0:
		enemy.take_damage(5, enemy.global_position + Vector2(30, 0))
		await _frames(2)
	await _frames(2)
	_check(enemy.dead, "%s must die at 0 HP" % label)
	_check(not enemy.contact_hitbox.is_active(), "%s death must disable its hitbox" % label)
	_check(GameManager.score > score_before, "%s death must award score" % label)
	await _frames(10)
	_check(get_tree().get_nodes_in_group(&"pickup").size() > shards_before,
		"%s death must drop a rift shard" % label)

	await _frames(80)
	# Enemy da chet nen tick_dead() co the da tu queue_free() sau death_delay.
	if is_instance_valid(enemy):
		enemy.queue_free()
	await _frames(2)


func _test_flying(path: String) -> void:
	var label: String = path.get_file().get_basename()
	var enemy: Enemy = (load(path) as PackedScene).instantiate() as Enemy
	enemy.position = Vector2(0, 60)
	add_child(enemy)
	await _frames(6)

	var frames: SpriteFrames = enemy.sprite.sprite_frames
	_check(frames != null, "%s must have sprite_frames assigned" % label)
	for anim in NEEDED:
		_check(frames != null and frames.has_animation(StringName(anim))
			and frames.get_frame_count(StringName(anim)) > 0,
			"%s must provide animation \"%s\"" % [label, anim])

	var body := enemy as CharacterBody2D
	_check(not body.has_gravity, "%s must not be pulled down by gravity" % label)
	_check(enemy.get_node_or_null("DetectArea") != null, "%s must have a DetectArea" % label)

	# Bay ngang + dao chieu doc, khong dung y tren.
	var start_y: float = enemy.global_position.y
	var highest: float = start_y
	var lowest: float = start_y
	enemy.state_machine.change_state(&"Patrol")
	await _frames(90)
	for i in 30:
		await get_tree().physics_frame
		highest = minf(highest, enemy.global_position.y)
		lowest = maxf(lowest, enemy.global_position.y)
	_check(lowest - highest > 4.0, "%s must drift vertically while patrolling" % label)
	_check(enemy.global_position.y < 140.0, "%s must never sink to the floor" % label)

	# Chet cung phai rơi manh.
	enemy.take_damage(9, enemy.global_position + Vector2(30, 0))
	await _frames(10)
	_check(enemy.dead, "%s must die when damaged" % label)
	if is_instance_valid(enemy):
		enemy.queue_free()
	await _frames(2)