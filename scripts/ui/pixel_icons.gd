class_name PixelIcons
extends RefCounted
## Vẽ icon pixel bằng code (sao, ổ khóa, boss, tim) cho UI.
##
## Repo KHÔNG có sẵn icon cho mấy thứ này (chỉ có heart.svg/shield.svg cho
## pickup trong thế giới), nên dựng ImageTexture lúc chạy.
## Cache theo (loại, kích thước, màu) để không vẽ lại mỗi lần refresh().
## Muốn thay bằng asset thật: bỏ qua hàm tương ứng, set texture trong .tscn.

const CACHE_MAX: int = 64

static var _cache: Dictionary[String, ImageTexture] = {}


## Sao 5 cánh. filled = false -> chỉ viền (chưa thắng).
static func star(size: int = 16, filled: bool = true, color: Color = Color(1.0, 0.84, 0.25)) -> ImageTexture:
	return _cached("star:%d:%s:%s" % [size, filled, color.to_html()], size, func(px: int) -> Image:
		var img := _blank(px)
		var points := _star_points(px)
		# Sao rongchi giu vong giua star() va star() thu nho -> viet vong.
		# Phai kiem tra "trong star()" truoc; neu chi lay "ngoai star() thu nho"
		# thi o vuong nen se bi to mau va hinh thanh mot khoang trong o vuong.
		var inner := _shrink(points, 0.82)
		for y in px:
			for x in px:
				var p := _center_of(x, y)
				if filled:
					if _point_in_polygon(p, points):
						img.set_pixel(x, y, color)
				elif _point_in_polygon(p, points) and not _point_in_polygon(p, inner):
					img.set_pixel(x, y, color)
		return img)


## Ổ khóa: móc trên + thân + lỗ chìa khoá.
static func lock(size: int = 16, color: Color = Color(0.75, 0.78, 0.86)) -> ImageTexture:
	return _cached("lock:%d:%s" % [size, color.to_html()], size, func(px: int) -> Image:
		var img := _blank(px)
		var cx: float = px * 0.5
		var shackle_c := Vector2(cx, px * 0.30)
		var shackle_r: float = px * 0.22
		var shackle_t: float = maxf(px / 10.0, 1.0)
		var body := Rect2(Vector2(px * 0.22, px * 0.46), Vector2(px * 0.56, px * 0.38))
		var hole := Rect2(Vector2(cx - px * 0.07, px * 0.58), Vector2(px * 0.14, px * 0.14))
		for y in px:
			for x in px:
				var p := _center_of(x, y)
				if p.y <= shackle_c.y and p.distance_to(shackle_c) <= shackle_r \
						and p.distance_to(shackle_c) >= shackle_r - shackle_t:
					img.set_pixel(x, y, color)
				elif body.has_point(p):
					img.set_pixel(x, y, color)
				elif hole.has_point(p):
					img.set_pixel(x, y, Color(0.1, 0.12, 0.18, 1))
		return img)


## Icon boss: đầu quái + sừng + mắt đỏ.
static func boss(size: int = 24, color: Color = Color(0.62, 0.24, 0.72)) -> ImageTexture:
	return _cached("boss:%d:%s" % [size, color.to_html()], size, func(px: int) -> Image:
		var img := _blank(px)
		var head := Rect2(px * 0.18, px * 0.34, px * 0.64, px * 0.50)
		var horn_l := Rect2(px * 0.10, px * 0.10, px * 0.14, px * 0.30)
		var horn_r := Rect2(px * 0.76, px * 0.10, px * 0.14, px * 0.30)
		var eye_l := Rect2(px * 0.30, px * 0.48, px * 0.13, px * 0.11)
		var eye_r := Rect2(px * 0.57, px * 0.48, px * 0.13, px * 0.11)
		var mouth := Rect2(px * 0.34, px * 0.70, px * 0.32, px * 0.08)
		for y in px:
			for x in px:
				var p := _center_of(x, y)
				if head.has_point(p) or horn_l.has_point(p) or horn_r.has_point(p):
					img.set_pixel(x, y, color)
				elif eye_l.has_point(p) or eye_r.has_point(p):
					img.set_pixel(x, y, Color(1.0, 0.30, 0.25, 1))
				elif mouth.has_point(p):
					img.set_pixel(x, y, Color(0.08, 0.06, 0.12, 1))
		return img)


## Trái cây (vòng tròn + lá) cho HUD.
static func fruit(size: int = 16, color: Color = Color(0.86, 0.28, 0.32)) -> ImageTexture:
	return _cached("fruit:%d:%s" % [size, color.to_html()], size, func(px: int) -> Image:
		var img := _blank(px)
		var center := Vector2(px * 0.5, px * 0.58)
		var r: float = px * 0.38
		var stem := Rect2(Vector2(px * 0.46, px * 0.10), Vector2(px * 0.10, px * 0.16))
		var leaf := Rect2(Vector2(px * 0.56, px * 0.12), Vector2(px * 0.24, px * 0.10))
		var shine := Rect2(Vector2(px * 0.30, px * 0.40), Vector2(px * 0.12, px * 0.12))
		for y in px:
			for x in px:
				var p := _center_of(x, y)
				if p.distance_to(center) <= r:
					if shine.has_point(p):
						img.set_pixel(x, y, color.lightened(0.55))
					else:
						img.set_pixel(x, y, color)
				elif stem.has_point(p):
					img.set_pixel(x, y, Color(0.36, 0.24, 0.14, 1))
				elif leaf.has_point(p):
					img.set_pixel(x, y, Color(0.36, 0.66, 0.28, 1))
		return img)


## Cổng (khung + cánh cổng) cho HUD.
static func gate(size: int = 16, color: Color = Color(0.55, 0.85, 1)) -> ImageTexture:
	return _cached("gate:%d:%s" % [size, color.to_html()], size, func(px: int) -> Image:
		var img := _blank(px)
		var t: float = maxf(px / 12.0, 1.0)
		var post_l := Rect2(Vector2(px * 0.14, px * 0.20), Vector2(t, px * 0.70))
		var post_r := Rect2(Vector2(px * 0.86 - t, px * 0.20), Vector2(t, px * 0.70))
		var top := Rect2(Vector2(px * 0.14, px * 0.14), Vector2(px * 0.72, t))
		var panel := Rect2(Vector2(px * 0.24, px * 0.30), Vector2(px * 0.52, px * 0.56))
		for y in px:
			for x in px:
				var p := _center_of(x, y)
				if post_l.has_point(p) or post_r.has_point(p) or top.has_point(p):
					img.set_pixel(x, y, color)
				elif panel.has_point(p):
					# Sọc dọc để nhìn ra là cổng, không phải ô đặc.
					img.set_pixel(x, y, color.darkened(0.45) if (x / maxi(int(t), 1)) % 2 == 0 else color.darkened(0.2))
		return img)


## Tim đầy (fill) hoặc rỗng (chỉ viền) cho thanh HP.
static func heart(size: int = 16, filled: bool = true, color: Color = Color(1.0, 0.40, 0.55)) -> ImageTexture:
	return _cached("heart:%d:%s:%s" % [size, filled, color.to_html()], size, func(px: int) -> Image:
		var img := _blank(px)
		var outline := color.darkened(0.55)
		for y in px:
			for x in px:
				var p := _center_of(x, y)
				var inside := _point_in_polygon(p, _heart_points(px))
				if not inside:
					continue
				if filled:
					img.set_pixel(x, y, color)
				elif not _point_in_polygon(p, _shrink(_heart_points(px), 0.82)):
					img.set_pixel(x, y, outline)
		return img)


## Kiếm: lưỡi nhọn + chuôi chắn + cán. Dùng cho chỉ số ATK ở CharacterSelect.
static func sword(size: int = 12, color: Color = Color(0.88, 0.90, 0.96)) -> ImageTexture:
	return _cached("sword:%d:%s" % [size, color.to_html()], size, func(px: int) -> Image:
		var img := _blank(px)
		var cx: float = px * 0.5
		var half: float = px * 0.09          # nửa bề rộng lưỡi
		var tip_y: float = px * 0.14        # lưỡi thuôn nhọn từ đây trở lên
		var guard_y: float = px * 0.68
		var guard := Rect2(Vector2(px * 0.26, guard_y), Vector2(px * 0.48, px * 0.10))
		var handle := Rect2(Vector2(px * 0.43, px * 0.78), Vector2(px * 0.14, px * 0.15))
		var pommel := Rect2(Vector2(px * 0.38, px * 0.90), Vector2(px * 0.24, px * 0.09))
		var guard_c := color.darkened(0.38)
		var handle_c := color.darkened(0.58)
		for y in px:
			for x in px:
				var p := _center_of(x, y)
				if p.y >= tip_y and p.y <= guard_y and absf(p.x - cx) <= half:
					img.set_pixel(x, y, color)
				elif p.y < tip_y and absf(p.x - cx) <= (tip_y - p.y) * 0.5:
					img.set_pixel(x, y, color)
				elif guard.has_point(p):
					img.set_pixel(x, y, guard_c)
				elif handle.has_point(p) or pommel.has_point(p):
					img.set_pixel(x, y, handle_c)
		return img)


## Mảnh vụn Rift: tinh thể nhiều mặt (facet sáng ở giữa). Đồ vật chính của
## game: quái rơi ra, người chơi thu đủ để mở cánh cổng cuối màn.
static func shard(size: int = 12, color: Color = Color(0.42, 0.84, 0.96)) -> ImageTexture:
	return _cached("shard:%d:%s" % [size, color.to_html()], size, func(px: int) -> Image:
		var img := _blank(px)
		# Ngũ giác lệch: nhọn trên, hai vai rộng, đáy hẹp -> trông như mảnh kính vỡ.
		var pts := PackedVector2Array([
			Vector2(px * 0.50, px * 0.04),
			Vector2(px * 0.88, px * 0.38),
			Vector2(px * 0.70, px * 0.94),
			Vector2(px * 0.30, px * 0.94),
			Vector2(px * 0.12, px * 0.38),
		])
		var inner := _shrink(pts, 0.80)
		# Facet sáng: nửa trái giữa, tạo cảm giác kim cương.
		var hi := PackedVector2Array([
			Vector2(px * 0.50, px * 0.12),
			Vector2(px * 0.63, px * 0.40),
			Vector2(px * 0.54, px * 0.88),
			Vector2(px * 0.43, px * 0.88),
			Vector2(px * 0.41, px * 0.40),
		])
		var edge := color.darkened(0.55)
		var light := color.lightened(0.55)
		for y in px:
			for x in px:
				var p := _center_of(x, y)
				if not _point_in_polygon(p, pts):
					continue
				if not _point_in_polygon(p, inner):
					img.set_pixel(x, y, edge)
				elif _point_in_polygon(p, hi):
					img.set_pixel(x, y, light)
				else:
					img.set_pixel(x, y, color)
		return img)


# --- Nội bộ -----------------------------------------------------------------

## px truyền TƯỜNG vào thay vì suy ra từ key: trước đây _cached cắt chuỗi
## key lấy phần tử [1], nghĩa là mọi key buộc phải đặt size đúng chỗ đó.
static func _cached(key: String, size: int, build: Callable) -> ImageTexture:
	if _cache.has(key):
		return _cache[key]
	var px: int = maxi(size, 4)
	var tex := ImageTexture.create_from_image(build.call(px))
	if _cache.size() >= CACHE_MAX:
		_cache.clear()
	_cache[key] = tex
	return tex


static func _blank(px: int) -> Image:
	var img := Image.create_empty(px, px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


static func _center_of(x: int, y: int) -> Vector2:
	return Vector2(float(x) + 0.5, float(y) + 0.5)


static func _star_points(px: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var center := Vector2(px * 0.5, px * 0.5)
	var outer: float = px * 0.5 - 1.0
	var inner: float = outer * 0.45
	for i in 10:
		var r: float = outer if i % 2 == 0 else inner
		# Bắt đầu từ -90° để cánh nhọn chỉa lên trên.
		var a: float = -PI * 0.5 + float(i) * PI / 5.0
		pts.push_back(center + Vector2(cos(a), sin(a)) * r)
	return pts


## Tim 2 nhịp: nhịp trên rộng, nhịp dưới hẹp -> giống heart.svg trong repo.
static func _heart_points(px: int) -> PackedVector2Array:
	var w: float = px * 0.86
	var h: float = px * 0.80
	var x0: float = (px - w) * 0.5
	var y0: float = (px - h) * 0.5
	return PackedVector2Array([
		Vector2(x0 + w * 0.25, y0),
		Vector2(x0 + w * 0.50, y0 + h * 0.28),
		Vector2(x0 + w * 0.75, y0),
		Vector2(x0 + w, y0 + h * 0.36),
		Vector2(x0 + w * 0.50, y0 + h),
	])


static func _shrink(pts: PackedVector2Array, factor: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var center := Vector2.ZERO
	for p in pts:
		center += p
	center /= float(maxi(pts.size(), 1))
	for p in pts:
		out.push_back(center + (p - center) * factor)
	return out


static func _point_in_polygon(p: Vector2, pts: PackedVector2Array) -> bool:
	var inside: bool = false
	var n: int = pts.size()
	if n < 3:
		return false
	var j: int = n - 1
	for i in n:
		var a := pts[i]
		var b := pts[j]
		if (a.y > p.y) != (b.y > p.y):
			var t: float = (p.y - a.y) / (b.y - a.y)
			if p.x < a.x + t * (b.x - a.x):
				inside = not inside
		j = i
	return inside