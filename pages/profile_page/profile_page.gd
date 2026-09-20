class_name ProfilePage
extends CanvasLayer

@export var profile_card_model: ProfileCard
@export var title_load: TextureRect
@export var title_save: TextureRect
@export var profile_card_pool: GridContainer

signal profile_index_changed
var profile_index: int = -1:
	set(value):
		profile_index = value
		profile_index_changed.emit()

var selected_card: ProfileCard:
	set(value):
		selected_card = value
		profile_index = value.slot_index if value else -1

func _ready() -> void:
	visibility_changed.connect(
		func ():
			title_load.visible = Main.profile_mode == Main.ProfileMode.LOAD
			title_save.visible = Main.profile_mode == Main.ProfileMode.SAVE
			if visible:
				update()
	)

var save_thread: Thread
var _queued_quick_save: bool = false

func update() -> void:
	Tools.clear_children(profile_card_pool)
	selected_card = null
	profile_card_pool.add_child(_make_card(ProfileCard.SlotKind.QUICK, -1, Main.save_data.auto_profile, "QUICK"))
	for i in Main.save_data.profiles.size():
		var profile = Main.save_data.profiles[i]
		var profile_card := _make_card(ProfileCard.SlotKind.MANUAL, i, profile, "NO.%02d" % [i + 1])
		profile_card_pool.add_child(profile_card)
	if Main.profile_mode == Main.ProfileMode.SAVE:
		profile_card_pool.add_child(_make_card(ProfileCard.SlotKind.NEW_MANUAL, Main.save_data.profiles.size(), null, "NO.%02d" % [Main.save_data.profiles.size() + 1]))
	# 记卡片数：界面"点不动"时先看这里——0 张说明卡片根本没建出来（不是点击被吃掉）
	print("[UI] 存读档页刷新完成（%s）卡片 %d 张 → %s" % [
		"存档" if Main.profile_mode == Main.ProfileMode.SAVE else "读档",
		profile_card_pool.get_child_count(), Game.describe_state()])

func _make_card(slot_kind: ProfileCard.SlotKind, slot_index: int, profile: ProfileData, index_text: String) -> ProfileCard:
	var profile_card: ProfileCard = profile_card_model.duplicate()
	profile_card.slot_kind = slot_kind
	profile_card.slot_index = slot_index
	profile_card.label_index.text = index_text
	profile_card.button_delete.visible = slot_kind == ProfileCard.SlotKind.MANUAL or (slot_kind == ProfileCard.SlotKind.QUICK and has_quick_save())
	profile_card.texture_rect_preview.texture = profile.preview if profile and profile.preview else profile_card.texture_rect_preview.texture
	if profile and profile.chapter_name != "":
		# 序号/章节名用存档里记的 chapter_designation / chapter_title（演出表里写的"第一话 / 初雪"那种）；
		# 老存档（或没经过 ShowChapterInfo 存的档）这两个字段是空的，才退回对话文件名
		profile_card.label_chapter.text = profile.chapter_designation if profile.chapter_designation != "" \
			else profile.chapter_name.to_upper().replace("_", " ")
		profile_card.label_chapter_title.text = profile.chapter_title if profile.chapter_title != "" \
			else profile.chapter_name
	else:
		profile_card.label_chapter.text = "EMPTY"
		profile_card.label_chapter_title.text = "暂无存档" if slot_kind != ProfileCard.SlotKind.NEW_MANUAL else "新存档"
	return profile_card

func _capture_runtime_snapshot() -> Dictionary:
	var image = Game.stage_page.subviewport.get_texture().get_image()
	image.resize(470, 265, Image.INTERPOLATE_NEAREST)
	var character_datas: Array[CharacterData] = []
	for character_image: Control in Game.stage_page.character_image_pool.get_children():
		for character: Character in Stage.character_array:
			if character.character_image == character_image:
				character_datas.append(character.get_character_data())
				break
	var apm = AudioManager.audio_player_music
	return {
		"preview": ImageTexture.create_from_image(image),
		"dialogue_id": Game.stage_page.dialogue_line.next_id if Game.stage_page.dialogue_line else "start",
		"book_segment_start_id": Game.stage_page.current_book_segment_start_id,
		"chapter_name": Game.stage_page.chapter_name if Game.stage_page.dialogue else "",
		"chapter_designation": Stage.current_chapter_designation,
		"chapter_title": Stage.current_chapter_title,
		"character_datas": character_datas,
		"background": Stage.current_background,
		"cg_name": Stage.current_cg,
		"cg_variation": Stage.current_cg_variation,
		"chat_datas": Game.phone_page.chat_data_pool.duplicate(true),
		"active_chat_character": Game.phone_page.active_chat_character,
		"log_datas": Game.log_page.log_data_pool.duplicate(true),
		"notebook_data": Game.book_page.duplicate_notebook_data(),
		"book_open": Game.book_page.visible,
		"music_path": apm.stream.resource_path if apm.playing else "",
		"music_position": apm.get_playback_position() if apm.playing else 0.0,
		"music_source": AudioManager._music_source if apm.playing else AudioManager.MusicSource.NONE,
		"quick_save_progress_count": Game.stage_page.quick_save_progress_count,
	}

func _apply_snapshot_to_profile(profile: ProfileData, snapshot: Dictionary) -> void:
	profile.preview = snapshot.preview
	profile.dialogue_id = snapshot.dialogue_id
	profile.book_segment_start_id = snapshot.book_segment_start_id
	profile.chapter_name = snapshot.chapter_name if snapshot.chapter_name != "" else (Game.stage_page.chapter_name if Game.stage_page.dialogue else "")
	profile.chapter_designation = snapshot.chapter_designation
	profile.chapter_title = snapshot.chapter_title
	profile.character_datas = snapshot.character_datas
	profile.background = snapshot.background
	profile.cg_name = snapshot.cg_name
	profile.cg_variation = snapshot.cg_variation
	profile.chat_datas = snapshot.chat_datas
	profile.active_chat_character = snapshot.active_chat_character
	profile.log_datas = snapshot.log_datas
	profile.notebook_data = snapshot.notebook_data
	profile.book_open = snapshot.book_open
	profile.music_path = snapshot.music_path
	profile.music_position = snapshot.music_position
	profile.music_source = snapshot.music_source
	profile.quick_save_progress_count = snapshot.quick_save_progress_count
	profile.last_saved_at_unix_ms = int(Time.get_unix_time_from_system() * 1000.0)

func _ensure_manual_profile(index: int) -> ProfileData:
	while Main.save_data.profiles.size() <= index:
		Main.save_data.profiles.append(ProfileData.new())
	return Main.save_data.profiles[index]

func _save_profile(profile: ProfileData, show_loading: bool) -> void:
	if save_thread and save_thread.is_started():
		if not show_loading:
			_queued_quick_save = true
		return
	if show_loading:
		Game.loading = true
		Game.loading_page.show()
		Game.loading_page.layer = 100
	var snapshot := _capture_runtime_snapshot()
	save_thread = Thread.new()
	save_thread.start(
		func():
			_apply_snapshot_to_profile(profile, snapshot)
			ResourceSaver.save(Main.save_data, Main.save_path)
			(
				func():
					save_thread.wait_to_finish()
					save_thread = null
					if show_loading:
						Game.loading = false
						Game.loading_page.hide()
					update()
					if _queued_quick_save:
						_queued_quick_save = false
						save_quick_game()
			).call_deferred()
	)

## UI 日志：卡片/自动保存/继续 都会走到这些入口，记一行动作 + 之后的状态
func _log_ui(action: String) -> void:
	print("[UI] %s → %s" % [action, Game.describe_state()])

func save_game() -> void:
	_log_ui("存档 NO.%02d" % [profile_index + 1])
	_save_profile(_ensure_manual_profile(profile_index), true)

# 存档查询都在 Main 上（纯数据）：主菜单刷新按钮那类自动路径会调，
# 不能为了问一句「有没有存档」就把存档页建出来
func has_quick_save() -> bool:
	return Main.is_profile_usable(Main.save_data.auto_profile)

func _is_profile_usable(profile: ProfileData) -> bool:
	return Main.is_profile_usable(profile)

func get_latest_manual_profile() -> ProfileData:
	return Main.get_latest_manual_profile()

func get_continue_profile() -> ProfileData:
	return Main.get_continue_profile()

func has_continue_save() -> bool:
	return Main.has_continue_save()

func load_continue_game() -> void:
	var profile := get_continue_profile()
	if profile:
		_log_ui("继续游戏（%s）" % ["快速存档" if profile == Main.save_data.auto_profile else "最新手动档"])
		load_profile(profile)

func save_quick_game() -> void:
	_log_ui("快速存档（含每 20 句自动）")
	if Main.save_data.auto_profile == null:
		Main.save_data.auto_profile = ProfileData.new()
	_save_profile(Main.save_data.auto_profile, false)

func load_game() -> void:
	if profile_index < 0 or profile_index >= Main.save_data.profiles.size():
		return
	load_profile(Main.save_data.profiles[profile_index])

func load_quick_game() -> void:
	if Main.save_data.auto_profile == null:
		return
	_log_ui("读档（快速存档）")
	load_profile(Main.save_data.auto_profile)

func refresh_continue_state_after_save_mutation() -> void:
	if Game.main_menu:
		Game.main_menu._update_start_button()
	if Game.stage_page in Game.page_stack:
		return
	var continue_profile := get_continue_profile()
	if continue_profile:
		Game.book_page.restore_notebook_data(continue_profile.notebook_data)
	else:
		Game.book_page.reset_notebook()

func load_profile(profile: ProfileData) -> void:
	if not _is_profile_usable(profile):
		return
	await Game.switch_to_page(Game.stage_page, true, false,
		func():
			Game.stage_page.reset()
			# 读档不会经过 ShowChapterInfo，章节信息从存档恢复（语音收藏的章节号/名要用）
			Stage.current_chapter_designation = profile.chapter_designation
			Stage.current_chapter_title = profile.chapter_title
			if profile.chapter_name != "" and Game.stage_page.chapters_dict.has(profile.chapter_name):
				Game.stage_page.dialogue = Game.stage_page.chapters_dict[profile.chapter_name]
			Game.stage_page.quick_save_progress_count = profile.quick_save_progress_count
			if profile.background != "":
				var background_split = profile.background.split("-")
				if background_split.size() >= 2:
					var background_name = background_split[0]
					var variation_name = background_split[1]
					var target_background: BackgroundData = Stage.find_background(background_name)
					if target_background:
						Game.stage_page.texture_rect_background.texture = target_background.variations[variation_name]
						Stage.current_background = profile.background
						Game.phone_page.label_location.text = target_background.location
			Game.stage_page.stop_background_performance()
			Game.stage_page.stop_opening_effects()
			if profile.cg_name != "" and profile.cg_variation != "":
				var target_gallery: GalleryData = Stage.find_gallery(profile.cg_name)
				if target_gallery:
					Game.stage_page.texture_rect_cg.texture = target_gallery.base
					var var_texture: Texture2D
					for v in target_gallery.variation:
						if v.resource_path.get_file().replace(".tres", "") == profile.cg_variation:
							var_texture = v
							break
					Game.stage_page.texture_rect_variation.texture = var_texture
					Game.stage_page.texture_rect_cg.visible = true
					# 读档恢复 Q版等小CG时也要应用缩放+偏移，和剧情内 SetCG 表现一致
					Stage._apply_cg_transform(target_gallery.cg_scale, target_gallery.cg_offset_y)
					Stage.current_cg = profile.cg_name
					Stage.current_cg_variation = profile.cg_variation
			for character_data: CharacterData in profile.character_datas:
				var character = Stage.Character(character_data.character_name)
				character.set_character_data(character_data)
				if character_data.position:
					character.character_image = character.story_model.duplicate()
					Game.stage_page.character_image_pool.add_child(character.character_image)
					character.character_image.show()
			Character.redistribute_stage_characters(true)
			Game.phone_page.chat_data_pool = profile.chat_datas.duplicate(true)
			Game.phone_page.active_chat_character = profile.active_chat_character
			Game.phone_page.reload_active_chat()
			Game.log_page._suppressed = true
			Game.log_page.restore(profile.log_datas.duplicate(true))
			if profile.music_path != "":
				var apm = AudioManager.audio_player_music
				apm.stream = load(profile.music_path)
				apm.play(profile.music_position)
				AudioManager._music_source = profile.music_source
			var resume_key := profile.dialogue_id if profile.dialogue_id != "" else "start"
			var book_resume_key := profile.book_segment_start_id if profile.book_segment_start_id != "" else resume_key
			var resume_probe_line: DialogueLine = await Game.stage_page.dialogue.get_next_dialogue_line(resume_key, [Game.stage_page, Stage], DMConstants.MutationBehaviour.Skip)
			var resume_in_book: bool = resume_probe_line != null and "奇迹书" in resume_probe_line.tags
			if not resume_in_book:
				Game.stage_page.dialogue_line = await Game.stage_page.dialogue.get_next_dialogue_line(resume_key, [Game.stage_page, Stage])
				await Game.book_page.restore_notebook_data(profile.notebook_data)
			else:
				await Game.book_page.restore_notebook_data(profile.notebook_data)
				await Game.book_page.trim_notebook_from_dialogue_id(profile.book_segment_start_id)
				Game.stage_page.current_book_segment_start_id = profile.book_segment_start_id
			Game.log_page._suppressed = false
	)
	_log_ui("读档完成（章节=%s 行=%s）" % [
		profile.chapter_name,
		Game.stage_page.dialogue_line.id if Game.stage_page.dialogue_line else "<无>"])
	if profile.book_open:
		await Game.switch_to_page(Game.book_page, true, true)
		if Game.stage_page.dialogue_line and "奇迹书" not in Game.stage_page.dialogue_line.tags:
			await Game.book_page.restore_notebook_data(profile.notebook_data)
		elif Game.stage_page.dialogue and profile.book_segment_start_id != "":
			Game.stage_page.dialogue_line = await Game.stage_page.dialogue.get_next_dialogue_line(profile.book_segment_start_id, [Game.stage_page, Stage])
		if Game.stage_page.dialogue_line and Game.stage_page.dialogue_line.responses:
			Game.book_page.show_reply_options(Game.stage_page.dialogue_line.responses)
	else:
		if Game.stage_page.dialogue_line and "奇迹书" not in Game.stage_page.dialogue_line.tags:
			await Game.book_page.restore_notebook_data(profile.notebook_data)
