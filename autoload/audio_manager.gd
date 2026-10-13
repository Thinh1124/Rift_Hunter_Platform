extends Node
## Phát nhạc nền (crossfade giữa 2 AudioStreamPlayer) và SFX qua pool 8 voice.

const SFX_DIR: String = "res://assets/audio/sfx/"
const CROSSFADE_TIME: float = 0.5
const SFX_VOICE_COUNT: int = 8
const SILENT_DB: float = -80.0
const AUDIO_EXTENSIONS: PackedStringArray = ["ogg", "wav", "mp3"]
const SFX_FILES: Dictionary[StringName, String] = {
	&"ui_select": "Sounds/Menu/Accept.wav",
	&"ui_back": "Sounds/Menu/Cancel.wav",
	&"ui_move": "Sounds/Menu/Move1.wav",
	&"jump": "Sounds/Jump & Bounce/Jump.wav",
	&"double_jump": "Sounds/Jump & Bounce/Jump2.wav",
	&"land": "Sounds/Jump & Bounce/Bounce2.wav",
	&"player_appear": "Sounds/Magic & Skill/Magic3.wav",
	&"player_hurt": "Sounds/Hit & Impact/Hit1.wav",
	&"player_die": "Sounds/Voice/Voice4.wav",
	&"player_attack": "Sounds/Whoosh & Slash/Launch.wav",
	&"fireball": "Sounds/Elemental/Fireball.wav",
	&"shuriken": "Sounds/Whoosh & Slash/Whoosh.wav",
	&"energy_ball": "Sounds/Magic & Skill/Magic1.wav",
	&"arrow": "Sounds/Whoosh & Slash/Launch.wav",
	&"projectile_hit": "Sounds/Hit & Impact/Hit3.wav",
	&"enemy_hurt": "Sounds/Hit & Impact/Hit2.wav",
	&"enemy_die": "Sounds/Hit & Impact/Impact2.wav",
	&"enemy_detect": "Sounds/Alert/Alert.wav",
	&"enemy_attack": "Sounds/Whoosh & Slash/Whoosh2.wav",
	&"stomp": "Sounds/Jump & Bounce/Bounce.wav",
	&"pickup": "Sounds/Bonus/Coin.wav",
	&"shield": "Sounds/Bonus/PowerUp1.wav",
	&"one_up": "Jingles/LevelUp1.wav",
	&"checkpoint": "Jingles/Secret1.wav",
	&"gate_open": "Sounds/Magic & Skill/Magic4.wav",
	&"gate_close": "Sounds/Magic & Skill/Magic2.wav",
	&"boss_dash": "Sounds/Whoosh & Slash/Whoosh2.wav",
	&"boss_slam": "Sounds/Elemental/Explosion4.wav",
	&"bomb_fuse": "Sounds/Alert/Alert2.wav",
	&"bomb_explode": "Sounds/Elemental/Explosion.wav",
	&"boss_shoot": "Sounds/Elemental/Fireball2.wav",
	&"boss_summon": "Sounds/Magic & Skill/Magic5.wav",
	&"boss_phase": "Sounds/Alert/Alert5.wav",
	&"boss_defeated": "Jingles/Success3.wav",
	&"level_completed": "Jingles/Success1.wav",
	&"game_over": "Jingles/GameOver.wav",
	&"platform_shake": "Sounds/Hit & Impact/Impact.wav",
	&"platform_fall": "Sounds/Whoosh & Slash/Whoosh.wav",
	&"platform_respawn": "Sounds/Magic & Skill/Magic2.wav",
	&"npc_dialogue": "Sounds/Voice/Voice1.wav",
}
const LEVEL_MUSIC: Array[String] = [
	"5 - Peaceful.ogg", "1 - Adventure Begin.ogg", "12 - Temple.ogg",
	"2 - The Cave.ogg", "19 - Ascension.ogg", "37 - Dark Forest.ogg", "17 - Fight.ogg",
]
## Thời gian hạ/ngẩng nhạc khi pause (giây).
const DUCK_FADE_TIME: float = 0.15
## Nhạc còn bao nhiêu phần khi pause.
const PAUSE_DUCK: float = 0.5

var _sfx: Dictionary[StringName, AudioStream] = {}
var _sfx_voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_active: AudioStreamPlayer
var _music_tween: Tween

var _music_volume: float = 0.8
var _sfx_volume: float = 1.0
## Nhân thêm vào âm lượng nhạc. 0.5 = hạ nhạc còn một nửa khi game pause.
var _music_duck: float = 1.0
var _music_cache: Dictionary[String, AudioStream] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_a = _make_music_player(&"MusicA")
	_music_b = _make_music_player(&"MusicB")
	_music_active = _music_a
	for i in SFX_VOICE_COUNT:
		var voice := AudioStreamPlayer.new()
		voice.name = "Sfx%d" % i
		voice.bus = &"Master"
		add_child(voice)
		_sfx_voices.append(voice)
	_scan_sfx()
	EventBus.level_completed.connect(_on_level_completed)
	EventBus.game_over.connect(_on_game_over)
	EventBus.boss_defeated.connect(func() -> void: play_sfx(&"boss_defeated"))


## Nạp volume đã lưu. Gọi từ GameManager._ready vì AudioManager đứng TRƯỚC
## SaveManager trong autoload -> lúc _ready của AudioManager, save chưa nạp.
func apply_saved_volumes() -> void:
	if "music_vol" in SaveManager:
		_music_volume = clampf(float(SaveManager.get(&"music_vol")), 0.0, 1.0)
	if "sfx_vol" in SaveManager:
		_sfx_volume = clampf(float(SaveManager.get(&"sfx_vol")), 0.0, 1.0)


func _make_music_player(node_name: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.bus = &"Master"
	player.volume_db = SILENT_DB
	add_child(player)
	return player


## Nạp mọi file trong res://assets/audio/sfx/ thành dict name -> stream.
func _scan_sfx() -> void:
	_sfx.clear()
	var dir := DirAccess.open(SFX_DIR)
	if dir != null:
		for file_name in dir.get_files():
			if not AUDIO_EXTENSIONS.has(file_name.get_extension().to_lower()):
				continue
			var stream := ResourceLoader.load(SFX_DIR + file_name) as AudioStream
			if stream != null:
				_sfx[StringName(file_name.get_basename())] = stream
	for key: StringName in SFX_FILES:
		var stream := load("res://assets/audio/" + SFX_FILES[key]) as AudioStream
		if stream != null:
			_sfx[key] = stream


func music_for_level(number: int) -> AudioStream:
	return music_from_file(LEVEL_MUSIC[clampi(number, 0, LEVEL_MUSIC.size() - 1)])


func _on_level_completed() -> void:
	play_sfx(&"level_completed")
	if GameManager.current_level >= GameManager.BOSS_LEVEL:
		play_music(music_from_file("8 - End Theme.ogg"))


func _on_game_over() -> void:
	stop_music()
	play_sfx(&"game_over")


func music_from_file(file_name: String) -> AudioStream:
	if _music_cache.has(file_name):
		return _music_cache[file_name]
	var stream := load("res://assets/audio/Musics/" + file_name) as AudioStream
	if stream != null:
		stream = stream.duplicate() as AudioStream
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		_music_cache[file_name] = stream
	return stream


# --- Nhạc ------------------------------------------------------------------

func play_music(stream: AudioStream) -> void:
	if stream == null:
		stop_music()
		return
	if _music_active.stream == stream and _music_active.playing:
		return
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	var outgoing: AudioStreamPlayer = _music_active
	var incoming: AudioStreamPlayer = _music_b if outgoing == _music_a else _music_a
	incoming.stream = stream
	incoming.volume_db = SILENT_DB
	incoming.play()
	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_property(outgoing, "volume_db", SILENT_DB, CROSSFADE_TIME)
	_music_tween.tween_property(incoming, "volume_db", _to_db(_music_volume * _music_duck), CROSSFADE_TIME)
	_music_tween.chain().tween_callback(outgoing.stop)
	_music_active = incoming


func stop_music() -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_a.stop()
	_music_b.stop()
	_music_a.stream = null
	_music_b.stream = null


func _exit_tree() -> void:
	stop_music()
	stop_sfx()
	_sfx.clear()
	_music_cache.clear()


func stop_sfx() -> void:
	for voice in _sfx_voices:
		voice.stop()
		voice.stream = null


func set_music_volume(v: float) -> void:
	_music_volume = clampf(v, 0.0, 1.0)
	if _music_active != null and _music_active.playing:
		_music_active.volume_db = _to_db(_music_volume * _music_duck)


## Âm lượng nhạc đang dùng (0-1) - Settings đọc để hiện lại giá trị hiện tại.
func get_music_volume() -> float:
	return _music_volume


## Hạ nhạc còn factor (0.5 = còn nửa) khi pause. Chỉ đổi nhạc, SFX giữ nguyên.
func set_music_duck(factor: float) -> void:
	_music_duck = clampf(factor, 0.0, 1.0)
	if _music_active != null and _music_active.playing:
		# Tween ngắn để không bị giật khi bật/tắt pause.
		var tween := create_tween()
		tween.tween_property(_music_active, "volume_db", _to_db(_music_volume * _music_duck), DUCK_FADE_TIME)


func unduck_music() -> void:
	set_music_duck(1.0)


# --- SFX -------------------------------------------------------------------

func play_sfx(sfx_name: StringName) -> void:
	var stream: AudioStream = _sfx.get(sfx_name, null)
	if stream == null:
		return
	var voice: AudioStreamPlayer = _sfx_voices[_next_voice]
	_next_voice = (_next_voice + 1) % _sfx_voices.size()
	voice.stream = stream
	voice.volume_db = _to_db(_sfx_volume)
	voice.play()


func set_sfx_volume(v: float) -> void:
	_sfx_volume = clampf(v, 0.0, 1.0)


## Âm lượng SFX đang dùng (0-1) - Settings đọc để hiện lại giá trị hiện tại.
func get_sfx_volume() -> float:
	return _sfx_volume


func has_sfx(sfx_name: StringName) -> bool:
	return _sfx.has(sfx_name)


func _to_db(linear: float) -> float:
	return linear_to_db(maxf(linear, 0.0001))
