extends Node2D

var failures: int = 0
var hit_count: int = 0


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
	var spikes := preload("res://scenes/objects/Spikes.tscn").instantiate() as Spikes
	spikes.tile_count = 3
	add_child(spikes)
	var sprite := spikes.get_node("Sprite2D") as Sprite2D
	var collision := spikes.get_node("CollisionShape2D") as CollisionShape2D
	var rectangle := collision.shape as RectangleShape2D
	_check(spikes.collision_layer == 128 and spikes.collision_mask == 2 and spikes.damage == 1, "Spikes must use layer 8, mask 2, damage 1")
	_check(sprite.region_rect.size == Vector2(48, 16) and sprite.texture_repeat == CanvasItem.TEXTURE_REPEAT_ENABLED, "Three tiles must repeat horizontally across 48 px")
	_check(rectangle.size.x == 48, "Three tiles must have 48 px collision width")
	var separate := preload("res://scenes/objects/Spikes.tscn").instantiate() as Spikes
	separate.position = Vector2(300, 0)
	add_child(separate)
	_check((separate.get_node("CollisionShape2D").shape as RectangleShape2D).size.x == 16, "Resizing spikes must not change another instance")
	for degrees in [0, 90, 180, 270]:
		spikes.rotation_dir = degrees
		_check(is_equal_approx(spikes.rotation_degrees, float(degrees)), "Rotation export must rotate sprite and collision")
	spikes.rotation_dir = 0
	spikes.tile_count = 2
	_check(rectangle.size.x == 32 and sprite.region_rect.size.x == 32, "Changing tile_count must update collision and sprite together")
	spikes.tile_count = 3
	var player := preload("res://scenes/player/Player.tscn").instantiate() as Player
	player.position = Vector2(-100, 0)
	add_child(player)
	player.set_physics_process(false)
	player.state_machine.set_physics_process(false)
	player.hurtbox.hit_received.connect(func(_hitbox: HitboxComponent) -> void: hit_count += 1)
	var hp := player.health.current
	var lives := GameManager.lives
	# The last tile must collide; a point beyond the 3-tile rectangle must not.
	player.position = Vector2(36, collision.position.y + 9)
	await _frames(4)
	_check(player.health.current == hp, "Spikes must not damage beyond the extended collision")
	player.position.x = 20
	await _frames(4)
	_check(player.health.current == hp - 1 and player.health.is_alive(), "Contact on third tile must deal one damage without instant kill")
	_check(player.velocity == Vector2(0, -200), "Spikes must apply vertical -200 knockback")
	_check(GameManager.lives == lives and player.current_state() == Player.STATE_HIT, "Nonlethal spike contact must not cost a life")
	await _frames(30)
	_check(player.health.current == hp - 1 and hit_count == 1, "Persistent overlap must not damage during i-frames")
	# Keep the frozen body in the hazard and allow its i-frames to expire.
	await _frames(55)
	_check(player.health.current == hp - 2 and hit_count == 2, "Persistent contact must damage again after i-frames expire")
	spikes.set_active(false)
	await _frames(85)
	_check(player.health.current == hp - 2, "Inactive spikes must not damage")
	spikes.set_active(true)
	player.position = Vector2(100, 0)
	player.add_shield(8)
	await _frames(3)
	player.position = Vector2(0, collision.position.y + 9)
	await _frames(4)
	_check(player.health.current == hp - 2, "Shield must block spike contact")
	player.position = Vector2(100, 0)
	player.set_shield(false)
	await _frames(3)
	# Existing hitboxes retain Player's default knockback unless opted in.
	var ordinary := HitboxComponent.new()
	ordinary.position = Vector2(0, 0)
	ordinary.knockback = Vector2(500, -500)
	add_child(ordinary)
	player.health.reset()
	player.iframe_timer.stop()
	player.health.invincible = false
	player.state_machine.change_state(Player.STATE_IDLE)
	player.hurtbox._on_area_entered(ordinary)
	_check(player.velocity == Vector2(player.hit_knockback.x, player.hit_knockback.y), "Existing hitboxes must retain default knockback")
	print("Spikes checks complete: %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)
