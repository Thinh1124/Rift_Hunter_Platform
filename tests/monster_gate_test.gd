extends Node2D

var failures: int = 0
var _gate_closed_bus: int = 0
var _gate_closed_signal: int = 0
var _last_bus_args: Array = []


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


func _run() -> void:
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(100, 240)
	var floor_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(600, 20)
	floor_shape.shape = rectangle
	floor_body.add_child(floor_shape)
	add_child(floor_body)

	EventBus.gate_closed.connect(func(id: StringName) -> void:
		_gate_closed_bus += 1
		_last_bus_args = [id])

	var gate := preload("res://scenes/enemies/MonsterGate.tscn").instantiate() as MonsterGate
	gate.position = Vector2(200, 220)
	gate.gate_id = &"gate_a"
	gate.spawn_scene = preload("res://scenes/enemies/SummonedPatrolEnemy.tscn")
	gate.spawn_interval = 0.2
	gate.max_alive = 2
	gate.close_time = 0.3
	add_child(gate)
	gate.closed.connect(func(_id: StringName) -> void: _gate_closed_signal += 1)
	await _frames(3)
	_check(gate.is_in_group(&"gate"), "MonsterGate must join group \"gate\"")
	_check(not gate.is_boss_gate, "Normal gate must not be a boss gate")
	_check(gate.interact_zone.collision_layer == 64 and gate.interact_zone.collision_mask == 2, "InteractZone must use layer 7 and mask 2")
	_check(gate.state == MonsterGate.GateState.OPEN, "start_active gate must begin open")
	_check(gate.sprite.sprite_frames.has_animation(MonsterGate.ANIM_OPEN) and gate.sprite.sprite_frames.has_animation(MonsterGate.ANIM_CLOSING) and gate.sprite.sprite_frames.has_animation(MonsterGate.ANIM_CLOSED), "Gate must provide open_idle, closing and closed animations")
	_check(gate.open_glow.emitting and not gate.smoke.emitting, "Open gate must glow and not smoke")

	# Cổng thường được GameManager tính vào tổng.
	GameManager.register_gates()
	_check(GameManager.total_gates == 1 and GameManager.remaining_gates == 1, "Normal gate must count toward the gate total")

	GameManager.lives = 3
	GameManager.last_checkpoint = Vector2(100, 230)
	var player := preload("res://scenes/player/Player.tscn").instantiate() as Player
	player.position = Vector2(60, 230)
	add_child(player)
	player.camera.enabled = false
	var camera := Camera2D.new()
	camera.position = Vector2(200, 320)
	add_child(camera)
	camera.make_current()
	await _frames(4)
	_check(gate.alive_count() == 0, "No enemy may spawn before the first interval elapses")

	# Spawn theo interval, không vượt max_alive.
	await _frames(70)
	_check(gate.alive_count() == 2, "Gate must spawn up to max_alive enemies")
	var spawned := get_tree().get_nodes_in_group(&"enemy").size()
	_check(spawned >= 2, "Spawned enemies must join group \"enemy\"")
	_check(gate.spawn_timer.wait_time == 0.2, "SpawnTimer must follow spawn_interval")
	await _frames(60)
	_check(gate.alive_count() == 2, "Gate must never spawn beyond max_alive")

	# Player đứng trong vùng nhưng không giữ interact -> vẫn Open.
	player.position = gate.position + Vector2(0, -24)
	player.velocity = Vector2.ZERO
	await _frames(10)
	_check(gate.hint_icon.visible, "Interact hint must show while the player stands in the zone")
	_check(gate.state == MonsterGate.GateState.OPEN, "Standing in the zone alone must not close the gate")

	# Giữ interact -> Closing, thả nút -> reset về Open.
	Input.action_press(&"interact")
	await _frames(6)
	_check(gate.state == MonsterGate.GateState.CLOSING, "Holding interact in the zone must start closing")
	_check(gate.close_bar.visible and gate.close_bar.value > 0.0, "CloseBar must fill while closing")
	_check(gate.sprite.animation == MonsterGate.ANIM_CLOSING, "Closing gate must play the closing animation")
	Input.action_release(&"interact")
	await _frames(6)
	_check(gate.state == MonsterGate.GateState.OPEN, "Releasing interact must reset back to Open")
	_check(gate.close_bar.value == 0.0 and not gate.close_bar.visible, "CloseBar must reset to zero")

	# Rời vùng khi đang giữ -> cũng phải reset.
	Input.action_press(&"interact")
	await _frames(4)
	_check(gate.state == MonsterGate.GateState.CLOSING, "Holding interact must start closing again")
	player.position = Vector2(60, 230)
	player.velocity = Vector2.ZERO
	await _frames(6)
	Input.action_release(&"interact")
	await _frames(4)
	_check(gate.state == MonsterGate.GateState.OPEN, "Leaving the zone while holding must reset to Open")

	# Giữ đủ close_time -> Closed.
	player.position = gate.position + Vector2(0, -24)
	player.velocity = Vector2.ZERO
	await _frames(6)
	Input.action_press(&"interact")
	await _frames(30)
	Input.action_release(&"interact")
	await _frames(4)
	_check(gate.state == MonsterGate.GateState.CLOSED, "Holding long enough must close the gate")
	_check(_gate_closed_signal == 1 and _gate_closed_bus == 1, "Closing must emit gate_closed exactly once")
	_check(_last_bus_args == [&"gate_a"], "gate_closed must carry gate_id")
	_check(gate.sprite.animation == MonsterGate.ANIM_CLOSED, "Closed gate must play the closed animation")
	_check(gate.smoke.emitting, "Closed gate must emit smoke")
	_check(not gate.open_glow.emitting, "Closed gate must stop the open glow")
	_check(not gate.interact_zone.monitoring, "Closed gate must disable its InteractZone")
	_check(gate.spawn_timer.is_stopped(), "Closed gate must stop spawning")

	# HUD giảm "Cổng x/y".
	_check(GameManager.remaining_gates == 0, "Closing one gate must reduce the remaining count")
	_check(GameManager.total_gates == 1, "Closing must not change the gate total")

	# Quái đã spawn không biến mất.
	_check(gate.alive_count() == 2, "Closing must not remove already spawned enemies")

	# Không spawn thêm sau khi đóng.
	var before := get_tree().get_nodes_in_group(&"enemy").size()
	await _frames(60)
	_check(get_tree().get_nodes_in_group(&"enemy").size() == before, "Closed gate must never spawn again")
	_check(gate.alive_count() == 2, "Closed gate must keep its existing enemies")

	# start_active = false -> Inactive (ẩn), activate() bật lên.
	var dormant := preload("res://scenes/enemies/MonsterGate.tscn").instantiate() as MonsterGate
	dormant.position = Vector2(400, 220)
	dormant.start_active = false
	dormant.spawn_interval = 0.2
	dormant.max_alive = 1
	add_child(dormant)
	await _frames(4)
	_check(dormant.state == MonsterGate.GateState.INACTIVE and not dormant.visible, "start_active=false gate must stay inactive and hidden")
	_check(dormant.spawn_timer.is_stopped(), "Inactive gate must not spawn")
	_check(GameManager.total_gates == 1, "register_gates must run before adding extra gates")
	dormant.activate()
	await _frames(3)
	_check(dormant.state == MonsterGate.GateState.OPEN and dormant.visible, "activate() must open the dormant gate")
	await _frames(30)
	_check(dormant.alive_count() == 1, "Activated gate must spawn enemies")
	dormant.activate()
	await _frames(2)
	_check(dormant.state == MonsterGate.GateState.OPEN, "activate() on a closed gate must be ignored")

	print("MonsterGate checks complete: %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)