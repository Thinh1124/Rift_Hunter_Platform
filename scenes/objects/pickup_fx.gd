class_name PickupFX
extends CPUParticles2D
## Vòng hạt vàng tỏa ra khi nhặt đồ. One-shot, tự hủy khi hết hạt.
## Dùng: PickupFX.spawn(parent, pos)

const SCENE_PATH: String = "res://scenes/objects/PickupFX.tscn"


static func spawn(parent: Node, pos: Vector2) -> PickupFX:
	if parent == null or not parent.is_inside_tree():
		return null
	var packed: PackedScene = load(SCENE_PATH)
	if packed == null:
		push_warning("PickupFX.spawn: không load được %s" % SCENE_PATH)
		return null
	var fx := packed.instantiate() as PickupFX
	if fx == null:
		return null
	parent.add_child(fx)
	fx.global_position = pos
	fx.play()
	return fx


func play() -> void:
	restart()
	emitting = true


func _ready() -> void:
	finished.connect(queue_free)