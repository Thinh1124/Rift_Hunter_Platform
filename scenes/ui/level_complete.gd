extends CanvasLayer
## Màn HOÀN THÀNH ải: hiện khi EventBus.level_completed phát.
##
## Sao hiện lần lượt mỗi star_interval giây, mỗi sao một tiếng SFX.
## Thuật toán sao lấy từ GameManager.last_stars (HP đầy=3, HP>=2=2, còn lại 1),
## đã được GameManager._on_level_completed() tính và lưu sẵn.
##
## LƯU Ý (khác spec một chỗ, có chủ ý): GameManager KHÔNG ghi save ở đây. Nó đã
## set_stars + submit_score + unlock(level+1) ngay khi nhận level_completed, và
## vì GameManager là autoload (nối signal trước node trong scene) nên chạy TRƯỚC.
## Nếu ghi lần hai ở đây thì thành viết trùng; và nếu LevelComplete vô tình
## không có trong scene thì sao sẽ không được lưu.

## Nhịp hiện từng sao (giây).
@export_range(0.05, 1.0, 0.05) var star_interval: float = 0.3

@onready var _title_label: Label = %TitleLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _stars_row: HBoxContainer = %StarsRow
@onready var _next_button: UIButton = %NextButton
@onready var _restart_button: UIButton = %RestartButton
@onready var _quit_button: UIButton = %QuitButton
@onready var _victory_label: Label = %VictoryLabel

var _reveal_tween: Tween
var _completed_level: int = 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	add_to_group(&"level_complete")
	visible = false

	_next_button.pressed.connect(_on_next_pressed)
	_restart_button.pressed.connect(_on_restart_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

	EventBus.level_completed.connect(_on_level_completed)


func _on_level_completed() -> void:
	if visible:
		return
	_completed_level = GameManager.current_level
	visible = true

	AudioManager.unduck_music()
	_score_label.text = "Score: %06d" % GameManager.score

	var stars: int = _stars_earned()
	if _completed_level >= GameManager.BOSS_LEVEL:
		# Xong ải boss -> màn thắng game: chỉ còn lời chúc + nút "Về menu".
		# KHÔNG để lại "Chơi lại": người chơi đã thắng game, mời họ chơi lại
		# ải boss là hành động không có trong spec và gây rối tiến độ.
		_title_label.text = "YOU WIN!"
		_title_label.add_theme_color_override(&"font_color", Color(1.0, 0.84, 0.25))
		_victory_label.visible = true
		_next_button.hide()
		_restart_button.hide()
	else:
		_title_label.text = "LEVEL CLEAR!"
		_victory_label.visible = false
		_next_button.show()
		_restart_button.show()
		_restart_button.text = "RETRY"

	_reveal_stars(stars)


## Đọc sao đã lưu; nếu GameManager chưa kịp chạy (thứ tự signal) thì tự tính lại.
func _stars_earned() -> int:
	var stars: int = GameManager.last_stars
	if stars > 0:
		return clampi(stars, 1, SaveManager.MAX_STARS)
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player != null and player.health != null:
		return clampi(GameManager.compute_stars(player.health.current, player.health.max_health), 1, SaveManager.MAX_STARS)
	return 1


## Dựng sẵn SaveManager.MAX_STARS ô sao (rỗng), rồi bật sáng từng cái cách nhau
## star_interval giây, mỗi cái một tiếng SFX.
##
## Tween TUẦN TỰ (không set_parallel): nếu trộn parallel/sequential thì sao thứ 2
## sẽ rơi vào cùng step với interval của sao thứ 1 và hiện cùng lúc.
func _reveal_stars(earned: int) -> void:
	for child in _stars_row.get_children():
		_stars_row.remove_child(child)
		child.queue_free()

	var slots: Array[TextureRect] = []
	for i in SaveManager.MAX_STARS:
		var icon := TextureRect.new()
		icon.name = "Star%d" % i
		icon.texture = PixelIcons.star(20, false)
		icon.custom_minimum_size = Vector2(20, 20)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.modulate = Color(0.3, 0.32, 0.4, 1)
		_stars_row.add_child(icon)
		slots.append(icon)

	_kill_reveal()
	_reveal_tween = create_tween()
	for i in earned:
		# Sao đầu hiện ngay, sao sau mỗi nhịp.
		if i > 0:
			_reveal_tween.tween_interval(star_interval)
		_reveal_tween.tween_callback(_light_star.bind(slots[i]))


## Bật 1 ô sao: đổi texture, trả màu, phóng to nhẹ cho có nhịp, kêu tiếng.
func _light_star(slot: TextureRect) -> void:
	if slot == null or not is_instance_valid(slot):
		return
	slot.texture = PixelIcons.star(20, true)
	slot.modulate = Color(1, 1, 1, 1)
	slot.scale = Vector2(1.6, 1.6)
	var pop := create_tween()
	pop.tween_property(slot, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	AudioManager.play_sfx(&"pickup")


func _on_next_pressed() -> void:
	AudioManager.play_sfx(&"ui_select")
	_kill_reveal()
	if _completed_level >= GameManager.LEVEL_COUNT:
		_go_menu()
		return
	GameManager.go_to_level(_completed_level + 1)


func _on_restart_pressed() -> void:
	AudioManager.play_sfx(&"ui_select")
	_kill_reveal()
	GameManager.restart_level()


func _on_quit_pressed() -> void:
	AudioManager.play_sfx(&"ui_back")
	_go_menu()


func _kill_reveal() -> void:
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	_reveal_tween = null


func _go_menu() -> void:
	GameManager.go_to_menu()