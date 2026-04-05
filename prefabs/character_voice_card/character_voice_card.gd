@tool
class_name CharacterVoiceCard
extends TextureButton

signal character_selected(card: CharacterVoiceCard)

@export var character_name: String
@export var texture_normal_state: Texture2D:
	set(value):
		texture_normal_state = value
		if not selected and not hovered:
			texture_normal = value
@export var texture_hover_state: Texture2D:
	set(value):
		texture_hover_state = value
		if hovered:
			texture_normal = value
@export var texture_selected_state: Texture2D:
	set(value):
		texture_selected_state = value
		if selected:
			texture_normal = value

var selected: bool = false:
	set(value):
		selected = value
		if selected:
			texture_normal = texture_selected_state
		else:
			texture_normal = texture_normal_state

var hovered: bool = false:
	set(value):
		hovered = value
		if selected: return
		if hovered:
			texture_normal = texture_hover_state
		else:
			texture_normal = texture_normal_state

func _ready() -> void:
	if Engine.is_editor_hint(): return
	mouse_entered.connect(func(): hovered = true)
	mouse_exited.connect(func(): hovered = false)
	pressed.connect(func(): character_selected.emit(self))
	texture_normal = texture_normal_state
