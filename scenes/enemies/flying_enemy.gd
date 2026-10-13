class_name FlyingEnemy
extends Enemy
## Idle: hover in place. DetectPlayer: chase directly. Dead: inherited death.

const STATE_IDLE: StringName = &"Idle"
const STATE_DETECT_PLAYER: StringName = &"DetectPlayer"

@export_range(0.0, 400.0, 10.0) var chase_speed: float = 90.0
@export_range(0.0, 5.0, 0.05) var lose_target_time: float = 2.0

var player_lost_timer: float = 0.0

@onready var detect_area: Area2D = %DetectArea
@onready var detect_shape: CollisionShape2D = %DetectShape


func _ready() -> void:
	has_gravity = false
	super._ready()
	var circle := detect_shape.shape.duplicate() as CircleShape2D
	circle.radius = detect_radius
	detect_shape.shape = circle
	detect_area.body_entered.connect(_on_detect_body_entered)


func enter_state(state_name: StringName) -> void:
	match state_name:
		STATE_IDLE:
			velocity = Vector2.ZERO
			player_lost_timer = 0.0
			play_anim(&"idle")
		STATE_DETECT_PLAYER:
			AudioManager.play_sfx(&"enemy_detect")
			player_lost_timer = 0.0
			play_anim(&"run")
		STATE_DEAD:
			super.enter_state(state_name)


func tick_idle(_delta: float) -> void:
	if dead:
		return
	velocity = Vector2.ZERO
	if can_see_player():
		state_machine.change_state(STATE_DETECT_PLAYER)


func tick_detect_player(delta: float) -> void:
	if dead:
		return
	if not can_see_player():
		velocity = Vector2.ZERO
		player_lost_timer += delta
		if player_lost_timer >= lose_target_time:
			state_machine.change_state(STATE_IDLE)
		return
	player_lost_timer = 0.0
	_face_player()
	var offset: Vector2 = player.global_position - global_position
	# Limit the final step so the enemy never overshoots its target.
	velocity = offset.normalized() * minf(chase_speed, offset.length() / maxf(delta, 0.000001))
	move_and_slide()


func _on_detect_body_entered(body: Node2D) -> void:
	if dead or not body.is_in_group(&"player"):
		return
	var target := body as Player
	if target == null:
		return
	player = target
	if can_see_player():
		state_machine.change_state(STATE_DETECT_PLAYER)


func _on_damaged(_amount: int, _from_pos: Vector2) -> void:
	if not dead:
		if health.is_alive():
			AudioManager.play_sfx(&"enemy_hurt")
		_start_flash()
