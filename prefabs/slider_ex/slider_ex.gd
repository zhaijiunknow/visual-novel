@tool
class_name SliderEx
extends PanelContainer

signal value_changed(new_value: float)

@export var initial_value: float = 0.5:
	set(v):
		initial_value = v
		if Engine.is_editor_hint():
			value = initial_value

@export var step: float = 0.0

@export var fill: Control
@export var end_point: Control
@export var caret: Control
@export var click_rect: Control

var dragged: bool = false
var _value: float = 0.0

var value: float:
	get:
		return _value
	set(v):
		_set_value(v, true)

func set_value_silent(v: float) -> void:
	_set_value(v, false)


func _set_value(v: float, notify: bool) -> void:
	v = clamp(v, 0.0, 1.0)
	if step > 0.0:
		v = snapped(v, step)
		v = clamp(v, 0.0, 1.0)
	if abs(_value - v) < 0.0001:
		return
	_value = v
	_update_visuals()
	if notify:
		value_changed.emit(_value)


func _update_visuals() -> void:
	fill.size.x = size.x * _value
	_update_caret()


func _update_caret() -> void:
	if caret and end_point:
		caret.global_position = end_point.global_position - caret.get_combined_pivot_offset()


func _ready() -> void:
	set_process_input(false)
	click_rect.gui_input.connect(_on_click_rect_input)
	set_value_silent(initial_value)
	resized.connect(_update_caret)


func _on_click_rect_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			dragged = true
			set_process_input(true)
			value = event.position.x / size.x
	elif dragged and event is InputEventMouseMotion:
		value = event.position.x / size.x


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var local_x: float = event.global_position.x - global_position.x
		value = local_x / size.x
	elif event is InputEventMouseButton:
		if event.is_released() and event.button_index == MOUSE_BUTTON_LEFT:
			dragged = false
			set_process_input(false)
