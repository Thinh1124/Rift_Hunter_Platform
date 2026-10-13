extends Node

var failures: int = 0

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _ready() -> void:
	var boot := get_node("Boot")
	await get_tree().create_timer(1.1).timeout
	_check(boot.menu_loaded(), "MainMenu must finish loading in the background")
	var bar := boot.get_node("%LoadBar") as ProgressBar
	var track := boot.get_node("%RunnerTrack") as Control
	var group := boot.get_node("%Runners") as Node2D
	_check(bar.ratio > 0 and bar.ratio < 1, "Boot must display intermediate progress")
	_check(bar.get_global_rect().position.y > get_viewport().get_visible_rect().size.y * 0.75, "Loading bar must sit at the bottom")
	_check(is_equal_approx(group.position.x, (track.size.x - 128.0) * bar.ratio), "Runner translation must match the bar progress")
	var previous_x: float = -INF
	for name: String in ["NinjaFrog", "PinkMan", "VirtualGuy", "MaskDude"]:
		var sprite := boot.get_node("%" + name) as AnimatedSprite2D
		_check(sprite.animation == &"run" and sprite.is_playing(), name + " must use its run animation")
		_check(is_zero_approx(sprite.position.y) and sprite.position.x > previous_x, "All runners must share a row and keep their ordering")
		previous_x = sprite.position.x
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/boot_loading_preview.png")
	while not boot._done and boot._elapsed < 5:
		await get_tree().process_frame
	_check(boot._done and bar.ratio == 1 and boot.menu_loaded(), "Boot must reach 100 percent before requesting MainMenu")
	_check(is_equal_approx(group.position.x, track.size.x - 128.0), "Runners must finish at the end of the loading track")
	print("Boot loading checks complete: %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)
