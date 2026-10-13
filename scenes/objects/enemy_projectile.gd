class_name EnemyProjectile
extends HitboxComponent
## Hostile layer 5 (bit value 16), with swept collision and ground-following waves.

@export var speed: float = 140.0
@export var life: float = 5.0
var travel_direction: Vector2 = Vector2.RIGHT
var ground_wave: bool = false
var source: Enemy
var _remaining: float


func _ready() -> void:
	super._ready()
	_remaining = life
	body_entered.connect(_on_body)
	area_entered.connect(_on_area)
	rotation = travel_direction.angle() if not ground_wave else 0.0
	queue_redraw()


func _excluded_enemies() -> Array[RID]:
	var excluded: Array[RID] = []
	for enemy in get_tree().get_nodes_in_group(&"enemy"):
		if enemy is CollisionObject2D:
			excluded.append(enemy.get_rid())
	return excluded


func _physics_process(delta: float) -> void:
	if is_instance_valid(source) and source.dead:
		_retire()
		return
	_remaining -= delta
	if _remaining <= 0.0:
		_retire()
		return
	var destination := global_position + travel_direction * speed * delta
	var space := get_world_2d().direct_space_state
	if ground_wave:
		var ground := PhysicsRayQueryParameters2D.create(destination + Vector2(0, -20), destination + Vector2(0, 32), 1)
		ground.exclude = _excluded_enemies()
		var floor_hit := space.intersect_ray(ground)
		if floor_hit.is_empty():
			_retire()
			return
		destination.y = (floor_hit.position as Vector2).y - 8.0
	var query := PhysicsRayQueryParameters2D.create(global_position, destination, 3)
	query.exclude = _excluded_enemies()
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		_on_body(hit.collider)
		return
	global_position = destination


func _on_body(body: Node2D) -> void:
	if body.is_in_group(&"enemy"):
		return
	if body is Player:
		var target := body as Player
		if target.hurtbox != null:
			target.hurtbox._on_area_entered(self)
	_retire()


func _on_area(area: Area2D) -> void:
	var receiver := area as HurtboxComponent
	if receiver != null and receiver.get_parent().is_in_group(&"player"):
		receiver._on_area_entered(self)
		_retire()


func _retire() -> void:
	set_active(false)
	queue_free()


func _draw() -> void:
	if ground_wave:
		draw_colored_polygon(PackedVector2Array([Vector2(-9, 6), Vector2(-5, -10), Vector2(0, -16), Vector2(5, -10), Vector2(9, 6)]), Color(1, 0.25, 0.65))
	else:
		draw_circle(Vector2.ZERO, 5.0, Color(1, 0.3, 0.6))
		draw_circle(Vector2.ZERO, 2.0, Color(1, 0.95, 0.85))
