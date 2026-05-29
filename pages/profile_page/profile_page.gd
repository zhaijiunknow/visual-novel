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

func _make_card(slot_kind: ProfileCard.SlotKind, slot_index: int, profile: ProfileData, index_text: String) -> ProfileCard:
	var profile_card: ProfileCard = profile_card_model.duplicate()
	profile_card.slot_kind = slot_kind
	profile_card.slot_index = slot_index
	profile_card.label_index.text = index_text
	profile_card.button_delete.visible = false
	profile_card.texture_rect_preview.texture = profile.preview if profile and profile.preview else profile_card.texture_rect_preview.texture
	if profile and profile.chapter_name != "":
		profile_card.label_chapter.text = profile.chapter_name.to_upper().replace("_", " ")
		profile_card.label_chapter_title.text = profile.chapter_name
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
		"dialogue_id": Game.stage_page.dialogue_line.id if Game.stage_page.dialogue_line else "",
		"chapter_name": Game.stage_page.chapter_name if Game.stage_page.dialogue else "",
		"character_datas": character_datas,
		"background": Stage.current_background,
		"cg_name": Stage.current_cg,
		"cg_variation": Stage.current_cg_variation,
		"chat_datas": Game.phone_page.chat_data_pool.duplicate(true),
		"active_chat_character": Game.phone_page.active_chat_character,
		"log_datas": Game.log_page.log_data_pool.duplicate(true),
		"notebook_data": Game.book_page.duplicate_notebook_data(),
		"music_path": apm.stream.resource_path if apm.playing else "",
		"music_position": apm.get_playback_position() if apm.playing else 0.0,
		"music_source": AudioManager._music_source if apm.playing else AudioManager.MusicSource.NONE,
		"quick_save_progress_count": Game.stage_page.quick_save_progress_count,
	}

func _apply_snapshot_to_profile(profile: ProfileData, snapshot: Dictionary) -> void:
	profile.preview = snapshot.preview
	profile.dialogue_id = snapshot.dialogue_id
	profile.chapter_name = snapshot.chapter_name
	profile.character_datas = snapshot.character_datas
	profile.background = snapshot.background
	profile.cg_name = snapshot.cg_name
	profile.cg_variation = snapshot.cg_variation
	profile.chat_datas = snapshot.chat_datas
	profile.active_chat_character = snapshot.active_chat_character
	profile.log_datas = snapshot.log_datas
	profile.notebook_data = snapshot.notebook_data
	profile.music_path = snapshot.music_path
	profile.music_position = snapshot.music_position
	profile.music_source = snapshot.music_source
	profile.quick_save_progress_count = snapshot.quick_save_progress_count

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

func save_game() -> void:
	_save_profile(_ensure_manual_profile(profile_index), true)

func has_quick_save() -> bool:
	return Main.save_data.auto_profile != null and Main.save_data.auto_profile.chapter_name != ""

func save_quick_game() -> void:
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
	load_profile(Main.save_data.auto_profile)

func load_profile(profile: ProfileData) -> void:
	if profile == null or profile.chapter_name == "" or not Game.stage_page.chapters_dict.has(profile.chapter_name):
		return
	Game.switch_to_page(Game.stage_page, true, false,
		func():
			Game.stage_page.reset()
			Game.stage_page.dialogue = Game.stage_page.chapters_dict[profile.chapter_name]
			Game.stage_page.quick_save_progress_count = profile.quick_save_progress_count
			if profile.background != "":
				var background_split = profile.background.split("-")
				if background_split.size() >= 2:
					var background_name = background_split[0]
					var variation_name = background_split[1]
					var target_background: BackgroundData = Stage.background_data_pool.filter(
						func(bg: BackgroundData): return bg.title == background_name
					).front()
					if target_background:
						Game.stage_page.texture_rect_background.texture = target_background.variations[variation_name]
						Stage.current_background = profile.background
						Game.phone_page.label_location.text = target_background.location
			if profile.cg_name != "" and profile.cg_variation != "":
				var target_gallery: GalleryData = Stage.gallery_data_pool.filter(
					func(g: GalleryData): return g.resource_path.get_file().replace(".tres", "") == profile.cg_name
				).front()
				if target_gallery:
					Game.stage_page.texture_rect_cg.texture = target_gallery.base
					var var_texture: Texture2D
					for v in target_gallery.variation:
						if v.resource_path.get_file().replace(".tres", "") == profile.cg_variation:
							var_texture = v
							break
					Game.stage_page.texture_rect_variation.texture = var_texture
					Game.stage_page.texture_rect_cg.visible = true
					Stage.current_cg = profile.cg_name
					Stage.current_cg_variation = profile.cg_variation
			for character_data: CharacterData in profile.character_datas:
				var character = Stage.Character(character_data.character_name)
				character.set_character_data(character_data)
				if character_data.position:
					character.character_image = character.story_model.duplicate()
					Game.stage_page.character_image_pool.add_child(character.character_image)
					character.character_image.show()
			var pool = Game.stage_page.character_image_pool
			var character_count = pool.get_child_count()
			if character_count > 0:
				var width = pool.size.x
				var portion_width = width / character_count
				var offset_x = portion_width / 2
				for image: Control in pool.get_children():
					var position_x = image.get_index() * portion_width + offset_x
					image.position = Vector2(position_x, 0)
			Game.phone_page.chat_data_pool = profile.chat_datas.duplicate(true)
			Game.phone_page.active_chat_character = profile.active_chat_character
			Game.phone_page.reload_active_chat()
			Game.log_page._suppressed = true
			Game.log_page.restore(profile.log_datas.duplicate(true))
			Game.book_page.restore_notebook_data(profile.notebook_data)
			if profile.music_path != "":
				var apm = AudioManager.audio_player_music
				apm.stream = load(profile.music_path)
				apm.play(profile.music_position)
				AudioManager._music_source = profile.music_source
			Game.stage_page.dialogue_line = await Game.stage_page.dialogue.get_next_dialogue_line(profile.dialogue_id)
			Game.log_page._suppressed = false
	)
