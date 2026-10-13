extends Node2D
## CHUP ANH ENEMY DE KIEM TRA HINH DUNG + KICH THUOC THUC TE.
## Chay: godot --rendering-driver opengl3 --position -3000,-3000 res://tests/enemy_shots.tscn

const LIST: Array[String] = [
	"Mushroom", "Bomb", "Bee", "ShooterEnemy",
	"RockGrunt", "ChargerEnemy", "FlyingBug", "Boss",
]

const GAP: float = 76.0
const BASE_Y: float = 288.0

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://enemy_shots")

	var bg := ColorRect.new()
	bg.color = Color(0.35, 0.42, 0.50)
	bg.size = Vector2(640, 360)
	add_child(bg)

	# Net san de chan duoi.
	var l := Line2D.new()
	l.width = 2.0
	l.default_color = Color(0.85, 0.85, 0.85)
	l.add_point(Vector2(0, BASE_Y))
	l.add_point(Vector2(640, BASE_Y))
	add_child(l)

	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(320, BASE_Y + 40)
	add_child(floor_body)
	var fs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(900, 40)
	fs.shape = rect
	floor_body.add_child(fs)

	var x: float = 320.0 - GAP * (LIST.size() - 1) * 0.5
	for i in LIST.size():
		var packed: PackedScene = load("res://scenes/enemies/%s.tscn" % LIST[i]) as PackedScene
		var e: Node2D = packed.instantiate() as Node2D
		add_child(e)
		await get_tree().process_frame
		# Dung yen, khong rơi, phat idle.
		if e is CharacterBody2D:
			(e as CharacterBody2D).has_gravity = false
		var sm: Node = e.get_node_or_null("StateMachine") as Node
		if sm != null:
			sm.set_physics_process(false)
		var sp: AnimatedSprite2D = e.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if sp != null:
			sp.stop()
			sp.play(&"walk")
			sp.frame = 0
		# Dat chan: vi tri goc - gan nua doc - xuong san.
		e.position = Vector2(x + i * GAP, BASE_Y - _body_half(e))

	for _i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame

	get_viewport().get_texture().get_image().save_png("user://enemy_shots/all.png")
	print("  luu all.png")
	get_tree().quit()


## Nua chieu cao collider de chan dung xuong duong dat.
func _body_half(root: Node) -> float:
	for c in root.get_children():
		if c is CollisionShape2D:
			var s: Shape2D = (c as CollisionShape2D).shape
			if s is CapsuleShape2D:
				return (s as CapsuleShape2D).height * 0.5
			if s is RectangleShape2D:
				return (s as RectangleShape2D).size.y * 0.5
			if s is CircleShape2D:
				return (s as CircleShape2D).radius
	var sp: AnimatedSprite2D = root.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sp != null:
		return sp.scale.y * sp.sprite_frames.get_frame_texture(&"idle", 0).get_height() * 0.5
	return 12.0