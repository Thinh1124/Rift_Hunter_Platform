class_name State
extends Node
## Base class cho các state của StateMachine.
## Tên node = tên state (vd node "idle" <-> change_state(&"idle")).

func enter(_msg: Dictionary = {}) -> void:
	pass


func exit() -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


func handle_input(_event: InputEvent) -> void:
	pass