extends Control
## Thread-load MainMenu while showing a synchronized four-character run.

@export var main_menu_scene: String = "res://scenes/ui/MainMenu.tscn"
@export_range(0.1, 10.0, 0.1) var minimum_loading_time: float = 1.5
@export_range(0.5, 4.0, 0.1) var run_cycles_per_second: float = 2.0
@export_range(16.0, 48.0, 1.0) var runner_size: float = 32.0

@onready var _bar: ProgressBar = %LoadBar
@onready var _track: Control = %RunnerTrack
@onready var _group: Node2D = %Runners
@onready var _status: Label = %LoadingStatus
@onready var _runners: Array[AnimatedSprite2D] = [%NinjaFrog, %PinkMan, %VirtualGuy, %MaskDude]

var _menu_scene: PackedScene
var _elapsed: float = 0.0
var _shown_progress: float = 0.0
var _done: bool = false
var _failed: bool = false


func _ready() -> void:
	_bar.value = 0.0
	SaveManager.load_data()
	for runner: AnimatedSprite2D in _runners:
		runner.play(&"run")
		runner.speed_scale = 0.0
		var texture: Texture2D = runner.sprite_frames.get_frame_texture(&"run", 0)
		runner.scale = Vector2.ONE * runner_size / maxf(float(texture.get_height()), 1.0)
	_track.resized.connect(_update_layout)
	_update_layout()
	if not ResourceLoader.exists(main_menu_scene):
		_fail_loading()
		return
	var error: Error = ResourceLoader.load_threaded_request(main_menu_scene, "PackedScene")
	if error != OK:
		_fail_loading()


func _process(delta: float) -> void:
	if _done or _failed:
		return
	_elapsed += delta
	var progress: Array = []
	var loading_status: int = ResourceLoader.THREAD_LOAD_LOADED if _menu_scene != null else ResourceLoader.load_threaded_get_status(main_menu_scene, progress)
	var actual_progress: float = float(progress[0]) if not progress.is_empty() else 0.0
	if loading_status == ResourceLoader.THREAD_LOAD_LOADED:
		if _menu_scene == null:
			_menu_scene = ResourceLoader.load_threaded_get(main_menu_scene) as PackedScene
			if _menu_scene == null:
				_fail_loading()
				return
		actual_progress = 1.0
	elif loading_status == ResourceLoader.THREAD_LOAD_FAILED or loading_status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_fail_loading()
		return
	var previous: float = _shown_progress
	_shown_progress = maxf(previous, minf(actual_progress, clampf(_elapsed / minimum_loading_time, 0.0, 1.0)))
	_bar.value = _shown_progress * _bar.max_value
	_status.text = "LOADING %d%%" % roundi(_shown_progress * 100.0)
	var pace: float = (_shown_progress - previous) / maxf(delta, 0.000001) * minimum_loading_time
	for runner: AnimatedSprite2D in _runners:
		var frames: SpriteFrames = runner.sprite_frames
		var fps: float = maxf(frames.get_animation_speed(&"run"), 0.001)
		runner.speed_scale = float(frames.get_frame_count(&"run")) * run_cycles_per_second / fps * pace
	_update_layout()
	if _shown_progress >= 1.0 and _menu_scene != null:
		_go_to_menu()


func _update_layout() -> void:
	var group_width: float = runner_size * float(_runners.size())
	_group.position = Vector2(maxf(_track.size.x - group_width, 0.0) * _shown_progress, _track.size.y - runner_size * 0.5)
	for index in _runners.size():
		_runners[index].position = Vector2(runner_size * (float(index) + 0.5), 0)


func _fail_loading() -> void:
	_failed = true
	_status.text = "UNABLE TO LOAD MENU"
	for runner: AnimatedSprite2D in _runners:
		runner.speed_scale = 0.0
	push_error("Boot: cannot load " + main_menu_scene)


func menu_loaded() -> bool:
	return _menu_scene != null


func _go_to_menu() -> void:
	if _done:
		return
	_done = true
	SceneTransition.change_scene(main_menu_scene)
