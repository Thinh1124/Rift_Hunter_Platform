class_name BigGate
extends MonsterGate
## Cổng cuối ải boss: kế thừa MonsterGate nhưng không sinh quái và chỉ hoạt
## động sau khi boss chết.
##
##   EventBus.boss_defeated -> activate()
##   Closed -> EventBus.level_completed (thay cho gate_closed) + nổ ánh sáng + rung màn hình

## Nổ ánh sáng khi đóng.
@export_range(1, 60, 1) var burst_amount: int = 36
@export_range(0.0, 2.0, 0.05) var burst_time: float = 0.9
@export_range(0.0, 20.0, 0.5) var shake_strength: float = 7.0
@export var big_gate_sfx: StringName = &"pickup"

@onready var burst: CPUParticles2D = $Burst
@onready var burst_glow: Sprite2D = $BurstGlow


func _ready() -> void:
	burst.amount = burst_amount
	burst.lifetime = burst_time
	burst.emitting = false
	burst_glow.visible = false
	if burst_glow.texture == null:
		burst_glow.texture = _make_glow_texture()
	EventBus.boss_defeated.connect(_on_boss_defeated)
	super._ready()


func _on_boss_defeated() -> void:
	activate()


func _on_closed() -> void:
	EventBus.level_completed.emit()
	_play_burst()


func _play_burst() -> void:
	burst.restart()
	burst_glow.visible = true
	var tween := create_tween()
	tween.tween_property(burst_glow, "modulate:a", 0.0, burst_time)
	tween.parallel().tween_property(burst_glow, "scale", Vector2.ONE * 3.2, burst_time)
	tween.tween_callback(func() -> void: burst_glow.visible = false)
	EventBus.request_shake.emit(shake_strength, 0.8)


func _make_glow_texture() -> ImageTexture:
	var size := 64
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := Vector2(size * 0.5, size * 0.5)
	var outer := size * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(center) / outer
			if d <= 1.0:
				image.set_pixel(x, y, Color(1.0, 0.80, 1.0, 0.55 * (1.0 - d)))
	return ImageTexture.create_from_image(image)