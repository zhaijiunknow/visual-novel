class_name StagePage
extends CanvasLayer

signal next_line
signal skip_cancelled
signal auto_cancelled

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
@export var texture_rect_cg: TextureRect
@export var texture_rect_variation: TextureRect
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

@export var date: Control
@export var label_month: Label
@export var label_day: Label
@export var label_week_day: Label

enum AdvanceMode { MANUAL, SKIP, AUTO }
var _mode: AdvanceMode = AdvanceMode.MANUAL
var _idle: bool = false
var _voice_finished_cb: Callable = Callable()
var quick_save_progress_count: int = 0

var skip: bool:
	get: return _mode == AdvanceMode.SKIP
	set(value):
		if value:
			_set_mode(AdvanceMode.SKIP)
		elif _mode == AdvanceMode.SKIP:
			_set_mode(AdvanceMode.MANUAL)

var autoplay: bool:
	get: return _mode == AdvanceMode.AUTO
	set(value):
		if value:
			_set_mode(AdvanceMode.AUTO)
		elif _mode == AdvanceMode.AUTO:
			_set_mode(AdvanceMode.MANUAL)

func _set_mode(mode: AdvanceMode) -> void:
	_mode = mode
	if skip_tag: skip_tag.visible = (_mode == AdvanceMode.SKIP)
	if auto_tag: auto_tag.visible = (_mode == AdvanceMode.AUTO)
	update_step_rate()
	if _mode == AdvanceMode.SKIP and _idle:
		next_line.emit()
	elif _mode == AdvanceMode.AUTO and _idle:
		_trigger_auto_advance()

func _trigger_auto_advance() -> void:
	if AudioManager.audio_player_voice.playing:
		while AudioManager.audio_player_voice.playing:
			await get_tree().process_frame
			if _mode != AdvanceMode.AUTO or not _idle: return
	if _idle and _mode == AdvanceMode.AUTO:
		next_line.emit()

func update_step_rate() -> void:
	apply_speed_settings()
	var rate = normal_step_rate
	match _mode:
		AdvanceMode.SKIP: rate = skip_step_rate
		AdvanceMode.AUTO: rate = auto_step_rate
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
		if dialogue_line and dialogue_line.has_tag("语音"):
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
			await process_phone_line()
			if dialogue_line != current: return
			if dialogue_line.responses:
				return
		elif "奇迹书" in dialogue_line.tags:
			await process_book_line()
			if dialogue_line != current: return
			if dialogue_line.responses:
				return
		else:
			await process_dialogue_line()
			if dialogue_line != current: return
			if dialogue_line.responses:
				return

	# 标记已读（在skip检查之后）
	var line_id := dialogue_line.id.to_int()
	var should_count_quick_save := _should_count_for_quick_save(dialogue_line, line_id)
	Main.save_data.mark_read(chapter_name, line_id)
	if should_count_quick_save:
		_register_quick_save_progress()
	dialogue_line = await dialogue.get_next_dialogue_line(dialogue_line.next_id, [ self , Stage])


func process_phone_line() -> void:
	await Game.phone_page.show_dialogue_message(dialogue_line.character, dialogue_line.text)

	if dialogue_line.responses:
		if skip and not Main.setting_data.skip_after_choice:
			_set_mode(AdvanceMode.MANUAL)
			skip_cancelled.emit()
		Game.phone_page.show_reply_options(dialogue_line.responses)
		var next_id: String = await Game.phone_page.reply_selected
		dialogue_line = await dialogue.get_next_dialogue_line(next_id, [self, Stage])

func process_book_line() -> void:
	print("[BookChoice] line id=", dialogue_line.id, " next_id=", dialogue_line.next_id, " tags=", dialogue_line.tags, " responses=", dialogue_line.responses.size(), " text=", dialogue_line.text)
	var side := "right" if dialogue_line.character == "周腾" else "left"
	await Game.book_page.append_story_entry(
		str(dialogue_line.id),
		dialogue_line.character,
		dialogue_line.text,
		side,
		[]
	)
	if dialogue_line.responses:
		print("[BookChoice] show_reply_options count=", dialogue_line.responses.size())
		if skip and not Main.setting_data.skip_after_choice:
			_set_mode(AdvanceMode.MANUAL)
			skip_cancelled.emit()
		Game.book_page.show_reply_options(dialogue_line.responses)
		var next_id: String = await Game.book_page.reply_selected
		print("[BookChoice] selected next_id=", next_id)
		var selected_next_line: DialogueLine = await dialogue.get_next_dialogue_line(next_id, [self, Stage])
		if selected_next_line and "奇迹书" not in selected_next_line.tags:
			await Game.book_page.wait_for_story_close()
		dialogue_line = selected_next_line
		return
	print("[BookChoice] no responses on current book line")
	var next_line: DialogueLine = await dialogue.get_next_dialogue_line(dialogue_line.next_id, [self, Stage])
	if next_line and "奇迹书" not in next_line.tags:
		await Game.book_page.wait_for_story_close()

var expression: String:
	get:
		return dialogue_line.get_tag_value("表情")

func _should_count_for_quick_save(line: DialogueLine, line_id: int) -> bool:
	if line == null or line.text == "" or line_id <= 0:
		return false
	return not Main.save_data.is_line_read(chapter_name, line_id)

func _register_quick_save_progress() -> void:
	quick_save_progress_count += 1
	if quick_save_progress_count < 20:
		return
	quick_save_progress_count = 0
	Game.profile_page.save_quick_game()

func process_dialogue_line() -> void:
	AudioManager.audio_player_voice.stop()
	var has_avatar = character != null

	# 角色表情/身体（在对话框出现前准备好）
	if has_avatar:
		if dialogue_line.has_tag("身体"):
			character.SetBody(dialogue_line.get_tag_value("身体"))
		if dialogue_line.has_tag("附加"):
			character.ClearOptionals()
			character.SetOptionals(dialogue_line.get_tag_value("附加"))
		if expression:
			character.SetExpression(expression)

	# 角色头像
	avatar.texture = null
	if has_avatar and not "隐藏头像" in dialogue_line.tags:
		avatar.texture = character.dialogue_box.preview_texture
	avatar.modulate.a = 1 if has_avatar else 0

	# 对话框淡入（ShowDialogue 内部会更新角色名、清空文字、设语音按钮）
	await Stage.ShowDialogue()

	# 语音
	_disconnect_voice_finished()
	if dialogue_line.has_tag("语音") and character:
		character.subviewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
		character.body_part_dict["Mouth"].animation = character.speaking_mouth
		_voice_finished_cb = func():
			if not expression: return
			character.subviewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			character.SetExpression(expression)
		AudioManager.voice_finished.connect(_voice_finished_cb)
		update_favourite()
		AudioManager.play_voice(voice_name, true)
		AudioManager.apply_character_volume(dialogue_line.character)
	else:
		AudioManager.audio_player_voice.stop()
		if character:
			character.subviewport.render_target_update_mode = SubViewport.UPDATE_ONCE

	# 打字（fade in 完成后才开始）
	responses_menu.visible = dialogue_line.responses.size() > 0
	dialogue_label.dialogue_line = dialogue_line
	dialogue_label.type_out()
	while dialogue_label.is_typing:
		await get_tree().process_frame

	# 分支或前进
	if dialogue_line.responses:
		if skip and not Main.setting_data.skip_after_choice:
			_set_mode(AdvanceMode.MANUAL)
			skip_cancelled.emit()
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
	match _mode:
		AdvanceMode.SKIP:
			var is_read = Main.save_data.is_line_read(chapter_name, dialogue_line.id.to_int())
			if not Main.setting_data.skip_unread_text and not is_read:
				_set_mode(AdvanceMode.MANUAL)
				skip_cancelled.emit()
				_idle = true
				await next_line
				_idle = false
			else:
				next_line.emit()
		AdvanceMode.AUTO:
			if dialogue_line.has_tag("语音"):
				while AudioManager.audio_player_voice.playing:
					await get_tree().process_frame
					if _mode != AdvanceMode.AUTO: break
			else:
				await get_tree().create_timer(finish_pause).timeout
			if _mode == AdvanceMode.AUTO:
				next_line.emit()
			else:
				_idle = true
				await next_line
				_idle = false
		_:
			_idle = true
			await next_line
			_idle = false


# ─── 初始化 ───

func _ready() -> void:
	date.modulate.a = 0
	dialogue_label.visible_characters = 0
	Main.speed_settings_changed.connect(update_step_rate)
	DialogueManager.dialogue_ended.connect(_on_dialogue_end)
	for chapter in chapters:
		var _chapter_name = chapter.resource_path.get_file().split(".")[0]
		chapters_dict[_chapter_name] = chapter

	dialogue_screen.gui_input.connect(
		func(event: InputEvent):
			if Game.loading: return
			if event is InputEventMouseButton:
				if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					if _mode != AdvanceMode.MANUAL:
						var was_skip = (_mode == AdvanceMode.SKIP)
						_set_mode(AdvanceMode.MANUAL)
						if was_skip: skip_cancelled.emit()
						else: auto_cancelled.emit()
						return
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
			Main.voice_collection_changed.emit(voice_name)
	)
	Main.voice_collection_changed.connect(
		func(vf: String):
			if vf == voice_name:
				update_favourite()
	)


func _disconnect_voice_finished() -> void:
	if not _voice_finished_cb.is_null() and AudioManager.voice_finished.is_connected(_voice_finished_cb):
		AudioManager.voice_finished.disconnect(_voice_finished_cb)
		_voice_finished_cb = Callable()

func reset() -> void:
	_mode = AdvanceMode.MANUAL
	_idle = false
	skip_tag.visible = false
	auto_tag.visible = false
	dialogue_line = null
	dialogue_screen.modulate.a = 0
	label_character_name.text = ""
	dialogue_label.text = ""
	dialogue_label.visible_characters = 0
	date.modulate.a = 0
	texture_rect_blackscreen.modulate.a = 0
	avatar.texture = null
	responses_menu.visible = false
	voice_buttons.visible = false
	AudioManager.audio_player_voice.stop()
	_disconnect_voice_finished()
	Stage.reset()
	quick_save_progress_count = 0

func start() -> void:
	reset()
	dialogue_line = await dialogue.get_next_dialogue_line("start", [ self , Stage])
	if not Game.profile_page.has_quick_save():
		Game.profile_page.save_quick_game()


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

# ─── 对话结束 ───

func _on_dialogue_end(_resource: DialogueResource) -> void:
	if _resource != dialogue:
		return
	_disconnect_voice_finished()
	AudioManager.audio_player_voice.stop()
	responses_menu.visible = false
	Stage.reset()
	reset()
	Game.switch_to_page(Game.main_menu, true, false)
