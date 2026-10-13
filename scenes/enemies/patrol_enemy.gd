class_name PatrolEnemy
extends Enemy
## Patrol only on the initial supporting platform; never chase the player.

@export_range(4.0, 64.0, 1.0) var wall_check_distance: float = 10.0
@export_range(4.0, 64.0, 1.0) var floor_check_distance: float = 20.0
@export_range(0.1, 4.0, 0.1) var floor_height_tolerance: float = 1.0

var _floor_height: float = 0.0
var _floor_locked: bool = false
var _body_bottom: float = 8.0
var _body_half_width: float = 6.0

@onready var floor_check: RayCast2D = %FloorCheck
@onready var wall_check: RayCast2D = %WallCheck


func _ready() -> void:
	super._ready()
	var collision := find_child(^"CollisionShape2D", false, false) as CollisionShape2D
	if collision != null and collision.shape != null:
		var bounds: Rect2 = collision.shape.get_rect()
		_body_bottom = collision.position.y + bounds.end.y * collision.scale.y
		_body_half_width = bounds.size.x * absf(collision.scale.x) * 0.5
	_update_raycast_direction()


func tick_patrol(delta: float) -> void:
	_apply_gravity(delta)
	if is_on_floor():
		velocity.y = gravity * delta
	_step(delta)


func tick_detect(delta: float) -> void:
	state_machine.change_state(STATE_PATROL)
	tick_patrol(delta)


func tick_chase(delta: float) -> void:
	state_machine.change_state(STATE_PATROL)
	tick_patrol(delta)


func tick_attack(delta: float) -> void:
	state_machine.change_state(STATE_PATROL)
	tick_patrol(delta)


func _step(delta: float) -> void:
	if is_on_floor():
		if not _floor_locked:
			_floor_height = global_position.y + _body_bottom
			for index in get_slide_collision_count():
				var contact := get_slide_collision(index)
				if contact.get_normal().y < -0.7:
					_floor_height = contact.get_position().y
					break
			_floor_locked = true
		_update_raycast_direction()
		wall_check.force_raycast_update()
		if wall_check.is_colliding() or not _same_floor_ahead(delta):
			_flip()
			velocity.x = 0.0
			_update_raycast_direction()
		elif control_enabled:
			velocity.x = move_toward(velocity.x, float(direction) * speed, accel * delta)
	else:
		# Spawn in the air: settle vertically before selecting the patrol floor.
		velocity.x = 0.0
	move_and_slide()
	if sprite != null:
		sprite.flip_h = direction < 0


func _same_floor_ahead(delta: float) -> bool:
	var distance: float = maxf(floor_check_distance, _body_half_width + absf(velocity.x) * delta + floor_height_tolerance)
	var ahead := Vector2(global_position.x + float(direction) * distance, _floor_height)
	var query := PhysicsRayQueryParameters2D.create(
		ahead - Vector2(0, floor_height_tolerance),
		ahead + Vector2(0, floor_height_tolerance), 1)
	query.exclude = [get_rid()]
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var point: Vector2 = hit["position"]
	var normal: Vector2 = hit["normal"]
	return normal.y < -0.7 and absf(point.y - _floor_height) <= floor_height_tolerance


func _update_raycast_direction() -> void:
	wall_check.target_position = Vector2(float(direction) * maxf(wall_check_distance, _body_half_width + 1.0), 0)
	floor_check.position = Vector2(float(direction) * floor_check_distance, _body_bottom - floor_height_tolerance)
	floor_check.target_position = Vector2(0, floor_height_tolerance * 2.0)
