extends Node

class MissingCharacter:
	var character_name: String

	func _init(name: String) -> void:
		character_name = name

	func FadeIn(_position_name: String, _duration: float = 0.5) -> void:
		pass

	func FadeOut(_duration: float = 0.5) -> void:
		pass

	func MoveTo(_position_name: String, _duration: float = 0.5) -> void:
		pass

	func SetParts(_parts_string: String) -> void:
		pass

	func SetBody(_body_name: String) -> void:
		pass

	func SetExpression(_expression_name: String) -> void:
		pass

	func ClearOptionals() -> void:
		pass

	func SetOptionals(_optionals_string: String) -> void:
		pass

@export var character_pool: Control
@export var background_data_pool: Array[BackgroundData]
@export var gallery_data_pool: Array[GalleryData]

var current_background: String
var current_date: String
var current_cg: String
var current_cg_variation: String

signal character_selection_name_changed
var character_selection_name: String:
	set(value):
		character_selection_name = value
		character_selection_name_changed.emit()

var character_dict: Dictionary[String, Character]
var _missing_character_dict: Dictionary[String, MissingCharacter]
var character_array: Array[Character]:
	get:
		var characters: Array[Character]
		for key in character_dict.keys():
			characters.append(character_dict[key])
		return characters

func _ready() -> void:
	for character: Character in character_pool.get_children():
		character_dict[character.name] = character

func reset() -> void:
	if Game and Game.stage_page:
		Game.stage_page.stop_background_performance()
		Game.stage_page.stop_opening_effects()
		Game.stage_page.texture_rect_cg.scale = Vector2.ONE
		Game.stage_page.texture_rect_cg.pivot_offset = Vector2.ZERO
		Game.stage_page.texture_rect_cg.position = Vector2(0, 0)
	current_background = ""
	current_date = ""
	current_cg = ""
	current_cg_variation = ""
	clear_characters()

func start() -> void:
	Game.stage_page.start()

#region Dialogue Commands
func Character(character_name: String):
	if character_dict.has(character_name):
		return character_dict[character_name]
	if not _missing_character_dict.has(character_name):
		_missing_character_dict[character_name] = MissingCharacter.new(character_name)
	return _missing_character_dict[character_name]

func SetBackground(background_name: String, variation_name: String,
		out_time: float = 1.2, in_time: float = 1.2) -> void:
	Game.stage_page.stop_background_performance()
	Game.stage_page.stop_opening_effects()
	var is_skip: bool = Game.stage_page.skip
	var skip_trans: bool = is_skip and Main.setting_data.skip_ignore_transitions

	if is_skip and not skip_trans:
		Game.stage_page._set_mode(Game.stage_page.AdvanceMode.MANUAL)
		Game.stage_page.skip_cancelled.emit()

	if skip_trans:
		Game.stage_page.texture_rect_blackscreen.modulate.a = 1
	else:
		await create_tween().tween_property(
			Game.stage_page.texture_rect_blackscreen,
			"modulate:a",
			1,
			out_time
		).finished

	var target_background: BackgroundData = background_data_pool.filter(
		func (background: BackgroundData):
			return background.title == background_name
	).front()
	_apply_background(target_background, variation_name)

	if skip_trans:
		Game.stage_page.texture_rect_blackscreen.modulate.a = 0
	else:
		await create_tween().tween_property(
			Game.stage_page.texture_rect_blackscreen,
			"modulate:a",
			0,
			in_time
		).finished

func _apply_background(target_background: BackgroundData, variation_name: String) -> void:
	var target_texture: Texture2D = target_background.variations[variation_name]
	current_background = "%s-%s" % [target_background.title, variation_name]
	Game.phone_page.label_location.text = target_background.location
	Game.stage_page.texture_rect_background.texture = target_texture
	clear_characters()
	HideDialogue(0)

func PrepareBackground(background_name: String, variation_name: String) -> void:
	Game.stage_page.stop_background_performance()
	Game.stage_page.stop_opening_effects(false)
	var target_background: BackgroundData = background_data_pool.filter(
		func (background: BackgroundData):
			return background.title == background_name
	).front()
	if not target_background:
		push_warning("PrepareBackground: 未找到背景 %s" % background_name)
		return
	_apply_background(target_background, variation_name)
	Game.stage_page.texture_rect_blackscreen.modulate.a = 1.0

func SetCG(cg_name: String, variation_name: String) -> void:
	Game.stage_page.stop_background_performance()
	Game.stage_page.stop_opening_effects()
	var target_gallery: GalleryData = gallery_data_pool.filter(
		func(g: GalleryData): return g.resource_path.get_file().replace(".tres", "") == cg_name
	).front()
	if not target_gallery:
		push_warning("SetCG: 未找到 gallery %s" % cg_name)
		return
	Main.unlock_cg(cg_name)

	# 同一CG切换差分：直接换贴图，不走过渡
	if current_cg == cg_name:
		var var_texture: Texture2D
		for v in target_gallery.variation:
			if v.resource_path.get_file().replace(".tres", "") == variation_name:
				var_texture = v
				break
		Game.stage_page.texture_rect_variation.texture = var_texture
		current_cg_variation = variation_name
		return

	# 切换到不同CG：黑屏过渡
	var is_skip: bool = Game.stage_page.skip
	var skip_trans: bool = is_skip and Main.setting_data.skip_ignore_transitions

	if is_skip and not skip_trans:
		Game.stage_page._set_mode(Game.stage_page.AdvanceMode.MANUAL)
		Game.stage_page.skip_cancelled.emit()

	if skip_trans:
		Game.stage_page.texture_rect_blackscreen.modulate.a = 1
	else:
		await create_tween().tween_property(
			Game.stage_page.texture_rect_blackscreen,
			"modulate:a",
			1,
			1.2
		).finished

	current_cg = cg_name
	current_cg_variation = variation_name
	Game.stage_page.texture_rect_cg.texture = target_gallery.base
	var var_texture: Texture2D
	for v in target_gallery.variation:
		if v.resource_path.get_file().replace(".tres", "") == variation_name:
			var_texture = v
			break
	Game.stage_page.texture_rect_variation.texture = var_texture
	Game.stage_page.texture_rect_cg.visible = true
	# Q版等小CG按数据里的倍率缩小、居中，并可上移避开 UI（base 与差分同属一节点，会一起变换）
	_apply_cg_transform(target_gallery.cg_scale, target_gallery.cg_offset_y)
	clear_characters()
	HideDialogue(0)

	if skip_trans:
		Game.stage_page.texture_rect_blackscreen.modulate.a = 0
	else:
		await create_tween().tween_property(
			Game.stage_page.texture_rect_blackscreen,
			"modulate:a",
			0,
			1.2
		).finished

func _apply_cg_transform(cg_scale: float, offset_y: float) -> void:
	var cg_rect: TextureRect = Game.stage_page.texture_rect_cg
	cg_rect.pivot_offset = cg_rect.size * 0.5
	cg_rect.scale = Vector2.ONE if cg_scale <= 0.0 else Vector2(cg_scale, cg_scale)
	# 在缩放居中基础上整体垂直偏移（负值向上），保持水平居中
	cg_rect.position = Vector2(0.0, offset_y)

func HideCG() -> void:
	Game.stage_page.stop_background_performance()
	Game.stage_page.stop_opening_effects()
	var is_skip: bool = Game.stage_page.skip
	var skip_trans: bool = is_skip and Main.setting_data.skip_ignore_transitions

	if is_skip and not skip_trans:
		Game.stage_page._set_mode(Game.stage_page.AdvanceMode.MANUAL)
		Game.stage_page.skip_cancelled.emit()

	if skip_trans:
		Game.stage_page.texture_rect_blackscreen.modulate.a = 1
	else:
		await create_tween().tween_property(
			Game.stage_page.texture_rect_blackscreen,
			"modulate:a",
			1,
			1.2
		).finished

	Game.stage_page.texture_rect_cg.visible = false
	Game.stage_page.texture_rect_cg.texture = null
	Game.stage_page.texture_rect_cg.scale = Vector2.ONE
	Game.stage_page.texture_rect_cg.pivot_offset = Vector2.ZERO
	Game.stage_page.texture_rect_cg.position = Vector2(0, 0)
	Game.stage_page.texture_rect_variation.texture = null
	current_cg = ""
	current_cg_variation = ""

	if skip_trans:
		Game.stage_page.texture_rect_blackscreen.modulate.a = 0
	else:
		await create_tween().tween_property(
			Game.stage_page.texture_rect_blackscreen,
			"modulate:a",
			0,
			1.2
		).finished

func clear_characters() -> void:
	Tools.clear_children(Game.stage_page.character_image_pool)
	for character in character_array:
		character.character_image = null
		character.current_position = ""

func Travel() -> void:
	Game.travel_page.visible = true
	await Game.travel_page.visibility_changed

func SetDate(month: int, day: int, week_day: String) -> void:
	var date_key := "%02d-%02d-%s" % [month, day, week_day]
	if current_date == date_key:
		return
	current_date = date_key
	var month_str = str(month).pad_zeros(2)
	var day_str = str(day).pad_zeros(2)
	Game.phone_page.label_phone_date.text = "%s/%s" % [month_str, day_str]
	Game.phone_page.label_time.text = week_day
	Game.stage_page.label_month.text = month_str
	Game.stage_page.label_day.text = day_str
	Game.stage_page.label_week_day.text = week_day
	var date_control = Game.stage_page.date
	date_control.modulate.a = 0
	await create_tween().tween_property(date_control, "modulate:a", 1, 1).finished
	await get_tree().create_timer(3.0).timeout
	await create_tween().tween_property(date_control, "modulate:a", 0, 1).finished

func SetMusic(music_name: String) -> void:
	var track_data: MusicData = AudioManager.playlist.filter(
		func(m: MusicData): return m.title == music_name
	).front()
	if not track_data:
		return
	# 如果已经在播同一首就不重复
	if AudioManager._music_source == AudioManager.MusicSource.PLAYLIST \
		and AudioManager.audio_player_music.stream == track_data.track \
		and AudioManager.audio_player_music.playing:
		return
	# fade out 当前音乐，但不阻塞对话推进
	if AudioManager.audio_player_music.playing:
		var saved_db := AudioManager.audio_player_music.volume_db
		var tween := create_tween()
		tween.tween_property(
			AudioManager.audio_player_music, "volume_db", -80.0, 2.0
		).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
		tween.tween_callback(
			func():
				AudioManager.audio_player_music.stop()
				AudioManager.audio_player_music.volume_db = saved_db
				AudioManager.track_index = AudioManager.playlist.find(track_data)
				AudioManager.play_track()
		)
		return
	AudioManager.track_index = AudioManager.playlist.find(track_data)
	AudioManager.play_track()

func StopMusic() -> void:
	if not AudioManager.audio_player_music.playing:
		return
	var saved_db := AudioManager.audio_player_music.volume_db
	var tween := create_tween()
	tween.tween_property(
		AudioManager.audio_player_music, "volume_db", -80.0, 2.0
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
	tween.tween_callback(
		func():
			AudioManager.audio_player_music.stop()
			AudioManager.audio_player_music.volume_db = saved_db
	)

func HideDialogue(duration: float = 0.4) -> void:
	AudioManager.audio_player_voice.stop()
	Game.stage_page.reset_dialogue_ui_hidden()
	if Game.stage_page.dialogue_screen.modulate.a > 0:
		if duration > 0:
			await create_tween().tween_property(
				Game.stage_page.dialogue_screen, "modulate:a", 0.0, duration
			).finished
		else:
			Game.stage_page.dialogue_screen.modulate.a = 0
	Game.stage_page.avatar.texture = null  # 淡出后再清头像，防止下次显示时闪现旧头像

func ShowDialogue(duration: float = 0.4) -> void:
	var sp = Game.stage_page
	sp.reset_dialogue_ui_hidden()
	# 先更新状态再呈现
	sp.label_character_name.text = sp.dialogue_line.get_tag_value("昵称") \
		if sp.dialogue_line.has_tag("昵称") else sp.dialogue_line.character
	sp.dialogue_label.text = ""
	sp.dialogue_label.visible_characters = 0
	sp.voice_buttons.visible = sp.dialogue_line.has_tag("语音")
	if sp.dialogue_screen.modulate.a < 1:
		if duration > 0:
			await create_tween().tween_property(
				sp.dialogue_screen, "modulate:a", 1.0, duration
			).finished
		else:
			sp.dialogue_screen.modulate.a = 1

func PlaySFX(sound_name: String, wait_for_finish: bool = false) -> void:
	await AudioManager.play_sound_by_name(sound_name, wait_for_finish)

func RevealBackgroundWithBlur(black_fade_time: float = 0.8,
		blur_fade_time: float = 1.2, blur_amount: float = 8.0) -> void:
	var is_skip: bool = Game.stage_page.skip
	var skip_trans: bool = is_skip and Main.setting_data.skip_ignore_transitions
	if skip_trans:
		Game.stage_page.stop_opening_effects()
		Game.stage_page.texture_rect_blackscreen.modulate.a = 0.0
		return
	if is_skip:
		Game.stage_page._set_mode(Game.stage_page.AdvanceMode.MANUAL)
		Game.stage_page.skip_cancelled.emit()
	await Game.stage_page.play_blur_reveal(black_fade_time, blur_fade_time, blur_amount)

func PerformBackgroundPan(scale_multiplier: float, segments: Array) -> void:
	if segments.is_empty():
		Game.stage_page.stop_background_performance()
		return
	var is_skip: bool = Game.stage_page.skip
	var skip_trans: bool = is_skip and Main.setting_data.skip_ignore_transitions
	if skip_trans:
		Game.stage_page.stop_background_performance()
		return
	if is_skip:
		Game.stage_page._set_mode(Game.stage_page.AdvanceMode.MANUAL)
		Game.stage_page.skip_cancelled.emit()
	Game.stage_page.play_background_performance.call_deferred(scale_multiplier, segments)

func StopBackgroundPerformance(fade_duration: float = 0.8) -> void:
	await Game.stage_page.stop_background_performance(true, fade_duration)

func ShowPhone() -> void:
	var initial_chat_character := ""
	if Game.stage_page.dialogue_line:
		var next_line = await Game.stage_page.dialogue.get_next_dialogue_line(
			Game.stage_page.dialogue_line.next_id,
			[Game.stage_page, Stage],
			DMConstants.MutationBehaviour.Skip
		)
		if next_line and "手机" in next_line.tags and next_line.character != "周腾":
			initial_chat_character = next_line.character
	await Game.phone_page.open(true, initial_chat_character)

func HidePhone() -> void:
	await Game.phone_page.close()

func OpenBook() -> void:
	await Game.switch_to_page(Game.book_page, true, true)

func CloseBook() -> void:
	if Game.book_page.visible:
		await Game.go_back()

func WriteBook(entry_id: String, speaker: String, text: String, side: String = "", tags: Array[String] = []) -> void:
	await Game.book_page.append_entry(entry_id, speaker, text, side, tags)

#endregion
