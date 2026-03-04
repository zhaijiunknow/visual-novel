class_name CharacterSelection
extends Panel

@export var portrait: TextureRect
@export var blackout_shade: Control
@export var hover_shade: Control

var selected: bool:
	get:
		return Stage.character_selection_index == get_index()

var hovered: bool:
	set(value):
		hovered = value
		update()

func _ready() -> void:
	portrait.texture = Stage.character_dict[name].character_page_portrait.texture
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
					Stage.character_selection_index = get_index()
	)
	Stage.character_selection_index_changed.connect(update)
	
	update()

func update() -> void:
	blackout_shade.visible = not selected
