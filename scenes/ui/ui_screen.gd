class_name UIScreen
extends Control
## Gốc cho mọi màn hình UI (menu, level select...).
##
## - Ép Control full-rect: scene được add dưới Node2D/CanvasItem nào cũng phủ
##   hết viewport 640x360, không bị rộng 0.
## - Theme lấy từ Project Settings > GUI > Theme > Custom
##   (res://addons/pixel_ui/themes/wood.tres) nên không cần set theme thủ công từng scene.
##
## Muốn UI tự tránh safe area: bọc con trong SafeAreaMargin, hoặc dùng
## SafeArea.apply_offsets() cho Control không nằm trong container.
##
## HIỆN KHÔNG scene nào dùng script này (Các màn đã set anchors_preset=15 thủ công
## trong .tscn). Giữ lại làm base class cho màn UI mới; xoá nếu không dùng.


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)