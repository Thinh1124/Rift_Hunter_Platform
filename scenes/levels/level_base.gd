class_name LevelBase
extends Node2D
## Create new levels with New Inherited Scene from LevelBase.tscn.
## Camera limits use world coordinates; season is authoring metadata only.

@export_range(1, 99, 1) var level_number: int = 1
@export var music: AudioStream
@export_group("Camera limits (world coordinates)")
@export var limit_left: int = 0
@export var limit_right: int = 1280
@export var limit_top: int = 0
@export var limit_bottom: int = 720
@export_group("Notes")
@export_enum("spring", "summer", "autumn", "winter") var season: String = "spring"

@onready var player: Player = $Player
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var ground: TileMapLayer = $Ground
@onready var decor: TileMapLayer = $Decor
@onready var objects: Node2D = $Objects


func _ready() -> void:
	player.global_position = player_spawn.global_position
	player.velocity = Vector2.ZERO
	player.limit_left = limit_left
	player.limit_right = limit_right
	player.limit_top = limit_top
	player.limit_bottom = limit_bottom
	if player.camera != null:
		player.camera.limit_left = limit_left
		player.camera.limit_right = limit_right
		player.camera.limit_top = limit_top
		player.camera.limit_bottom = limit_bottom
		player.camera.limit_smoothed = false
		player.camera.reset_smoothing()
		player.camera.force_update_scroll()
	GameManager.current_level = level_number
	GameManager.last_checkpoint = player_spawn.global_position
	# register_gates already publishes EventBus.gates_changed, including 0/0.
	GameManager.register_gates()
	AudioManager.play_music(music)
