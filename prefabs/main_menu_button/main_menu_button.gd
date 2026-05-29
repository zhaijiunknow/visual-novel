class_name MainMenuButton
extends Control

signal clicked

@export var texture_hover: TextureRect
@export var texture_click: TextureRect
@export var click_box: Control
@export var label_chinese: Label
@export var label_english: Label

var selected: bool = false

func _ready() -> void:
	click_box.mouse_entered.connect(
		func ():
			texture_hover.visible = true
	)
	click_box.mouse_exited.connect(
		func ():
			texture_hover.visible = false
			texture_click.visible = false
	)

	click_box.gui_input.connect(
		func (event: InputEvent):
			if event is InputEventMouseButton:
				if event.button_index == MOUSE_BUTTON_LEFT:
					if event.is_pressed():
						texture_click.visible = true
					if event.is_released():
						clicked.emit()
						texture_click.visible = false
	)

func set_titles(chinese: String, english: String) -> void:
	label_chinese.text = chinese
	label_english.text = english
