class_name DialogueButton
extends TextureRect

signal toggle_changed
signal clicked

@export var hint_text: String
@export var toggle_button: bool
@export var select_frame: TextureRect
@export var icon: TextureRect
@export var click_rect: Control

var color_normal = Color(1.0, 1.0, 1.0)
var color_hover = Color(0.7, 0.7, 0.7)
var color_click = Color(0.5, 0.5, 0.5)
var color_off = Color(0.0, 0.0, 0.0, 0)

@export var toggled: bool:
	set(value):
		toggled = value
		
		var frame_on = toggle_button and toggled
		select_frame.self_modulate = color_normal if frame_on else color_off
		click_rect.mouse_filter = Control.MOUSE_FILTER_STOP if frame_on \
			else Control.MOUSE_FILTER_IGNORE
		
		toggle_changed.emit()

var disabled: bool:
	set(value):
		disabled = value
		if disabled:
			toggled = false
		modulate.a = 0.3 if disabled else 1.0

func _ready() -> void:
	icon.mouse_entered.connect(
		func ():
			if disabled: return
			icon.modulate = color_hover
	)
	icon.mouse_exited.connect(
		func ():
			if disabled: return
			icon.modulate = color_normal
	)
	icon.gui_input.connect(
		func (event: InputEvent):
			if disabled: return
			if event is InputEventMouseButton:
				if event.button_index == MOUSE_BUTTON_LEFT:
					if event.is_pressed():
						icon.modulate = color_click
						clicked.emit()
						if toggle_button:
							toggled = not toggled
					if event.is_released():
						icon.modulate = color_normal
	)
	
	toggled = toggled
