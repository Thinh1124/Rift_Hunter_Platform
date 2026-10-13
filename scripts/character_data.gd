class_name CharacterData
extends Resource
## Dữ liệu MỘT model nhân vật. Thêm nhân vật mới = tạo 1 file .tres trong
## res://data/characters/, KHÔNG sửa Player.
##
## SpriteFrames bắt buộc có: idle, run, jump, fall, hit, dead.
## Thiếu anim nào -> tự dựng anim đó từ 'idle' + in cảnh báo (không crash).

## 6 anim Player/state machine luôn gọi. Thiếu -> fallback về "idle".
const REQUIRED_ANIMATIONS: Array[StringName] = [
	&"idle", &"run", &"jump", &"fall", &"hit", &"dead",
]
const FALLBACK_ANIMATION: StringName = &"idle"

@export_group("Identity")
@export var id: StringName = &""
@export var display_name: String = ""
## Ảnh nhỏ cho menu chọn nhân vật (AtlasTexture 1 frame là đẹp nhất).
@export var icon: Texture2D

@export_group("Look")
@export var sprite_frames: SpriteFrames
## Bề rộng, cao thân va chạm (px). (12, 20) = nhân vật 32px, chân đặt ở y=0.
@export var collision_size: Vector2 = Vector2(12.0, 20.0)
## Lệch vị trí Sprite so với gốc thân (thường (0, -sprite_height/2)).
@export var sprite_offset: Vector2 = Vector2.ZERO

@export_group("Stats")
## 1.0 = bằng tốc độ gốc của Player.
@export_range(0.3, 3.0, 0.01) var speed_mult: float = 1.0
## > 1 nhảy cao hơn, < 1 nhảy thấp hơn.
@export_range(0.3, 3.0, 0.01) var jump_mult: float = 1.0
## Cộng thẳng vào max_hp của Player.
@export_range(-9, 9, 1) var max_hp_bonus: int = 0
## 1.0 = cooldown gốc (0.4s). < 1 bắn nhanh hơn.
@export_range(0.25, 4.0, 0.05) var attack_cooldown_mult: float = 1.0
## Dòng mô tả năng kỹ đặc, hiện ở CharacterSelect. Rỗng -> ẩn luôn dòng này.
@export_multiline var ability: String = ""
## Mã năng kỹ đặc cho Player đọc bằng máy (không parse chuỗi `ability`).
## Hiện có: &"" (không có) | &"double_jump" (nhảy 2 lần trên không).
@export var ability_id: StringName = &""

@export_group("Unlock")
## null = dùng Projectile mặc định gán trong Player.tscn.
@export var projectile_scene: PackedScene
## true = mở khoá ngay từ đầu (nhân vật mặc định).
@export var unlocked_by_default: bool = true
## Mở khoá sau khi vượt qua màn số N. 0 = không cần vượt màn nào.
## `unlocked_by_default = true` thì `unlock_level` bị bỏ qua.
@export_range(0, 99, 1) var unlock_level: int = 0


## Màn phải vượt qua để mở khoá nhân vật này. 0 = đã mở sẵn.
func required_level() -> int:
	if unlocked_by_default:
		return 0
	return maxi(unlock_level, 1)


func has_animation(anim: StringName) -> bool:
	return sprite_frames != null and sprite_frames.has_animation(anim)


## Danh sách anim bắt buộc đang thiếu.
func missing_animations() -> Array[StringName]:
	var out: Array[StringName] = []
	for anim: StringName in REQUIRED_ANIMATIONS:
		if not has_animation(anim):
			out.append(anim)
	return out


## Tên anim an toàn để play: có thì trả về, thiếu thì trả về "idle".
func animation_or_idle(anim: StringName) -> StringName:
	if has_animation(anim):
		return anim
	if has_animation(FALLBACK_ANIMATION):
		return FALLBACK_ANIMATION
	return &""


## SpriteFrames đã được vá: mọi anim bắt buộc đều tồn tại (thiếu -> copy từ idle).
## Trả về null khi chưa gán SpriteFrames.
func validated_sprite_frames() -> SpriteFrames:
	if sprite_frames == null:
		push_warning("CharacterData '%s' (id=%s): chưa gán SpriteFrames." % [display_name, id])
		return null
	var missing: Array[StringName] = missing_animations()
	if missing.is_empty():
		return sprite_frames
	var names: PackedStringArray = PackedStringArray()
	for anim: StringName in missing:
		names.append(String(anim))
	if not has_animation(FALLBACK_ANIMATION):
		push_error("CharacterData '%s': thiếu %s và cả 'idle' để fallback." % [display_name, String(", ").join(names)])
		return sprite_frames
	push_warning("CharacterData '%s': thiếu anim %s -> dùng 'idle' thay thế." % [display_name, String(", ").join(names)])
	var patched := sprite_frames.duplicate(true) as SpriteFrames
	for anim: StringName in missing:
		patched.add_animation(anim)
		patched.set_animation_speed(anim, sprite_frames.get_animation_speed(FALLBACK_ANIMATION))
		patched.set_animation_loop(anim, sprite_frames.get_animation_loop(FALLBACK_ANIMATION))
		for frame: int in sprite_frames.get_frame_count(FALLBACK_ANIMATION):
			patched.add_frame(anim, sprite_frames.get_frame_texture(FALLBACK_ANIMATION, frame))
	return patched


## Dòng chữ tóm tắt cho UI.
## XUỐNG 2 DÒNG: thẻ nhân vật rộng 150px, font NinjaAdventure rộng hơn font cũ -
## gộp 1 dòng sẽ tràn ra ngoài thẻ.
func stats_line() -> String:
	return "SPD %.2f  JMP %.2f\nHP +%d  CD %.2f" % [
		speed_mult, jump_mult, max_hp_bonus, attack_cooldown_mult,
	]


## Số tim cho chỉ số HP: gốc 3, cộng thẳng max_hp_bonus.
func hp_stars() -> int:
	return clampi(3 + max_hp_bonus, 1, 5)


## Số kiếm cho chỉ số ATK: cooldown càng nhỏ (đánh càng nhanh) càng nhiều kiếm.
## Gốc 1.0 -> 3 kiếm. Khoảng hiển thị 1..5.
func atk_stars() -> int:
	var cd: float = maxf(attack_cooldown_mult, 0.01)
	return clampi(int(3.0 / cd), 1, 5)