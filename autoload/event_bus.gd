extends Node
## Bus tín hiệu toàn cục. Mọi scene giao tiếp qua đây, không dùng đường dẫn node cứng.

signal score_changed(score: int)
signal lives_changed(lives: int)
signal player_hp_changed(cur: int, max: int)
signal gates_changed(remaining: int, total: int)
signal gate_closed(id: StringName)
signal level_completed
signal player_died
signal game_over
signal boss_hp_changed(cur: int, max: int)
signal boss_defeated
signal checkpoint_reached(pos: Vector2)
## Số mảnh Rift đã thu / số cần thu trong màn. Đủ -> cổng cuối màn mở cánh.
signal shards_changed(collected: int, required: int)
signal request_shake(strength: float, duration: float)
