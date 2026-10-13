class_name StateMachine
extends Node
## Quản lý các State con. Mỗi State là một node con trực tiếp, tên node = tên state.

signal state_changed(name: StringName)

@export var initial_state: State

var current_state: State
var states: Dictionary[StringName, State] = {}


func _ready() -> void:
	for child in get_children():
		var state := child as State
		if state == null:
			push_warning("StateMachine: '%s' không phải State, bỏ qua." % child.name)
			continue
		states[state.name] = state
	if initial_state != null and states.has(initial_state.name):
		change_state(initial_state.name)
	elif not states.is_empty():
		change_state(states.keys()[0])


func change_state(state_name: StringName, msg: Dictionary = {}) -> void:
	if current_state != null and current_state.name == state_name:
		return
	if not states.has(state_name):
		push_warning("StateMachine: không có state '%s'." % state_name)
		return
	if current_state != null:
		current_state.exit()
	current_state = states[state_name]
	current_state.enter(msg)
	state_changed.emit(state_name)


func is_current(state_name: StringName) -> bool:
	return current_state != null and current_state.name == state_name


func _physics_process(delta: float) -> void:
	if current_state != null:
		current_state.physics_update(delta)


func _unhandled_input(event: InputEvent) -> void:
	if current_state != null:
		current_state.handle_input(event)