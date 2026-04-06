class_name LogLine
extends MarginContainer

@export var vbox_character_info: VBoxContainer
@export var label_character_name: Label
@export var rich_label_dialogue_text: RichTextLabel
@export var button_replay: TextureRect
@export var button_favourite: TextureRect

const COLOR_NORMAL := Color(0.7, 0.7, 0.7, 0.6)
const COLOR_HOVER := Color(1.0, 1.0, 1.0, 0.9)
const COLOR_PRESS := Color(0.5, 0.5, 0.5, 1.0)
const COLOR_FAVOURITE_ON := Color(1.0, 0.85, 0.3, 1.0)
const COLOR_FAVOURITE_OFF := COLOR_NORMAL

var log_data: LogData

var character_name: String:
	set(value):
		character_name = value
		label_character_name.text = character_name
		vbox_character_info.modulate.a = 1 if character_name else 0

var dialogue_text: String:
	set(value):
		dialogue_text = value
		rich_label_dialogue_text.text = dialogue_text

var has_voice: bool:
	get: return log_data != null and log_data.voice_filename != ""

var is_favourite: bool:
	get:
		if not has_voice: return false
		for collection in Main.collection_data.voice_collections:
			if collection.voice_filename == log_data.voice_filename:
				return true
		return false

func setup(data: LogData) -> void:
	log_data = data
	character_name = data.character_name
	dialogue_text = data.text
	var show = has_voice
	button_replay.visible = show
	button_favourite.visible = show
	_update_favourite_color()

func _ready() -> void:
	button_replay.mouse_filter = Control.MOUSE_FILTER_STOP
	button_favourite.mouse_filter = Control.MOUSE_FILTER_STOP
	button_replay.modulate = COLOR_NORMAL
	button_favourite.modulate = COLOR_FAVOURITE_OFF

	button_replay.mouse_entered.connect(func(): button_replay.modulate = COLOR_HOVER)
	button_replay.mouse_exited.connect(func(): button_replay.modulate = COLOR_NORMAL)
	button_replay.gui_input.connect(
		func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					button_replay.modulate = COLOR_PRESS
				else:
					if has_voice:
						AudioManager.play_voice(log_data.voice_filename)
					button_replay.modulate = COLOR_HOVER
	)

	button_favourite.mouse_entered.connect(func(): _update_favourite_color(true))
	button_favourite.mouse_exited.connect(func(): _update_favourite_color())
	button_favourite.gui_input.connect(
		func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					button_favourite.modulate = COLOR_PRESS
				else:
					if has_voice:
						_toggle_favourite()
					_update_favourite_color(true)
	)

func _toggle_favourite() -> void:
	if is_favourite:
		for collection in Main.collection_data.voice_collections:
			if collection.voice_filename == log_data.voice_filename:
				Main.collection_data.voice_collections.erase(collection)
				break
	else:
		var collection = VoiceCollection.new()
		collection.character_name = log_data.character_name
		collection.chapter_name = log_data.chapter_name
		collection.text = log_data.text
		collection.voice_filename = log_data.voice_filename
		Main.collection_data.voice_collections.append(collection)
	Main.save_collection_data()

func _update_favourite_color(hover: bool = false) -> void:
	if not has_voice: return
	var base = COLOR_FAVOURITE_ON if is_favourite else COLOR_FAVOURITE_OFF
	button_favourite.modulate = COLOR_HOVER if hover else base
