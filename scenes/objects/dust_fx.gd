class_name DustFX
extends CPUParticles2D
## Puff bụi dùng lại. One-shot, tự hủy khi hết hạt.
## Dùng: DustFX.spawn(parent, pos)

const SCENE_PATH: String = "res://scenes/objects/DustFX.tscn"

var _self_free: bool = true


static func spawn(parent: Node, pos: Vector2) -> DustFX:
	if parent == null or not parent.is_inside_tree():
		return null
	var packed: PackedScene = load(SCENE_PATH)
	if packed == null:
		push_warning("DustFX.spawn: không load được %s" % SCENE_PATH)
		return null
	var fx := packed.instantiate() as DustFX
	if fx == null:
		return null
	parent.add_child(fx)
	fx.global_position = pos
	fx.play()
	return fx


## Bắt đầu phát. Gọi _ready() nếu muốn tự hủy, false = giữ lại để dùng lại.
func play() -> void:
	restart()
	emitting = true


func _ready() -> void:
	if _self_free:
		finished.connect(queue_free)