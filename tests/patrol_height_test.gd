extends Node2D

const ENEMIES: Array[String] = [
	"res://scenes/enemies/Mushroom.tscn",
	"res://scenes/enemies/Bomb.tscn",
	"res://scenes/enemies/PatrolRockGrunt.tscn",
	"res://scenes/enemies/SummonedPatrolEnemy.tscn",
]
var failures: int = 0

func _ready() -> void:
	call_deferred(&"_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
	await get_tree().process_frame

func _floor(at: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = at
	body.collision_layer = 1
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	collision.shape = rectangle
	body.add_child(collision)
	add_child(body)

func _run() -> void:
	_floor(Vector2(80, 210), Vector2(160, 20))
	_floor(Vector2(230, 226), Vector2(140, 20))
	_floor(Vector2(20, 194), Vector2(40, 52))
	var player := preload("res://scenes/player/Player.tscn").instantiate() as Player
	player.position = Vector2(230, 200)
	add_child(player)
	player.set_physics_process(false)
	player.state_machine.set_physics_process(false)
	player.health.invincible = true
	player.velocity = Vector2.ZERO
	for path in ENEMIES:
		var enemy := (load(path) as PackedScene).instantiate() as PatrolEnemy
		enemy.position = Vector2(80, 180)
		enemy.detect_radius = 600
		add_child(enemy)
		await _frames(20)
		var height: float = enemy.global_position.y
		var min_x: float = enemy.global_position.x
		var max_x: float = min_x
		var stayed_on_floor: bool = true
		var stayed_patrol: bool = true
		for i in 180:
			player.position = Vector2(230, 100 if i < 90 else 250)
			await _frames(1)
			min_x = minf(min_x, enemy.global_position.x)
			max_x = maxf(max_x, enemy.global_position.x)
			stayed_on_floor = stayed_on_floor and absf(enemy.global_position.y - height) < 0.5
			stayed_patrol = stayed_patrol and enemy.current_state() == &"Patrol"
		_check(max_x - min_x > 20, path + " must continue patrolling")
		_check(min_x >= 40 and max_x < 160, path + " must turn before higher and lower terrain")
		_check(stayed_on_floor, path + " must stay at its initial floor height")
		_check(stayed_patrol, path + " must not chase a player on another row")
		enemy.queue_free()
		await _frames(2)
	print("Patrol height checks complete: %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)
