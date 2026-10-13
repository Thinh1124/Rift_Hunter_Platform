class_name UIIcons
extends RefCounted
## Icon dùng chung cho UI, cache theo path để không load lại mỗi frame.
##
## Tách khỏi PixelIcons vì đây là ảnh CÓ SẴN trong repo, còn PixelIcons là ảnh VẼ
## bằng code. Cả hai đều trả ImageTexture để HUD gắn thẳng vào TextureRect.

const HEART: String = "res://assets/Items/heart.svg"
const SHIELD: String = "res://assets/Items/shield.svg"
const GATE: String = "res://assets/Items/Checkpoints/End/End (Idle).png"

static var _cache: Dictionary[String, Texture2D] = {}


## Icon mảnh Rift. Repo không có sprite shard nên vẽ bằng PixelIcons.
static func shard_icon(size: int = 14) -> Texture2D:
	return PixelIcons.shard(size)


## Nạp texture từ res://, cache lại. Sai path -> null + báo lỗi 1 lần.
static func get_icon(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		push_error("UIIcons: không thấy icon '%s'." % path)
		return null
	var tex: Resource = load(path)
	if tex is Texture2D:
		_cache[path] = tex
		return tex
	push_error("UIIcons: '%s' không phải Texture2D." % path)
	return null


## Texture phẳng cho TextureProgressBar. KHÔNG bật nine_patch_stretch:
## texture này không có lề, bật 9-patch sẽ cắt vỡ thanh.
static func progress_background(size: Vector2 = Vector2(8, 8), color: Color = Color(0.12, 0.08, 0.16, 0.9)) -> Texture2D:
	return _flat_texture("bar_bg:%s:%s" % [size, color.to_html()], size, color)


static func progress_fill(size: Vector2 = Vector2(8, 8), color: Color = Color(0.85, 0.20, 0.30)) -> Texture2D:
	return _flat_texture("bar_fill:%s:%s" % [size, color.to_html()], size, color)


static func _flat_texture(key: String, size: Vector2, color: Color) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var w: int = maxi(int(round(size.x)), 1)
	var h: int = maxi(int(round(size.y)), 1)
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(color)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex