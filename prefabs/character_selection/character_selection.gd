class_name CharacterSelection
extends Panel

@export var portrait: TextureRect
@export var blackout_shade: Control
@export var hover_shade: Control

var selected: bool:
	get:
		return Stage.character_selection_name == name

var hovered: bool:
	set(value):
		hovered = value
		update()

func _ready() -> void:
	mouse_entered.connect(
		func (): hover_shade.visible = true
	)
	mouse_exited.connect(
		func (): hover_shade.visible = false
	)
	gui_input.connect(
		func (event: InputEvent):
			if event is InputEventMouseButton:
				if event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
					Stage.character_selection_name = name
	)
	Stage.character_selection_name_changed.connect(update)
	
	update()

func update() -> void:
	blackout_shade.visible = not selected
