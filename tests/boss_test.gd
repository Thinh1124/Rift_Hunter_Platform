extends Node2D

var failures: int = 0
var hp_events: Array[Vector2i] = []
var defeated_events: int = 0
var shakes: Array[Vector2] = []
var target: Player
var boss: Boss


func _ready() -> void:
	call_deferred(&"_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _seconds(duration: float) -> void:
	var elapsed := 0.0
	while elapsed < duration:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
	await get_tree().process_frame


func _platform(at: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = at
	body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	body.add_child(shape)
	add_child(body)


func _new_boss() -> Boss:
	var instance := preload("res://scenes/enemies/Boss.tscn").instantiate() as Boss
	instance.position = Vector2(0, 128)
	instance.arena_left = -320
	instance.arena_right = 320
	add_child(instance)
	return instance


func _run() -> void:
	EventBus.boss_hp_changed.connect(func(cur: int, maximum: int) -> void: hp_events.append(Vector2i(cur, maximum)))
	EventBus.boss_defeated.connect(func() -> void: defeated_events += 1)
	EventBus.request_shake.connect(func(strength: float, duration: float) -> void: shakes.append(Vector2(strength, duration)))
	_platform(Vector2(0, 210), Vector2(640, 20))
	_platform(Vector2(-330, 100), Vector2(20, 200))
	_platform(Vector2(330, 100), Vector2(20, 200))
	target = preload("res://scenes/player/Player.tscn").instantiate() as Player
	target.position = Vector2(180, 200)
	add_child(target)
	target.set_physics_process(false)
	target.state_machine.set_physics_process(false)
	target.health.invincible = true
	boss = _new_boss()
	await _seconds(0.1)
	_check(boss.is_in_group(&"boss") and boss.health.current == 20, "Boss must initialize group and 20 HP")
	_check(hp_events.back() == Vector2i(20, 20), "Boss must publish initial HP")
	_check(boss.current_state() == &"Rest", "Boss must begin in Rest")
	boss.take_damage(9)
	_check(boss.phase == 1, "11 HP must remain phase 1")
	await _seconds(0.5)
	boss.take_damage(1)
	_check(boss.phase == 2, "10 HP must enter phase 2")
	_check(not boss.summon_timer.is_stopped() and is_equal_approx(boss.summon_timer.wait_time, 8.0), "Phase 2 must start 8-second summon timer")
	_check(hp_events.back() == Vector2i(10, 20), "Damage must publish HP")
	_check(shakes.has(Vector2(2, 0.2)), "Phase transition must shake")
	boss._attack = &"Dash"
	boss.state_machine.change_state(&"Telegraph")
	await _seconds(0.2)
	_check(boss.current_state() == &"Telegraph" and not boss.contact_hitbox.active, "No damaging attack before telegraph completes")
	await _seconds(0.23)
	_check(boss.current_state() == &"Dash", "Telegraph must begin selected attack")
	_check(is_equal_approx(absf(boss.velocity.x), 338.0), "Phase 2 dash speed must be 260 x 1.3")
	await _seconds(1.0)
	_check(boss.current_state() == &"Stunned", "Dash at wall must stun")
	_check(not boss.contact_hitbox.active, "Stunned Boss must be safe to touch")
	_check(boss.global_position.x <= 256.1, "Boss must stay in arena")
	await _seconds(0.5)
	_check(boss.current_state() == &"Stunned", "Wall stun must last 1 second")
	await _seconds(0.6)
	_check(boss.current_state() == &"Rest", "Boss must recover from wall stun")
	boss.state_machine.set_physics_process(false)
	var shots_before := boss._projectiles.size()
	boss._fire_fan()
	_check(boss._projectiles.size() == shots_before + 3, "Shoot must create 3 projectiles")
	var first := boss._projectiles[shots_before]
	var middle := boss._projectiles[shots_before + 1]
	var last := boss._projectiles[shots_before + 2]
	_check(is_equal_approx(rad_to_deg(first.travel_direction.angle_to(middle.travel_direction)), 20), "Fan must use -20/0/+20 degrees")
	_check(is_equal_approx(rad_to_deg(middle.travel_direction.angle_to(last.travel_direction)), 20), "Fan must use equal 20-degree spread")
	_check(middle.collision_layer == 16 and is_equal_approx(middle.speed, 234), "Hostile projectile must be layer 5 and scale speed")
	boss.global_position = Vector2(0, 128)
	boss._emit_slam_waves()
	var waves := boss._projectiles.slice(boss._projectiles.size() - 2)
	_check(waves[0].ground_wave and waves[1].ground_wave and waves[0].travel_direction.x == -1 and waves[1].travel_direction.x == 1, "Slam must launch two opposing ground waves")
	await _seconds(0.15)
	_check(is_instance_valid(waves[0]) and absf(waves[0].global_position.y - 192) < 1, "Wave must travel along floor")
	# Real incoming player projectile must reach the boss hurtbox.
	boss.health.invincible = false
	var incoming := preload("res://scenes/objects/Projectile.tscn").instantiate() as Projectile
	incoming.position = Vector2(-100, 128)
	add_child(incoming)
	await _seconds(0.25)
	_check(boss.health.current == 9, "Boss must receive player projectile damage")
	boss.health.invincible = false
	boss.state_machine.change_state(&"Slam")
	target.velocity.y = 120
	boss._on_stomp_zone_area_entered(target.hurtbox)
	_check(boss.health.current == 9, "Boss must reject stomps during Slam")
	boss.state_machine.change_state(&"Rest")
	boss._on_stomp_zone_area_entered(target.hurtbox)
	_check(boss.health.current == 8 and target.velocity.y == target.stomp_bounce, "Stomp must deal exactly one hit and bounce")
	boss.state_machine.set_physics_process(true)
	boss._attack = &"Slam"
	boss.state_machine.change_state(&"Telegraph")
	await _seconds(0.2)
	_check(boss.current_state() == &"Telegraph", "Slam also requires telegraph")
	await _seconds(0.4)
	_check(boss.current_state() == &"Slam" and not boss.is_on_floor(), "Slam must jump after telegraph")
	await _seconds(1.0)
	_check(boss.current_state() == &"Rest", "Slam must land and recover")
	# Test real timer cadence independently of the attack loop.
	boss.state_machine.set_physics_process(false)
	boss.summon_timer.start(8.0)
	await _seconds(7.8)
	_check(not boss.summon_gate.visible, "Summon gate must wait 8 seconds")
	await _seconds(0.3)
	_check(boss.summon_gate.visible and boss._minions.is_empty(), "Gate opens before spawning")
	boss._tick_gate(0.5)
	_check(boss._minions.size() == 2 and boss._minions[0] is PatrolEnemy, "Gate must summon 2 PatrolEnemy")
	boss._tick_gate(0.4)
	_check(not boss.summon_gate.visible, "Gate must close after summoning")
	await _seconds(0.6)
	_check(boss._minions[0].health.is_alive(), "Summoned patrol must not damage itself")
	var score_before := GameManager.score
	boss.health.invincible = false
	boss.take_damage(99)
	_check(boss.dead and boss.summon_timer.is_stopped(), "Death must stop attacks and summoning")
	_check(GameManager.score == score_before + 2000 and defeated_events == 1, "Death must award 2000 and emit defeated once")
	_check(shakes.has(Vector2(6, 0.8)), "Death must request strong shake")
	boss._on_died()
	_check(GameManager.score == score_before + 2000 and defeated_events == 1, "Death handling must be idempotent")
	boss.state_machine.set_physics_process(true)
	await _seconds(1.0)
	_check(is_instance_valid(boss), "Boss death delay must be 1.5 seconds")
	await _seconds(0.6)
	_check(not is_instance_valid(boss), "Boss must free after death delay")
	await _test_shooter()
	await _test_pacing()
	print("Boss/Shooter checks complete: %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)


func _test_shooter() -> void:
	target.position = Vector2(100, 200)
	target.velocity = Vector2.ZERO
	target.health.invincible = true
	var shooter := preload("res://scenes/enemies/ShooterEnemy.tscn").instantiate() as ShooterEnemy
	shooter.position = Vector2(0, 192)
	add_child(shooter)
	await _seconds(2.1)
	_check(shooter._telegraph_left > 0.0 and absf(shooter.position.x) < 0.1, "Shooter must stand still and telegraph")
	await _seconds(0.3)
	var bullet_count := 0
	for child in get_children():
		if child is EnemyProjectile and child.source == shooter:
			bullet_count += 1
	_check(bullet_count == 1, "Shooter must fire exactly one bullet")
	target.position.x = -100
	await _seconds(2.5)
	_check(shooter._telegraph_left < 0.0 and shooter.position.x == 0, "Shooter must not attack behind itself or move")
	shooter.queue_free()
	await _seconds(0.1)


func _test_pacing() -> void:
	# Seeded encounter: player lands one hit per attack/recovery cycle.
	Engine.time_scale = 6.0
	target.position = Vector2(220, 200)
	target.health.invincible = true
	target.velocity = Vector2.ZERO
	var encounter := _new_boss()
	encounter._rng.seed = 42
	var elapsed := 0.0
	var hit_this_rest := false
	while is_instance_valid(encounter) and not encounter.dead and elapsed < 100.0:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		if encounter.current_state() == &"Rest":
			if not hit_this_rest:
				encounter.take_damage(1)
				hit_this_rest = true
		else:
			hit_this_rest = false
		_check(encounter.position.x >= -256.1 and encounter.position.x <= 256.1, "Encounter must stay inside arena")
	_check(encounter.dead and elapsed >= 60.0 and elapsed <= 90.0, "One-hit-per-cycle encounter should last 60-90 simulated seconds (actual %.1f)" % elapsed)
	print("Seeded encounter duration (one hit per cycle): %.1f simulated seconds" % elapsed)
	Engine.time_scale = 1.0
