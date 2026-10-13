extends Node
## Phát nhạc nền (crossfade giữa 2 AudioStreamPlayer) và SFX qua pool 8 voice.

const SFX_DIR: String = "res://assets/audio/sfx/"
const CROSSFADE_TIME: float = 0.5
const SFX_VOICE_COUNT: int = 8
const SILENT_DB: float = -80.0
const AUDIO_EXTENSIONS: PackedStringArray = ["ogg", "wav", "mp3"]

var _sfx: Dictionary[StringName, AudioStream] = {}
var _sfx_voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_active: AudioStreamPlayer
var _music_tween: Tween

var _music_volume: float = 0.8
var _sfx_volume: float = 1.0


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
	if dir == null:
		return
	for file_name in dir.get_files():
		if not AUDIO_EXTENSIONS.has(file_name.get_extension().to_lower()):
			continue
		var stream: Resource = ResourceLoader.load(SFX_DIR + file_name)
		if stream is AudioStream:
			_sfx[StringName(file_name.get_basename())] = stream


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
	_music_tween.tween_property(incoming, "volume_db", _to_db(_music_volume), CROSSFADE_TIME)
	_music_tween.chain().tween_callback(outgoing.stop)
	_music_active = incoming


func stop_music() -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_a.stop()
	_music_b.stop()
	_music_active.stream = null


func set_music_volume(v: float) -> void:
	_music_volume = clampf(v, 0.0, 1.0)
	if _music_active != null and _music_active.playing:
		_music_active.volume_db = _to_db(_music_volume)


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


func has_sfx(sfx_name: StringName) -> bool:
	return _sfx.has(sfx_name)


func _to_db(linear: float) -> float:
	return linear_to_db(maxf(linear, 0.0001))