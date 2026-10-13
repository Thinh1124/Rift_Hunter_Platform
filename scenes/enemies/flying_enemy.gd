class_name FlyingEnemy
extends Enemy
## Enemy bay với làn sóng sin, đuổi player, quay về nhà.

@export_range(0.0, 400.0, 10.0) var amplitude: float = 20.0
@export_range(0.1, 10.0, 0.1) var frequency: float = 2.0
@export_range(0.0, 400.0, 10.0) var chase_speed: float = 90.0
@export_range(0.0, 5.0, 0.05) var lose_target_time: float = 2.0

var home_position: Vector2
var time_elapsed: float = 0.0
var player_lost_timer: float = 0.0

@onready var detect_area: Area2D = $DetectArea


func _ready() -> void:
	# Gọi parent ready
	super._ready()
	
	# Lưu nhà
	home_position = global_position
	
	# Kết nối DetectArea
	detect_area.area_entered.connect(_on_detect_area_entered)
	detect_area.area_exited.connect(_on_detect_area_exited)
	
	# Cập nhật detect_area radius
	for child in detect_area.get_children():
		if child is CollisionShape2D:
			if child.shape is CircleShape2D:
				child.shape.radius = detect_radius


func _on_patrol(_delta: float) -> void:
	"""Bay ngang, tính toán speed"""
	velocity.x = float(direction) * speed
	# Y sẽ được update trong physics_process bằng sine wave


func _on_detect(_delta: float) -> void:
	"""Không dùng"""
	pass


func _on_chase(_delta: float) -> void:
	"""Đuổi player trực tiếp"""
	if player == null or not is_instance_valid(player):
		return
	
	var direction_to_player = (player.global_position - global_position).normalized()
	velocity = direction_to_player * chase_speed


func _on_attack(_delta: float) -> void:
	"""Không dùng"""
	pass


## Override tick_patrol để không gọi _step, dùng custom movement
func tick_patrol(delta: float) -> void:
	_on_patrol(delta)
	# Không áp gravity
	_move_flying(delta)
	
	# Kiểm tra player (DetectArea sẽ xử lý chuyển state)


## Override tick_chase để custom movement
func tick_chase(delta: float) -> void:
	_on_chase(delta)
	_move_flying(delta)
	
	# Nếu player ra khỏi DetectArea, timer tăng
	player_lost_timer += delta
	if player_lost_timer >= lose_target_time:
		state_machine.change_state(&"Return")
		player_lost_timer = 0.0


## Xử lý Return state (bay về home)
func tick_return(delta: float) -> void:
	if global_position.distance_to(home_position) < 10.0:
		# Tới home, quay lại Patrol
		state_machine.change_state(&"Patrol")
		time_elapsed = 0.0
		return
	
	var direction_to_home = (home_position - global_position).normalized()
	velocity = direction_to_home * speed
	_move_flying(delta)


## Hành động fly - di chuyển và update Y với sine wave
func _move_flying(_delta: float) -> void:
	time_elapsed += _delta
	
	# Có thể gọi move_and_slide() hoặc không
	move_and_slide()

	# Update Y position theo sine wave (nhưng chỉ trong Patrol)
	if state_machine.is_current(&"Patrol"):
		var vertical_offset = sin(time_elapsed * frequency * TAU) * amplitude
		global_position.y = home_position.y + vertical_offset


func _on_detect_area_entered(area: Area2D) -> void:
	"""Player vào DetectArea -> Chase"""
	if area.get_parent() is Player:
		player = area.get_parent() as Player
		if state_machine != null and not state_machine.is_current(&"Chase"):
			state_machine.change_state(&"Chase")
			player_lost_timer = 0.0


func _on_detect_area_exited(area: Area2D) -> void:
	"""Player ra khỏi DetectArea - timer bắt đầu"""
	if area.get_parent() is Player:
		if state_machine != null and state_machine.is_current(&"Chase"):
			player_lost_timer = 0.0  # Reset timer khi vừa ra khỏi
