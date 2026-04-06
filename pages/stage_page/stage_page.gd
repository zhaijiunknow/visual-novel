class_name StagePage
extends CanvasLayer

signal next_line

@export var chapters: Array[DialogueResource]
var chapters_dict: Dictionary[String, DialogueResource]

@export var dialogue: DialogueResource
var chapter_name: String:
	get:
		return dialogue.resource_path.get_file().split(".")[0]

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

@export var skip_tag: TextureRect
@export var auto_tag: TextureRect

@export var date_player: AnimationPlayer
@export var label_month: Label
@export var label_day: Label
@export var label_week_day: Label

var skip: bool = false:
	set(value):
		skip = value
		if skip_tag: skip_tag.visible = skip
		if skip:
			next_line.emit()
		update_step_rate()

var autoplay: bool = false:
	set(value):
		autoplay = value
		if auto_tag: auto_tag.visible = autoplay
		if autoplay:
			next_line.emit()
		update_step_rate()

func update_step_rate() -> void:
	apply_speed_settings()
	var rate = auto_step_rate if autoplay else normal_step_rate
	rate = skip_step_rate if skip else rate
	dialogue_label.seconds_per_step = rate

func apply_speed_settings() -> void:
	var s = Main.setting_data
	normal_step_rate = 0.05 - s.text_speed * 0.048
	auto_step_rate = 0.05 - s.auto_speed * 0.048
	finish_pause = 0.5 + (1.0 - s.auto_speed) * 3.0

func get_position_by_name(position_name: String) -> Vector2:
	var position_node: Control = hbox_positions.get_node(position_name + "/CenterPoint")
	return position_node.global_position

var dialogue_line: DialogueLine:
	set(value):
		dialogue_line = value
		if value:
			process_line()

var finish_pause: float = 1

var voice_name: String:
	get:
		if dialogue_line.has_tag("语音"):
			return dialogue_line.get_tag_value("语音")
		return ""

var character: Character:
	get:
		if Stage.character_dict.has(dialogue_line.character):
			return Stage.Character(dialogue_line.character)
		return null


var scene: String:
	get:
		if dialogue_line:
			return dialogue_line.get_tag_value("场景")
		return ""

# ─── 对话处理 ───

func process_line() -> void:
	var current = dialogue_line
	if not dialogue_line.text:
		pass
	else:
		if dialogue_line.has_tag("延迟"):
			await get_tree().create_timer(float(dialogue_line.get_tag_value("延迟"))).timeout
			if dialogue_line != current: return

		if "手机" in dialogue_line.tags:
			process_phone_line()
			if dialogue_line.responses:
				return
		else:
			await process_dialogue_line()
			if dialogue_line != current: return
			if dialogue_line.responses:
				return

	dialogue_line = await dialogue.get_next_dialogue_line(dialogue_line.next_id, [ self , Stage])


func process_phone_line() -> void:
	var chat_message: ChatMessage = Prefabs.chat_message.instantiate()
	Game.phone_page.chat_message_pool.add_child(chat_message)
	var type = Enums.SenderType.SELF \
		if dialogue_line.character == "周腾" else Enums.SenderType.OTHER
	await chat_message.setup(type, dialogue_line.text)
	Game.phone_page.add_message(dialogue_line.character, dialogue_line.text)

	if dialogue_line.responses:
		for response: DialogueResponse in dialogue_line.responses:
			var reply_selection: ReplySelection = Prefabs.reply_selection.instantiate()
			reply_selection.reply_text.text = response.text
			reply_selection.next_id = response.next_id
			Game.phone_page.reply_selection_pool.add_child(reply_selection)

var expression: String:
	get:
		return dialogue_line.get_tag_value("表情")

func process_dialogue_line() -> void:
	var has_avatar = character != null

	# 角色头像
	avatar.texture = null
	if has_avatar:
		if not "隐藏头像" in dialogue_line.tags:
			avatar.texture = character.texture_rect_avatar.texture
		if dialogue_line.has_tag("身体"):
			character.SetBody(dialogue_line.get_tag_value("身体"))
		if dialogue_line.has_tag("附加"):
			character.ClearOptionals()
			character.SetOptionals(dialogue_line.get_tag_value("附加"))
		if expression:
			character.SetExpression(expression)
	avatar.modulate.a = 1 if has_avatar else 0

	# 角色名 / 昵称
	label_character_name.text = dialogue_line.get_tag_value("昵称") \
		if dialogue_line.has_tag("昵称") else dialogue_line.character

	# 语音
	voice_buttons.visible = dialogue_line.has_tag("语音")
	Tools.clear_connections(AudioManager.audio_player_voice.finished)
	if dialogue_line.has_tag("语音") and character:
		character.subviewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
		character.body_part_dict["Mouth"].animation = character.speaking_mouth
		AudioManager.audio_player_voice.finished.connect(
			func():
				if not expression: return
				character.subviewport.render_target_update_mode = SubViewport.UPDATE_ONCE
				character.SetExpression(expression)
		)
		update_favourite()
		AudioManager.play_voice(voice_name, true)
		AudioManager.apply_character_volume(dialogue_line.character)
	else:
		AudioManager.audio_player_voice.stop()
		if character:
			character.subviewport.render_target_update_mode = SubViewport.UPDATE_ONCE

	# 打字
	responses_menu.visible = dialogue_line.responses.size() > 0
	dialogue_label.dialogue_line = dialogue_line
	dialogue_label.type_out()
	while dialogue_label.is_typing:
		await get_tree().process_frame

	# 分支或前进
	if dialogue_line.responses:
		show_dialogue_responses()
	else:
		await wait_for_advance()


func show_dialogue_responses() -> void:
	for child in responses_menu.get_children():
		child.queue_free()
	for response: DialogueResponse in dialogue_line.responses:
		var selection: DialogueSelection = Prefabs.dialogue_selection.instantiate()
		selection.text = response.text
		selection.pressed.connect(
			func():
				dialogue_line = await dialogue.get_next_dialogue_line(response.next_id, [ self , Stage])
		)
		responses_menu.add_child(selection)


func wait_for_advance() -> void:
	if skip:
		next_line.emit()
	elif autoplay:
		if dialogue_line.has_tag("语音"):
			while AudioManager.audio_player_voice.playing:
				await get_tree().process_frame
		else:
			await get_tree().create_timer(finish_pause).timeout
		next_line.emit()
	else:
		await next_line


# ─── 初始化 ───

func _ready() -> void:
	dialogue_label.visible_characters = 0
	Main.speed_settings_changed.connect(update_step_rate)
	for chapter in chapters:
		var _chapter_name = chapter.resource_path.get_file().split(".")[0]
		chapters_dict[_chapter_name] = chapter

	dialogue_screen.gui_input.connect(
		func(event: InputEvent):
			if event is InputEventMouseButton:
				if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					if dialogue_label.is_typing:
						dialogue_label.skip_typing()
					next_line.emit()
	)

	button_replay.pressed.connect(AudioManager.replay_voice)
	button_favourite.pressed.connect(
		func():
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
	dialogue_line = await dialogue.get_next_dialogue_line("start", [ self , Stage])


# ─── 收藏 ───

var favourite: bool:
	get: return current_collection != null

var current_collection: VoiceCollection:
	get:
		for collection in Main.collection_data.voice_collections:
			if collection.voice_filename == voice_name:
				return collection
		return null

func update_favourite() -> void:
	texture_rect_favourite.texture = \
		Prefabs.texture_cancel_favourite if favourite else Prefabs.texture_set_favourite
