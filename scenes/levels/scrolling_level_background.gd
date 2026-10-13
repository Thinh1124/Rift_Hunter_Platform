class_name ScrollingLevelBackground
extends CanvasLayer
## Screen-space tiled background; scrolls horizontally like MainMenu.

@export var background_texture: Texture2D
@export_range(0.0, 200.0, 1.0) var speed: float = 10.0
@export var reverse: bool = false

@onready var background: TextureRect = %Background

var _offset: float = 0.0
var _material: ShaderMaterial


func _ready() -> void:
	background.texture = background_texture
	_material = background.material as ShaderMaterial
	background.resized.connect(_update_size)
	_update_size()


func _process(delta: float) -> void:
	if background.texture == null:
		return
	var width: float = maxf(float(background.texture.get_width()), 1.0)
	_offset = fposmod(_offset + speed * delta * (-1.0 if reverse else 1.0), width)
	_material.set_shader_parameter(&"scroll_offset", roundf(_offset))


func _update_size() -> void:
	_material.set_shader_parameter(&"canvas_size", background.size)
