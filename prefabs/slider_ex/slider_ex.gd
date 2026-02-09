@tool
class_name SliderEx
extends PanelContainer

var dragged: bool

signal value_changed

@export var initial_value: float = 0.5:
	set(_value):
		initial_value = _value
		if not Engine.is_editor_hint(): return
		value = initial_value

var value: float:
	set(_value):
		value = clamp(_value, 0, 1)
		fill.size.x = size.x * value
		value_changed.emit()
		caret.global_position = end_point.global_position - caret.get_combined_pivot_offset()

@export var fill: Control
@export var end_point: Control
@export var caret: Control
@export var click_rect: Control

func _ready() -> void:
	click_rect.gui_input.connect(
		func (event: InputEvent):
			if event is InputEventMouseButton:
				if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					dragged = true
					value = event.position.x / size.x
			if dragged:
				if event is InputEventMouseMotion:
					value = event.position.x / size.x
	)
	
	value = initial_value

func _input(event: InputEvent) -> void:
	if dragged:
		if event is InputEventMouseButton:
			if event.is_released() and event.button_index == MOUSE_BUTTON_LEFT:
				dragged = false
