extends CanvasLayer
## Màn GAME OVER: hiện khi EventBus.game_over phát (hết mạng).
##
## Hiệu ứng chậm thời gian: Engine.time_scale = slow_scale trong slow_duration
## giây THẬT rồi trả lại 1.0 -> thấy được cú va chạm chết trước khi dừng.
##
## process_mode = ALWAYS để nút bấm được, nhưng scene KHÔNG pause: người chơi
## vẫn thấy thế giới đứng yên phía sau.

## Tốc độ thời gian khi chậm.
@export_range(0.05, 1.0, 0.05) var slow_scale: float = 0.3
## Giữ chậm bao lâu (giây thật).
@export_range(0.0, 3.0, 0.05) var slow_duration: float = 0.5

@onready var _score_label: Label = %ScoreLabel
@onready var _restart_button: UIButton = %RestartButton
@onready var _quit_button: UIButton = %QuitButton

var _slow_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	add_to_group(&"game_over")
	visible = false

	_restart_button.pressed.connect(_on_restart_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

	EventBus.game_over.connect(_on_game_over)


## Scene bị đổi giữa lúc đang slow -> phải trả time_scale, nếu không cả game
## chạy chậm vĩnh viễn.
func _exit_tree() -> void:
	_restore_time()


func _on_game_over() -> void:
	if visible:
		return
	visible = true
	_score_label.text = "Score: %06d" % GameManager.score

	AudioManager.unduck_music()
	_start_slow_mo()


func _start_slow_mo() -> void:
	_restore_time()
	Engine.time_scale = slow_scale
	# set_ignore_time_scale: 0.5s phải là 0.5s THẬT, không bị nhân với 0.3.
	_slow_tween = create_tween().set_ignore_time_scale(true)
	_slow_tween.tween_interval(slow_duration)
	_slow_tween.tween_callback(_restore_time)


func _restore_time() -> void:
	if _slow_tween != null and _slow_tween.is_valid():
		_slow_tween.kill()
	_slow_tween = null
	Engine.time_scale = 1.0


func _on_restart_pressed() -> void:
	AudioManager.play_sfx(&"ui_select")
	_restore_time()
	# reset_run trả điểm/mạng/trái cây về đầu, rồi vào lại chính ải này.
	GameManager.reset_run()
	GameManager.restart_level()


func _on_quit_pressed() -> void:
	AudioManager.play_sfx(&"ui_back")
	_restore_time()
	GameManager.go_to_menu()