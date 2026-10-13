class_name RiftShard
extends Pickup
## Mảnh vụn Rift — vật phẩm chính của RIFT HUNTER.
##
## Quái rơi ra khi chết. Người chơi thu đủ GameManager.SHARDS_REQUIRED mảnh
## trong màn thì cánh cổng ra cuối màn mở, chạm vào là qua màn.
##
## Hình do PixelIcons.shard() vẽ bằng code (repo không có sprite shard sẵn).
## Muốn thay bằng asset thật: gán `sprite_frames` trong RiftShard.tscn rồi
## xoá _build_frames().

## Tốc độ quay của dải "spin".
const SPIN_FPS: float = 8.0
## Mỗi frame nghiêng sắc độ + sáng khác nhau -> nhấp nháy như kính vỡ.
const FRAMES: Array[float] = [1.00, 0.86, 1.08, 0.94]


func _ready() -> void:
	sprite = $Sprite
	sprite_frames = _build_frames()
	# Nhặt lần đầu (Pickup._ready) mới gán sprite_frames và phát "spin".
	super._ready()


## Dựng dải "spin": 4 frame, cùng một mảnh nhưng đổi sắc độ/sáng theo vòng.
func _build_frames() -> SpriteFrames:
	var base := Color(0.42, 0.84, 0.96)
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"spin")
	frames.set_animation_speed(&"spin", SPIN_FPS)
	frames.set_animation_loop(&"spin", true)
	for s: float in FRAMES:
		var tex: Texture2D = PixelIcons.shard(16, base.lightened((s - 1.0) * 0.6))
		frames.add_frame(&"spin", tex)
	return frames