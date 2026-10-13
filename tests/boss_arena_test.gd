extends Node2D
## Playable arena. The automated checks live in BossTest.tscn.

func _ready() -> void:
	EventBus.boss_hp_changed.connect(_on_hp)
	EventBus.boss_defeated.connect(_on_defeated)
	_on_hp($Boss.health.current, $Boss.health.max_health)
	queue_redraw()


func _on_hp(cur: int, maximum: int) -> void:
	$HUD/Status.text = "Boss %d/%d | Phase %d" % [cur, maximum, 2 if cur <= maximum / 2 else 1]


func _on_defeated() -> void:
	$HUD/Status.text = "Boss defeated! +2000"


func _draw() -> void:
	draw_rect(Rect2(-340, -140, 680, 380), Color(0.055, 0.045, 0.1))
	draw_rect(Rect2(-320, 200, 640, 40), Color(0.25, 0.15, 0.32))
	draw_line(Vector2(-320, 200), Vector2(320, 200), Color(0.9, 0.3, 0.7), 3)
	draw_rect(Rect2(-340, -80, 20, 320), Color(0.35, 0.2, 0.4))
	draw_rect(Rect2(320, -80, 20, 320), Color(0.35, 0.2, 0.4))
