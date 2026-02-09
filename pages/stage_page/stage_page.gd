class_name StagePage
extends CanvasLayer
## A basic dialogue balloon for use with Dialogue Manager.

signal next_line

@export var chapters: Array[DialogueResource]
var chapters_dict: Dictionary[String, DialogueResource]

@export var dialogue: DialogueResource
var chapter_name: String:
	get:
		return dialogue.resource_path.get_file().split(".")[0]

@export var autoplay_pause_time: float = 1
@export var normal_step_rate: float = 0.02
@export var skip_step_rate: float = 0.01
@export var auto_step_rate: float = 0.1

@export var dialogue_screen: Control
@export var dialogue_label: DialogueLabel
@export var label_character_name: RichTextLabel
@export var responses_menu: Control
@export var subviewport: SubViewport
@export var hbox_positions: HBoxContainer
@export var character_image_pool: Control
@export var texture_rect_background: TextureRect
@export var texture_rect_blackscreen: ColorRect

@export var bg_common: TextureRect
@export var bg_character: TextureRect
@export var avatar: TextureRect

@export var button_replay: TextureButton
@export var button_favourite: TextureButton
@export var texture_rect_favourite: TextureRect

@export var voice_buttons: Control

var skip: bool = false:
	set(value):
		skip = value
		if skip:
			next_line.emit()
		update_step_rate()

var autoplay: bool = false:
	set(value):
		autoplay = value
		if autoplay:
			next_line.emit()
		update_step_rate()

func update_step_rate() -> void:
	var rate = auto_step_rate if autoplay else normal_step_rate
	rate = skip_step_rate if skip else rate
	dialogue_label.seconds_per_step = rate

func get_position_by_name(position_name: String) -> Vector2:
	var position_node: Control = hbox_positions.get_node(position_name + "/CenterPoint")
	
	return position_node.global_position

## The current line
var dialogue_line: DialogueLine:
	set(value):
		if value:
			dialogue_line = value
			process_line()

var finish_pause: float = 1

var voice_name: String:
	get: return dialogue_line.get_tag_value("voice")

func process_line() -> void:
	print(dialogue_line.tags)
	var character_name = dialogue_line.character
	avatar.texture = null
	var has_avatar = Stage.character_dict.has(character_name)
	if has_avatar:
		if not "hide_portrait" in dialogue_line.tags:
			avatar.texture = Stage.character_dict[character_name].texture_rect_avatar.texture
	avatar.modulate.a = 1 if has_avatar else 0
	label_character_name.text = dialogue_line.get_tag_value("nickname") \
				if dialogue_line.has_tag("nickname") else dialogue_line.character
	
	responses_menu.visible = dialogue_line.responses.size()
	dialogue_label.dialogue_line = dialogue_line
	voice_buttons.visible = dialogue_line.has_tag("voice")
	if dialogue_line.has_tag("voice"):
		update_favourite()
		AudioManager.play_voice(voice_name, true)
	else:
		AudioManager.audio_player_voice.stop()
	dialogue_label.type_out()
	while dialogue_label.is_typing:
		await get_tree().process_frame
	
	if dialogue_line.responses:
		for child in responses_menu.get_children():
			responses_menu.remove_child(child)
			child.queue_free()
		for response: DialogueResponse in dialogue_line.responses:
			var selection: DialogueSelection = Prefabs.dialogue_selection.instantiate()
			selection.text = response.text
			selection.pressed.connect(
				func ():
					dialogue_line = await dialogue.get_next_dialogue_line(response.next_id, [self, Stage])
			)
			responses_menu.add_child(selection)
		return
	else:
		if autoplay or skip:
			if skip:
				next_line.emit()
			else:
				if dialogue_line.has_tag("voice"):
					while AudioManager.audio_player_voice.playing:
						await get_tree().process_frame
				else:
					await get_tree().create_timer(finish_pause).timeout
		else:
			await next_line
		
	dialogue_line = await dialogue.get_next_dialogue_line(dialogue_line.next_id, [self, Stage])

func _ready() -> void:
	dialogue_label.visible_characters = 0
	for chapter in chapters:
		var _chapter_name = chapter.resource_path.get_file().split(".")[0]
		chapters_dict[_chapter_name] = chapter
	
	dialogue_screen.gui_input.connect(
		func (event: InputEvent):
			if event is InputEventMouseButton:
				if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					if dialogue_label.is_typing:
						dialogue_label.skip_typing()
					next_line.emit()
	)
	
	button_replay.pressed.connect(AudioManager.replay_voice)
	button_favourite.pressed.connect(
		func ():
			if favourite:
				Main.collection_data.voice_collections.erase(current_collection)
			else:
				var collection = VoiceCollection.new()
				collection.character_name = dialogue_line.character
				collection.chapter_name = chapter_name
				collection.text = dialogue_line.text
				collection.voice_filename = voice_name
				Main.collection_data.voice_collections.append(collection)
			Main.save_collection_data()
			update_favourite()
	)

func start() -> void:
	dialogue_line = await dialogue.get_next_dialogue_line("start", [self, Stage])

var favourite: bool:
	get: return current_collection != null

var current_collection: VoiceCollection:
	get:
		var collections: Array[VoiceCollection]
		for collection in Main.collection_data.voice_collections:
			if collection.voice_filename == voice_name:
				collections.append(collection)
		return collections.front() if collections else null

func update_favourite() -> void:
	texture_rect_favourite.texture = \
		Prefabs.texture_cancel_favourite if favourite else Prefabs.texture_set_favourite
