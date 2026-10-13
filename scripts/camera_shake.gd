class_name CameraShake
extends Camera2D
## Rung camera theo EventBus.request_shake(strength, duration).
## Gắn script này vào Camera2D. Offset rung giảm dần theo trauma^2.

## Cường độ rung tối đa (px).
@export var max_offset: Vector2 = Vector2(6.0, 5.0)
## Chia chuẩn hoá: strength / shake_scale = trauma.
@export_range(1.0, 32.0, 0.5) var shake_scale: float = 8.0
## Tần số nhiễu (Hz).
@export_range(4.0, 60.0, 0.5) var frequency: float = 24.0
## Trần tốc độ giảm trauma khi không nhận yêu cầu mới.
@export_range(0.1, 10.0, 0.1) var idle_decay: float = 3.0

var _trauma: float = 0.0
var _decay_rate: float = 3.0
var _time: float = 0.0
var _noise := FastNoiseLite.new()


func _ready() -> void:
	_noise.seed = 0x5ACE
	_noise.frequency = 0.5
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	EventBus.request_shake.connect(_on_request_shake)


func _process(delta: float) -> void:
	if _trauma <= 0.0:
		if offset != Vector2.ZERO:
			offset = Vector2.ZERO
		return
	_time += delta * frequency
	var amount: float = _trauma * _trauma
	offset = Vector2(_noise.get_noise_1d(_time), _noise.get_noise_1d(_time + 311.7)) * max_offset * amount
	_trauma = maxf(_trauma - _decay_rate * delta, 0.0)


## duration = thời gian để trauma tụt từ 1 về 0.
func _on_request_shake(strength: float, duration: float) -> void:
	var added: float = clampf(strength / shake_scale, 0.0, 1.0)
	_trauma = clampf(_trauma + added, 0.0, 1.0)
	_decay_rate = 1.0 / maxf(duration, 0.05)
	if duration <= 0.0:
		_decay_rate = idle_decay


## Trauma hiện tại (0..1) - hữu ích để test.
func get_trauma() -> float:
	return _trauma