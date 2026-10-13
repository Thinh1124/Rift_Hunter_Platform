class_name NPC
extends Node2D
## NPC hướng dẫn: player bước vào TalkZone thì bong bóng thoại hiện lên, chạm để
## đọc tiếp, rời vùng thì đóng. Không chạy trốn, không đồng hành, không nhánh hội
## thoại.
##
## Câu thoại đổi theo trạng thái, ưu tiên after_gates > hint > default.

const DEFAULT_IDLE_TEXTURE: String = "res://assets/Main Characters/Mask Dude/Idle (32x32).png"
const FRAME_SIZE: int = 32
const ANIM_IDLE: StringName = &"idle"

## Khóa trong res://data/dialogues.json.
@export var dialogue_id: String = "npc_guide"
## Chết >= số lần này trong ải thì dùng nhóm "hint".
@export_range(0, 99, 1) var hint_after_deaths: int = 3
@export var face_player: bool = true
@export var sprite_frames: SpriteFrames
@export var idle_texture: Texture2D
@export var exclaim_texture: Texture2D

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var talk_zone: Area2D = $TalkZone
@onready var exclaim_icon: Sprite2D = $ExclaimIcon
@onready var bubble: DialogueBubble = $DialogueBubble

var _player_inside: bool = false
var _open_key: String = ""


func _ready() -> void:
	add_to_group(&"npc")
	sprite.sprite_frames = sprite_frames if sprite_frames != null else _build_idle_frames()
	if sprite.sprite_frames.has_animation(ANIM_IDLE):
		sprite.play(ANIM_IDLE)
	if exclaim_texture != null:
		exclaim_icon.texture = exclaim_texture
	elif exclaim_icon.texture == null:
		exclaim_icon.texture = _make_exclaim_texture()
	exclaim_icon.visible = false
	talk_zone.body_entered.connect(_on_body_entered)
	talk_zone.body_exited.connect(_on_body_exited)
	bubble.closed.connect(_on_bubble_closed)


## Nhóm thoại hiện tại theo trạng thái ván chơi.
func current_key() -> String:
	# Ải không có cổng nào thì remaining == 0 không có nghĩa là "đã xong".
	if GameManager.total_gates > 0 and GameManager.remaining_gates <= 0:
		return "after_gates"
	if GameManager.deaths_this_level >= hint_after_deaths:
		return "hint"
	return "default"


func current_lines() -> PackedStringArray:
	return DialogueDB.lines(dialogue_id, current_key())


func is_talking() -> bool:
	return bubble.is_open()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"player"):
		return
	_player_inside = true
	if face_player:
		_face_towards(body as Node2D)
	_open_dialogue()


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group(&"player"):
		return
	_player_inside = false
	bubble.close()


func _on_bubble_closed() -> void:
	_open_key = ""
	exclaim_icon.visible = _player_inside


## Chỉ mở khi thực sự vào vùng, và không mở lại câu đang hiện -> không lặp.
func _open_dialogue() -> void:
	var key := current_key()
	if bubble.is_open() and _open_key == key:
		return
	_open_key = key
	exclaim_icon.visible = false
	bubble.open(DialogueDB.lines(dialogue_id, key))
	AudioManager.play_sfx(&"npc_dialogue")


func _face_towards(target: Node2D) -> void:
	if target == null or sprite == null:
		return
	sprite.flip_h = target.global_position.x < global_position.x


# --- Hình dựng sẵn -------------------------------------------------------

## Dựng animation "idle" từ dải sprite ngang (mỗi khung FRAME_SIZE px).
func _build_idle_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(ANIM_IDLE)
	frames.set_animation_speed(ANIM_IDLE, 6.0)
	frames.set_animation_loop(ANIM_IDLE, true)
	var texture: Texture2D = idle_texture
	if texture == null and ResourceLoader.exists(DEFAULT_IDLE_TEXTURE):
		texture = load(DEFAULT_IDLE_TEXTURE) as Texture2D
	if texture == null:
		push_warning("NPC: không có texture cho animation idle.")
		return frames
	var total := maxi(texture.get_width() / FRAME_SIZE, 1)
	for index in total:
		var frame := AtlasTexture.new()
		frame.atlas = texture
		frame.region = Rect2(index * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)
		frames.add_frame(ANIM_IDLE, frame)
	return frames


## Dấu "!" vàng 8x14 vẽ tay, dùng làm ExclaimIcon mặc định.
func _make_exclaim_texture() -> ImageTexture:
	var width := 8
	var height := 14
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var ink := Color(1.0, 0.85, 0.2, 1.0)
	var outline := Color(0.15, 0.1, 0.05, 1.0)
	for y in range(1, height - 4):
		image.set_pixel(3, y, ink)
		image.set_pixel(4, y, ink)
		image.set_pixel(2, y, outline)
		image.set_pixel(5, y, outline)
	image.set_pixel(2, 10, outline)
	image.set_pixel(5, 10, outline)
	image.set_pixel(3, 11, outline)
	image.set_pixel(4, 11, outline)
	image.set_pixel(3, height - 2, ink)
	image.set_pixel(4, height - 2, ink)
	image.set_pixel(2, height - 2, outline)
	image.set_pixel(5, height - 2, outline)
	return ImageTexture.create_from_image(image)
