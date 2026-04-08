class_name DialogueButton
extends Control

signal toggle_changed
signal clicked

@export var hint_text: String:
	set(value):
		hint_text = value
		if _hint_label:
			_hint_label.text = hint_text

@export var toggle_button: bool
@export var select_frame: TextureRect
@export var icon: TextureRect
@export var click_rect: Control
@export var hint_panel: Control

var color_normal = Color(1.0, 1.0, 1.0, 0)
var color_selected = Color(1.0, 1.0, 1.0, 1.0)
var color_hover = Color(0.7, 0.7, 0.7)
var color_click = Color(1.0, 1.0, 1.0)

@export var _hint_label: Label

@export var toggled: bool:
	set(value):
		toggled = value
		_update_modulate()
		toggle_changed.emit()

var hovered: bool:
	set(value):
		hovered = value
		hint_panel.visible = hovered
		_update_modulate()

var disabled: bool:
	set(value):
		disabled = value
		if disabled:
			toggled = false
			hovered = false
		_update_modulate()

var _pressing: bool = false

func _ready() -> void:
	_hint_label.text = hint_text
	hint_panel.visible = false

	click_rect.mouse_entered.connect(
		func ():
			if disabled: return
			hovered = true
	)
	click_rect.mouse_exited.connect(
		func ():
			if disabled: return
			hovered = false
			_pressing = false
	)
	click_rect.gui_input.connect(
		func (event: InputEvent):
			if disabled: return
			if event is InputEventMouseButton:
				if event.button_index == MOUSE_BUTTON_LEFT:
					if event.is_pressed():
						_pressing = true
						_update_modulate()
						clicked.emit()
						if toggle_button:
							toggled = not toggled
					if event.is_released():
						_pressing = false
						_update_modulate()
	)

	toggled = toggled


func _update_modulate() -> void:
	if disabled:
		select_frame.modulate = Color(1, 1, 1, 0.3)
		return
	if _pressing:
		select_frame.modulate = color_click
		return
	if hovered:
		select_frame.modulate = color_hover
		return
	if toggle_button and toggled:
		select_frame.modulate = color_selected
		return
	select_frame.modulate = color_normal
