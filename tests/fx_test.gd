extends Node2D
## Nghiệm thu: DustFX.spawn() hiện hạt đúng vị trí rồi tự biến mất.

var world: Node2D
var camera: Camera2D
var dust: DustFX
var pickup: PickupFX


func _ready() -> void:
	print("=== FX TEST ===")
	world = $World
	camera = $World/Camera

	var target: Vector2 = Vector2(320, 200)
	print("spawn at ", target)
	dust = DustFX.spawn(world, target)

	print("fx != null             : ", dust != null)
	print("amount (so hat)         : ", dust.amount)
	print("lifetime (s)            : ", "%.2f" % dust.lifetime)
	print("one_shot                : ", dust.one_shot)
	print("emitting                : ", dust.emitting)
	print("global_position khop    : ", dust.global_position.is_equal_approx(target))
	print("parent dung             : ", dust.get_parent() == world)

	pickup = PickupFX.spawn(world, target + Vector2(0, -40))
	print("PickupFX amount         : ", pickup.amount, " lifetime=", "%.2f" % pickup.lifetime, " pos=", pickup.global_position)

	await get_tree().create_timer(0.1).timeout
	print("--- sau 0.10s (dang chay) ---")
	print("is_instance_valid(dust) : ", is_instance_valid(dust))
	print("dust.emitting          : ", dust.emitting)
	print("camera offset (chua rung): ", camera.offset)

	EventBus.request_shake.emit(6.0, 0.4)
	await get_tree().create_timer(0.05).timeout
	print("camera offset (dang rung): ", camera.offset, " trauma=", "%.2f" % camera.get_trauma())

	await get_tree().create_timer(0.6).timeout
	print("--- sau 0.70s ---")
	print("is_instance_valid(dust)  : ", is_instance_valid(dust))
	print("is_instance_valid(pickup) : ", is_instance_valid(pickup))
	print("camera offset (da dung)  : ", camera.offset)
	print("=== FX TEST DONE ===")
	await get_tree().create_timer(0.3).timeout
	get_tree().quit()
