@tool
class_name Saw
extends Node2D
## A/B are generated from the route exports. The root stays at the rail origin.

signal endpoint_reached(endpoint: int)

@export_range(0.0, 1000.0, 1.0) var speed: float = 60.0
@export_range(0.0, 2000.0, 1.0) var path_length: float = 96.0:
	set(length):
		path_length = maxf(0.0, length)
		if is_node_ready():
			_update_path()
@export var direction: Vector2 = Vector2.RIGHT:
	set(heading):
		direction = heading
		if is_node_ready():
			_update_path()
@export var rotation_speed: float = 720.0
@export_range(1, 99, 1) var damage: int = 1:
	set(amount):
		damage = amount
		if is_node_ready():
			$HitboxComponent.damage = damage
@export_range(0.0, 5.0, 0.05) var pause_at_ends: float = 0.3

@onready var point_a: Marker2D = $Path/A
@onready var point_b: Marker2D = $Path/B
@onready var hitbox: HitboxComponent = $HitboxComponent
@onready var sprite: AnimatedSprite2D = $HitboxComponent/AnimatedSprite2D
@onready var sparks: CPUParticles2D = $Sparks

var _distance: float = 0.0
var _travel_sign: int = 1
var _pause_left: float = 0.0


func _ready() -> void:
	_update_path()
	hitbox.damage = damage
	if not Engine.is_editor_hint():
		sprite.play(&"spin")


func _update_path() -> void:
	point_a.position = Vector2.ZERO
	point_b.position = direction.normalized() * path_length
	_distance = 0.0
	_travel_sign = 1
	_pause_left = 0.0
	hitbox.position = _local_point(point_a)
	queue_redraw()


func _local_point(marker: Marker2D) -> Vector2:
	return ($Path as Node2D).transform * marker.position


func _draw() -> void:
	if not Engine.is_editor_hint() or not is_node_ready():
		return
	var start := _local_point(point_a)
	var end := _local_point(point_b)
	draw_dashed_line(start, end, Color(0.3, 0.85, 1.0, 0.8), 2.0, 6.0)
	draw_circle(start, 4.0, Color(0.4, 1.0, 0.6))
	draw_circle(end, 4.0, Color(1.0, 0.6, 0.2))


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	sprite.rotation = wrapf(sprite.rotation + deg_to_rad(rotation_speed) * delta, -PI, PI)
	_tick_motion(delta)
	if not hitbox.active or not hitbox.monitoring:
		return
	for area in hitbox.get_overlapping_areas():
		var receiver := area as HurtboxComponent
		if receiver != null and receiver.get_parent().is_in_group(&"player"):
			receiver._on_area_entered(hitbox)


func _tick_motion(delta: float) -> void:
	var start := _local_point(point_a)
	var end := _local_point(point_b)
	var length := start.distance_to(end)
	if length <= 0.001 or speed <= 0.0:
		return
	var remaining := maxf(delta, 0.0)
	while remaining > 0.0:
		if _pause_left > 0.0:
			var spent := minf(_pause_left, remaining)
			_pause_left -= spent
			remaining -= spent
			continue
		var destination := length if _travel_sign > 0 else 0.0
		var time_to_end := absf(destination - _distance) / speed
		if remaining < time_to_end:
			_distance += _travel_sign * speed * remaining
			remaining = 0.0
		else:
			_distance = destination
			remaining -= time_to_end
			hitbox.position = start.lerp(end, _distance / length)
			var heading := (end - start).normalized() * _travel_sign
			_emit_end_sparks(hitbox.position, heading)
			endpoint_reached.emit(1 if _travel_sign > 0 else 0)
			_travel_sign = -_travel_sign
			_pause_left = maxf(0.0, pause_at_ends)
		hitbox.position = start.lerp(end, _distance / length)


func _emit_end_sparks(endpoint: Vector2, heading: Vector2) -> void:
	var origin := to_global(endpoint)
	var ahead := to_global(endpoint + heading * 16.0)
	var query := PhysicsRayQueryParameters2D.create(origin, ahead, 1)
	query.hit_from_inside = true
	var excluded: Array[RID] = [hitbox.get_rid()]
	for enemy in get_tree().get_nodes_in_group(&"enemy"):
		if enemy is CollisionObject2D:
			excluded.append(enemy.get_rid())
	query.exclude = excluded
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	sparks.global_position = hit.position
	var normal: Vector2 = hit.normal
	if normal.is_zero_approx():
		normal = -(ahead - origin).normalized()
	sparks.direction = global_transform.basis_xform_inv(normal)
	sparks.restart()
	sparks.emitting = true
