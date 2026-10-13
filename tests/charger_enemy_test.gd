extends Node2D
## Run this scene headless to verify the charge cycle against real physics.

var failures: int = 0


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _body(at: Vector2, size: Vector2) -> StaticBody2D:
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


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
	await get_tree().process_frame


func _run() -> void:
	_body(Vector2(0, 110), Vector2(400, 20)) # Floor ends at x=200.
	var target := preload("res://scenes/player/Player.tscn").instantiate() as Player
	target.position = Vector2(130, 100)
	add_child(target)
	target.set_physics_process(false)
	target.state_machine.set_physics_process(false)
	var charger := preload("res://scenes/enemies/ChargerEnemy.tscn").instantiate() as ChargerEnemy
	charger.position = Vector2(0, 92)
	add_child(charger)
	await _frames(4)
	_check(charger.health.current == 2, "Charger must start with 2 HP")
	_check(charger.current_state() == &"Windup", "SightRay must detect player")
	var obstruction := _body(Vector2(70, 75), Vector2(10, 50))
	await _frames(1)
	_check(not charger.can_see_player(), "SightRay must not see through walls")
	obstruction.queue_free()
	var start_x := charger.position.x
	await _frames(12)
	_check(charger.current_state() == &"Windup", "Must telegraph before dash")
	_check(absf(charger.position.x - start_x) < 0.1, "Windup must stand still")
	_check(charger.sprite.modulate.g < 0.5, "Windup must flash red")
	await _frames(20)
	_check(charger.current_state() == &"Dash", "Windup must become Dash")
	var locked_direction := charger.direction
	target.position.x = -130
	await _frames(2)
	_check(charger.direction == locked_direction, "Dash direction must stay locked")
	var wall := _body(Vector2(charger.position.x + 25, 75), Vector2(10, 50))
	await _frames(10)
	_check(charger.current_state() == &"Stunned", "Wall impact must stun")
	_check(not charger.contact_hitbox.is_active(), "Stunned contact hitbox must be inactive")
	# Dọn tường + đưa Player ra xa TRƯỚC khi chờ stun hết. Nếu giữ tường, sau khi
	# hết stun charger về Patrol -> thấy player -> lao vào tường -> stun LẠI,
	# nên kiểm tra "về Patrol" sẽ đỏ dù AI chạy đúng.
	wall.queue_free()
	target.position.x = -500
	await _frames(50)
	_check(charger.current_state() == &"Stunned", "Stun must last 1.5 seconds")
	await _frames(45)
	_check(charger.current_state() == &"Patrol", "Stun must return to Patrol")
	charger.position = Vector2(165, 92)
	charger.direction = 1
	charger.state_machine.change_state(&"Dash")
	await _frames(20)
	_check(charger.current_state() == &"Cooldown", "Dash must stop at ledge")
	_check(charger.position.x < 194 and charger.position.y < 93, "Dash must not fall off floor")
	await _frames(65)
	_check(charger.current_state() == &"Patrol", "Cooldown must return to Patrol")
	charger.position = Vector2(0, 92)
	target.position = Vector2(35, 100)
	target.health.invincible = false
	var hp := target.health.current
	charger.direction = 1
	charger.state_machine.change_state(&"Dash")
	await _frames(12)
	_check(target.health.current == hp - charger.contact_damage, "Dash must damage player once")
	_check(charger.current_state() == &"Cooldown", "Player contact must end Dash")
	charger.state_machine.change_state(&"Stunned")
	target.health.invincible = false
	hp = target.health.current
	target.hurtbox._on_area_entered(charger.contact_hitbox)
	_check(target.health.current == hp, "Stunned charger must not damage player")
	charger.take_damage(1, target.global_position)
	_check(charger.health.current == 1, "Charger must still receive damage while stunned")
	await _frames(20)
	_check(charger.current_state() == &"Patrol", "Damage recovery must return to Patrol")
	charger.take_damage(1, target.global_position)
	_check(charger.dead and not charger.contact_hitbox.is_active(), "Lethal damage must disable contact")
	print("ChargerEnemy checks complete: %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)
