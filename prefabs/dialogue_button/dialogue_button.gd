class_name DialogueButton
extends TextureRect

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

var color_normal = Color(1.0, 1.0, 1.0)
var color_hover = Color(0.7, 0.7, 0.7)
var color_click = Color(1.0, 1.0, 1.0)

@export var _hint_label: Label

@export var toggled: bool:
	set(value):
		toggled = value
		if toggle_button:
			select_frame.self_modulate = color_normal if toggled else Color.TRANSPARENT
		toggle_changed.emit()

var hovered: bool:
	set(value):
		hovered = value
		hint_panel.visible = hovered
		modulate = color_hover if hovered else color_normal

var disabled: bool:
	set(value):
		disabled = value
		if disabled:
			toggled = false
			hovered = false
		modulate.a = 0.3 if disabled else 1.0

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
	)
	click_rect.gui_input.connect(
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
