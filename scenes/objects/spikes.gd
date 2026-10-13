@tool
class_name Spikes
extends HitboxComponent

@export_range(1, 256, 1) var tile_count: int = 1:
	set(count):
		tile_count = maxi(1, count)
		if is_node_ready():
			_update_layout()

@export_enum("Up:0", "Right:90", "Down:180", "Left:270") var rotation_dir: int = 0:
	set(degrees):
		rotation_dir = degrees
		if is_node_ready():
			_update_layout()


func _ready() -> void:
	_update_layout()
	if not Engine.is_editor_hint():
		super._ready()


func _update_layout() -> void:
	var sprite := $Sprite2D as Sprite2D
	var collision := $CollisionShape2D as CollisionShape2D
	if sprite.texture == null:
		return
	var tile_size := sprite.texture.get_size()
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sprite.region_enabled = true
	sprite.region_rect = Rect2(Vector2.ZERO, Vector2(tile_size.x * tile_count, tile_size.y))
	# Match the opaque spike height rather than its transparent sprite padding.
	var image := sprite.texture.get_image()
	if image.is_compressed():
		image.decompress()
	var visible_rect := image.get_used_rect()
	var rectangle := collision.shape as RectangleShape2D
	if rectangle == null:
		rectangle = RectangleShape2D.new()
		collision.shape = rectangle
	rectangle.size = Vector2(tile_size.x * tile_count, maxf(1.0, visible_rect.size.y))
	collision.position = Vector2(0, visible_rect.position.y + visible_rect.size.y * 0.5 - tile_size.y * 0.5)
	rotation_degrees = float(rotation_dir)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or not active or not monitoring:
		return
	# Also recheck persistent contact after i-frames expire; the receiver owns
	# damage cooldown and immunity, so this cannot double-hit on area_entered.
	for area in get_overlapping_areas():
		var receiver := area as HurtboxComponent
		if receiver != null and receiver.get_parent().is_in_group(&"player"):
			receiver._on_area_entered(self)
