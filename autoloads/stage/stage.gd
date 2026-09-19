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
## 当前章节在演出表里的「章节」与「标题」（由 ShowChapterInfo 写入），收藏语音时要用
var current_chapter_designation: String = ""
var current_chapter_title: String = ""

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

# ─── 黑屏过渡 ───

## 转场前置：按 skip 状态决定这次过渡要不要被忽略。
## 返回 true 表示「忽略转场」已开，调用方应直接赋值、不补间。
func _begin_black_transition() -> bool:
	var is_skip: bool = Game.stage_page.skip
	var skip_trans: bool = is_skip and Main.setting_data.skip_ignore_transitions
	if is_skip and not skip_trans:
		Game.stage_page._set_mode(Game.stage_page.AdvanceMode.MANUAL)
		Game.stage_page.skip_cancelled.emit()
	if skip_trans:
		Game.stage_page.texture_rect_blackscreen.modulate.a = 1
	return skip_trans

## 黑屏层淡到指定 alpha（1 = 全黑）；skip_trans 时直接赋值
func _fade_blackscreen_to(target_alpha: float, duration: float, skip_trans: bool) -> void:
	if skip_trans:
		Game.stage_page.texture_rect_blackscreen.modulate.a = target_alpha
		return
	await create_tween().tween_property(
		Game.stage_page.texture_rect_blackscreen,
		"modulate:a",
		target_alpha,
		duration
	).finished

## 换背景本体（不含过渡）；找不到背景只警告，不动画面
func _set_background_by_name(background_name: String, variation_name: String) -> void:
	var target_background: BackgroundData = background_data_pool.filter(
		func (background: BackgroundData):
			return background.title == background_name
	).front()
	if not target_background:
		push_warning("SetBackground: 未找到背景 %s" % background_name)
		return
	_apply_background(target_background, variation_name)

## 收掉 CG 本体（不含过渡）
func _clear_cg_now() -> void:
	Game.stage_page.texture_rect_cg.visible = false
	Game.stage_page.texture_rect_cg.texture = null
	Game.stage_page.texture_rect_cg.scale = Vector2.ONE
	Game.stage_page.texture_rect_cg.pivot_offset = Vector2.ZERO
	Game.stage_page.texture_rect_cg.position = Vector2(0, 0)
	Game.stage_page.texture_rect_variation.texture = null
	current_cg = ""
	current_cg_variation = ""

## 收 CG 的同时换背景：两个改动合进同一次黑屏过渡。
## 拆成 SetBackground + HideCG 两条会连出两次转场，而第一次换的背景被 CG 盖着看不见，看着像没反应。
func HideCGWithBackground(background_name: String, variation_name: String,
		out_time: float = 1.2, in_time: float = 1.2) -> void:
	Game.stage_page.stop_background_performance()
	Game.stage_page.stop_opening_effects()
	var skip_trans := _begin_black_transition()
	await _fade_blackscreen_to(1.0, out_time, skip_trans)
	_set_background_by_name(background_name, variation_name)
	_clear_cg_now()
	# 同上：收 CG 的这条合并命令也自己负责收对话框
	await HideDialogue(0)
	await _fade_blackscreen_to(0.0, in_time, skip_trans)

func SetBackground(background_name: String, variation_name: String,
		out_time: float = 1.2, in_time: float = 1.2) -> void:
	Game.stage_page.stop_background_performance()
	Game.stage_page.stop_opening_effects()
	var skip_trans := _begin_black_transition()
	await _fade_blackscreen_to(1.0, out_time, skip_trans)
	_set_background_by_name(background_name, variation_name)
	await _fade_blackscreen_to(0.0, in_time, skip_trans)

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
	var skip_trans := _begin_black_transition()
	await _fade_blackscreen_to(1.0, 1.2, skip_trans)

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

	await _fade_blackscreen_to(0.0, 1.2, skip_trans)

func _apply_cg_transform(cg_scale: float, offset_y: float) -> void:
	var cg_rect: TextureRect = Game.stage_page.texture_rect_cg
	cg_rect.pivot_offset = cg_rect.size * 0.5
	cg_rect.scale = Vector2.ONE if cg_scale <= 0.0 else Vector2(cg_scale, cg_scale)
	# 在缩放居中基础上整体垂直偏移（负值向上），保持水平居中
	cg_rect.position = Vector2(0.0, offset_y)

func HideCG() -> void:
	Game.stage_page.stop_background_performance()
	Game.stage_page.stop_opening_effects()
	var skip_trans := _begin_black_transition()
	await _fade_blackscreen_to(1.0, 1.2, skip_trans)
	_clear_cg_now()
	# 收 CG 由 CG 自己负责对话框：先收起来 + 清空文本，等下一句文本就位后再显示
	await HideDialogue(0)
	await _fade_blackscreen_to(0.0, 1.2, skip_trans)

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

## 章节过场：由导出脚本写在每章第一句之前（`$> ShowChapterInfo("章节1", "初雪")`）。
## 预制体没挂上时直接返回，保证对话不会卡在这里。
func ShowChapterInfo(chapter: String, chapter_title: String) -> void:
	# 先记下来：语音收藏的章节号/章节名要用（过场缺失时也得记）
	current_chapter_designation = chapter
	current_chapter_title = chapter_title
	if Game.chapter_transition == null:
		push_warning("[Stage] chapter_transition 未挂载，跳过章节过场")
		return
	await Game.chapter_transition.play(chapter, chapter_title)

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
	# fade out 当前音乐（3 秒），但不阻塞对话推进
	if AudioManager.audio_player_music.playing:
		var saved_db := AudioManager.audio_player_music.volume_db
		var tween := create_tween()
		tween.tween_property(
			AudioManager.audio_player_music, "volume_db", -80.0, 3.0
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
	# 收起对话框时顺手擦掉旧文本，并约定「等下一句文本就位再显示」：
	# 否则脚本里稍后的 ShowDialogue() 会把上一句的角色名 + 空文本先露出来
	Game.stage_page.begin_dialogue_ui_awaiting_text()

func ShowDialogue(duration: float = 0.4) -> void:
	var sp = Game.stage_page
	# 刚收过 CG/过场，约定等下一句文本就位再显示：这次先不放出来（下一句
	# process_dialogue_line 会再调一次），免得露出上一句的角色名和空文本
	if sp.is_dialogue_ui_awaiting_text():
		return
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
