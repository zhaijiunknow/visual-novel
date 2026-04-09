@tool
class_name VoiceCard
extends TextureRect

@export var preview_texture: Texture2D:
	set(value):
		preview_texture = value
		texture_rect_portrait.texture = preview_texture

@export var texture_rect_portrait: TextureRect
@export var label_number: Label
@export var label_text: RichTextLabel
@export var drag_filter: DragFilter

var voice_page: VoicePage:
	get: return Game.bonus_page.voice_page

var voice_collection: VoiceCollection:
	set(value):
		voice_collection = value
		texture_rect_portrait.texture = Stage.Character(voice_collection.character_name).texture_rect_avatar.texture
		label_text.text = voice_collection.text

const COLOR_NORMAL := Color(1, 1, 1, 1)
const COLOR_HOVER := Color(0.85, 0.85, 0.85, 1)
const COLOR_PRESSED := Color(0.7, 0.7, 0.7, 1)

func _ready() -> void:
	if Engine.is_editor_hint(): return
	label_number.text = ("NO.%s" % get_index()).pad_zeros(2)
	mouse_entered.connect(func(): modulate = COLOR_HOVER)
	mouse_exited.connect(func(): modulate = COLOR_NORMAL)
	gui_input.connect(
		func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
				modulate = COLOR_PRESSED if event.pressed else COLOR_HOVER
	)

	drag_filter.execute.connect(
		func ():
			voice_page.select_collection(voice_collection)
	)
