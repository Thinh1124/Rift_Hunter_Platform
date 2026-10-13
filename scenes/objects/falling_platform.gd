class_name FallingPlatform
extends AnimatableBody2D

enum PlatformState { IDLE, SHAKING, FALLING, HIDDEN, RESPAWNING }

@export_range(0.0, 5.0, 0.05) var fall_delay: float = 0.5
@export_range(0.0, 4000.0, 10.0) var fall_gravity: float = 600.0
@export_range(0.0, 30.0, 0.1) var respawn_time: float = 3.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var trigger: Area2D = $Trigger
@onready var on_screen: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

var state: PlatformState = PlatformState.IDLE
var _spawn_transform: Transform2D
var _sprite_position: Vector2
var _sprite_tint: Color
var _delay_left: float = 0.0
var _hidden_left: float = 0.0
var _fall_speed: float = 0.0
var _fade: Tween


func _ready() -> void:
	_spawn_transform = global_transform
	_sprite_position = sprite.position
	_sprite_tint = sprite.modulate
	trigger.body_entered.connect(_on_trigger_body_entered)
	on_screen.screen_exited.connect(_on_screen_exited)


func _on_trigger_body_entered(body: Node2D) -> void:
	_try_start(body)


func _try_start(body: Node2D) -> void:
	if state != PlatformState.IDLE or not body.is_in_group(&"player"):
		return
	var rider := body as CharacterBody2D
	if rider == null or not rider.is_on_floor() or rider.velocity.y < 0.0:
		return
	for index in rider.get_slide_collision_count():
		var contact := rider.get_slide_collision(index)
		if contact.get_collider() == self and contact.get_normal().dot(Vector2.UP) > 0.5:
			state = PlatformState.SHAKING
			AudioManager.play_sfx(&"platform_shake")
			_delay_left = fall_delay
			return


func _physics_process(delta: float) -> void:
	match state:
		PlatformState.IDLE:
			# Entering the trigger from underneath is not standing on the platform.
			for body in trigger.get_overlapping_bodies():
				_try_start(body)
		PlatformState.SHAKING:
			_delay_left -= delta
			var elapsed := fall_delay - _delay_left
			sprite.position = _sprite_position + Vector2(sin(elapsed * TAU * 18.0) * 2.0, 0)
			if _delay_left <= 0.0:
				_start_falling()
		PlatformState.FALLING:
			_fall_speed += fall_gravity * delta
			global_position.y += _fall_speed * delta
			if _touches_kill_zone() or _outside_viewport():
				_deactivate()
		PlatformState.HIDDEN:
			_hidden_left -= delta
			if _hidden_left <= 0.0:
				_begin_respawn()


func _start_falling() -> void:
	AudioManager.play_sfx(&"platform_fall")
	state = PlatformState.FALLING
	_fall_speed = 0.0
	sprite.position = _sprite_position
	var debris := DustFX.spawn(get_parent(), global_position)
	if debris != null:
		debris.gravity = Vector2(0, 180)
		debris.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		debris.emission_rect_extents = Vector2(14, 2)


func _touches_kill_zone() -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision_shape.shape
	query.transform = collision_shape.global_transform
	query.collision_mask = 128
	query.collide_with_bodies = false
	query.collide_with_areas = true
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 64):
		# Layer 8 also contains damaging hazards; only KillZone hides this body.
		if hit.collider is KillZone:
			return true
	return false


func _outside_viewport() -> bool:
	# Also works with headless physics, where screen notifier signals do not fire.
	var screen_bounds := sprite.get_global_transform_with_canvas() * sprite.get_rect()
	return not get_viewport_rect().intersects(screen_bounds)


func _on_screen_exited() -> void:
	if state == PlatformState.FALLING:
		_deactivate()


func _deactivate() -> void:
	if state != PlatformState.FALLING:
		return
	state = PlatformState.HIDDEN
	_hidden_left = respawn_time
	_fall_speed = 0.0
	collision_shape.set_deferred(&"disabled", true)
	trigger.set_deferred(&"monitoring", false)
	hide()


func _begin_respawn() -> void:
	AudioManager.play_sfx(&"platform_respawn")
	state = PlatformState.RESPAWNING
	global_transform = _spawn_transform
	sprite.position = _sprite_position
	sprite.modulate = _sprite_tint
	sprite.modulate.a = 0.0
	show()
	_fade = create_tween()
	_fade.tween_property(sprite, "modulate:a", _sprite_tint.a, 0.25)
	_fade.tween_callback(_finish_respawn)


func _finish_respawn() -> void:
	collision_shape.set_deferred(&"disabled", false)
	trigger.set_deferred(&"monitoring", true)
	state = PlatformState.IDLE

