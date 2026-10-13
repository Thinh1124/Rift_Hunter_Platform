extends PlayerState
## Chết: nằm chết `death_duration` giây cho animation, rồi:
##   1. GameManager.lose_life()  -> trừ 1 mạng (lives == 0 thì GameManager tự
##      phát game_over, không respawn)
##   2. còn mạng -> player.respawn(): về GameManager.last_checkpoint (hoặc
##      PlayerSpawn), HP đầy, i-frame respawn_iframe_time.

var _timer: float = 0.0
var _resolved: bool = false


func enter(_msg: Dictionary = {}) -> void:
	player.set_control_enabled(false)
	player.velocity = Vector2.ZERO
	play_animation(&"dead")
	_timer = player.death_duration
	_resolved = false
	AudioManager.play_sfx(&"player_die")


func physics_update(delta: float) -> void:
	if _resolved:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_resolved = true
	GameManager.lose_life()
	if GameManager.lives > 0:
		player.respawn()


func exit() -> void:
	player.set_control_enabled(true)