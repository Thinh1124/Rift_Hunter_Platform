class_name PatrolEnemy
extends Enemy
## Enemy tuần tra đơn giản: đi lại, quay đầu khi gặp tường/mép bục.

@export_range(4.0, 64.0, 1.0) var wall_check_distance: float = 10.0
@export_range(4.0, 64.0, 1.0) var floor_check_distance: float = 20.0

@onready var floor_check: RayCast2D = $FloorCheck
@onready var wall_check: RayCast2D = $WallCheck


func _ready() -> void:
	# Gọi parent ready trước
	super._ready()
	
	# Cấu hình raycast
	_update_raycast_direction()


func _on_patrol(_delta: float) -> void:
	"""Tuần tra: kiểm tra tường/mép bục, quay đầu nếu cần."""
	# Kiểm tra tường
	if wall_check != null and wall_check.is_colliding():
		_flip()
		_update_raycast_direction()
		return
	
	# Kiểm tra mép bục (không có đất trước mặt)
	if floor_check != null and not floor_check.is_colliding():
		_flip()
		_update_raycast_direction()
		return


func _on_detect(_delta: float) -> void:
	"""Trong state Detect: just stand still."""
	pass


func _on_chase(_delta: float) -> void:
	"""Không có chase behavior - quay lại patrol."""
	_face_player()
	pass


func _on_attack(_delta: float) -> void:
	"""Không có attack behavior."""
	pass


## Cập nhật hướng raycast khi quay đầu.
func _update_raycast_direction() -> void:
	if wall_check != null:
		wall_check.target_position = Vector2(float(direction) * wall_check_distance, 0.0)
	
	if floor_check != null:
		floor_check.target_position = Vector2(float(direction) * 12.0, floor_check_distance)
