class_name KillZone
extends Area2D
## Player death/life loss belongs to Player's existing Dead state.

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		body.kill_by_hazard()
	elif body.is_in_group(&"enemy"):
		body.queue_free()


func _physics_process(_delta: float) -> void:
	if not monitoring or collision_shape.disabled or collision_shape.shape == null:
		return
	# Keep the requested mask 2. New enemies use layer 3 (bit value 4),
	# so query the same rectangle for those bodies without changing the mask.
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision_shape.shape
	query.transform = collision_shape.global_transform
	query.collision_mask = 4
	query.collide_with_areas = false
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 64):
		var body := hit.collider as Node2D
		if body != null and body.is_in_group(&"enemy"):
			body.queue_free()
