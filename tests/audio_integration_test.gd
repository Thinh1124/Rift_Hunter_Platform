extends Node

var failures: int = 0

func _ready() -> void:
	call_deferred(&"_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	var music_volume: float = AudioManager.get_music_volume()
	var sfx_volume: float = AudioManager.get_sfx_volume()
	for key: StringName in AudioManager.SFX_FILES:
		_check(AudioManager.has_sfx(key), "Missing mapped SFX: " + String(key))
		var stream: AudioStream = AudioManager._sfx.get(key)
		_check(stream != null and stream.get_length() > 0, "Empty SFX: " + String(key))
	for number in range(7):
		var stream := AudioManager.music_for_level(number) as AudioStreamOggVorbis
		_check(stream != null and stream.loop and stream.get_length() > 0, "Level %d must have looping music" % number)
		_check(stream == AudioManager.music_for_level(number), "Music must reuse its cached stream")
	AudioManager.set_sfx_volume(0.25)
	var voice_index: int = AudioManager._next_voice
	AudioManager.play_sfx(&"fireball")
	var voice: AudioStreamPlayer = AudioManager._sfx_voices[voice_index]
	_check(voice.playing and voice.stream == AudioManager._sfx[&"fireball"], "SFX must actually start playing")
	_check(is_equal_approx(voice.volume_db, linear_to_db(0.25)), "SFX must use the settings volume")
	for i in 24:
		AudioManager.play_sfx(&"pickup")
	_check(AudioManager._sfx_voices.size() == 8, "SFX playback must reuse the fixed voice pool")
	voice_index = AudioManager._next_voice
	AudioManager.set_sfx_volume(0)
	AudioManager.play_sfx(&"ui_select")
	_check(AudioManager._sfx_voices[voice_index].volume_db <= -80, "Muted SFX must stay silent")

	AudioManager.set_music_volume(0.5)
	var first: AudioStream = AudioManager.music_for_level(1)
	AudioManager.play_music(first)
	await get_tree().create_timer(0.6).timeout
	_check(AudioManager._music_active.playing and AudioManager._music_active.stream == first, "Level music must start playing")
	var active: AudioStreamPlayer = AudioManager._music_active
	AudioManager.play_music(first)
	_check(AudioManager._music_active == active, "The same music must not restart")
	AudioManager.set_music_duck(0.5)
	await get_tree().create_timer(0.2).timeout
	_check(is_equal_approx(active.volume_db, linear_to_db(0.25)), "Pause must duck music")
	AudioManager.unduck_music()
	await get_tree().create_timer(0.2).timeout
	_check(is_equal_approx(active.volume_db, linear_to_db(0.5)), "Resume must restore music volume")
	AudioManager.play_music(AudioManager.music_for_level(6))
	await get_tree().create_timer(0.6).timeout
	_check(not active.playing and AudioManager._music_active.playing, "Crossfade must retire the old music voice")
	AudioManager.set_music_volume(0)
	_check(AudioManager._music_active.volume_db <= -80, "Muted music must stay silent")
	AudioManager._on_game_over()
	_check(not AudioManager._music_a.playing and not AudioManager._music_b.playing, "Game over must stop level music")
	AudioManager.set_music_volume(music_volume)
	AudioManager.set_sfx_volume(sfx_volume)
	for sfx_voice: AudioStreamPlayer in AudioManager._sfx_voices:
		sfx_voice.stop()
		sfx_voice.stream = null
	await get_tree().create_timer(0.1).timeout
	print("Audio integration checks complete: %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)
