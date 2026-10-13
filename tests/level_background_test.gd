extends Node

const COLORS: Array[String] = ["Blue", "Blue", "Brown", "Gray", "Purple", "Pink", "Yellow"]
var failures: int = 0

func _ready() -> void:
	call_deferred(&"_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	for number in range(7):
		var level := (load("res://scenes/levels/Level%d.tscn" % number) as PackedScene).instantiate()
		add_child(level)
		var player := level.get_node("Player") as Player
		player.set_physics_process(false)
		player.state_machine.set_physics_process(false)
		var background := level.get_node("ScrollingBackground") as ScrollingLevelBackground
		await get_tree().create_timer(0.05).timeout
		_check(background.background.texture.resource_path == "res://assets/Background/%s.png" % COLORS[number], "Level%d must use %s" % [number, COLORS[number]])
		_check(background.background.get_global_rect().size.is_equal_approx(get_viewport().get_visible_rect().size), "Level%d background must cover the viewport" % number)
		_check(background.layer < -10 and background.background.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Background must stay behind the map without blocking input")
		var offset: float = background._offset
		await get_tree().create_timer(0.15).timeout
		_check(not is_equal_approx(background._offset, offset), "Background must scroll automatically")
		offset = background._offset
		get_tree().paused = true
		await get_tree().create_timer(0.1).timeout
		_check(is_equal_approx(background._offset, offset), "Background must freeze while paused")
		get_tree().paused = false
		level.queue_free()
		await get_tree().process_frame
		print("Level%d background verified: %s" % [number, COLORS[number]])
	var a := preload("res://scenes/levels/ScrollingBackground.tscn").instantiate() as ScrollingLevelBackground
	var b := preload("res://scenes/levels/ScrollingBackground.tscn").instantiate() as ScrollingLevelBackground
	add_child(a)
	add_child(b)
	_check(a.background.material != b.background.material, "Backgrounds must not share scrolling shader state")
	a.queue_free()
	b.queue_free()
	AudioManager.stop_music()
	AudioManager.stop_sfx()
	await get_tree().create_timer(0.1).timeout
	print("Level background checks complete: %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)
