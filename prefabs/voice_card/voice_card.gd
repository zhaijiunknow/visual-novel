class_name VoiceCard
extends TextureRect

@export var texture_rect_portrait: TextureRect
@export var label_number: Label
@export var label_text: RichTextLabel
@export var drag_filter: DragFilter

var voice_page: VoicePage:
	get: return Game.bonus_page.voice_page

var voice_collection: VoiceCollection:
	set(value):
		voice_collection = value
		texture_rect_portrait.texture = Stage.character_dict[voice_collection.character_name].texture_rect_avatar.texture
		label_text.text = voice_collection.text

func _ready() -> void:
	label_number.text = ("NO.%s" % get_index()).pad_zeros(2)
	
	drag_filter.execute.connect(
		func ():
			voice_page.current_collection = voice_collection
	)
