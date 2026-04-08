class_name ProfilePage
extends CanvasLayer

@export var profile_card_model: ProfileCard
@export var title_load: TextureRect
@export var title_save: TextureRect
@export var profile_card_pool: GridContainer

signal profile_index_changed
var profile_index: int:
	set(value):
		profile_index = value
		profile_index_changed.emit()

func _ready() -> void:	
	visibility_changed.connect(
		func ():
			title_load.visible = Main.profile_mode == Main.ProfileMode.LOAD
			title_save.visible = Main.profile_mode == Main.ProfileMode.SAVE
			if visible:
				update()
	)

var save_thread: Thread

func update() -> void:
	Tools.clear_children(profile_card_pool)
	for profile in Main.save_data.profiles:
		var profile_card: ProfileCard = profile_card_model.duplicate()
		profile_card.texture_rect_preview.texture = profile.preview
		profile_card_pool.add_child(profile_card)
		profile_card.label_index.text = "NO.%02d" % [profile_card.get_index() + 1]
	if Main.profile_mode == Main.ProfileMode.SAVE:
		profile_card_pool.add_child(profile_card_model.duplicate())

func save_game() -> void:
	save_thread = Thread.new()
	Game.loading = true
	Game.loading_page.show()
	Game.loading_page.layer = 100
	var _texture = Game.stage_page.subviewport.get_texture()
	var image = _texture.get_image()
	# 按 character_image_pool 的子节点顺序保存，确保读档时顺序一致
	var character_datas: Array[CharacterData] = []
	for character_image: Control in Game.stage_page.character_image_pool.get_children():
		for character: Character in Stage.character_array:
			if character.character_image == character_image:
				character_datas.append(character.get_character_data())
				break
	save_thread.start(
		func():
			image.resize(470, 265, Image.INTERPOLATE_NEAREST)
			var resized_texture = ImageTexture.create_from_image(image)
			if Main.save_data.profiles.size() <= profile_index:
				Main.save_data.profiles.insert(profile_index, ProfileData.new())
			var profile = Main.save_data.profiles[profile_index]
			profile.preview = resized_texture
			profile.dialogue_id = Game.stage_page.dialogue_line.id
			profile.character_datas.clear()
			profile.character_datas = character_datas
			profile.background = Stage.current_background
			profile.chat_datas = Game.phone_page.chat_data_pool.duplicate(true)
			profile.log_datas = Game.log_page.log_data_pool.duplicate(true)
			ResourceSaver.save(Main.save_data, Main.save_path)
			(
				func():
					save_thread.wait_to_finish()
					save_thread = null
					Game.loading = false
					Game.loading_page.hide()
					update()
			).call_deferred()
	)

func load_game() -> void:
	var profile = Main.save_data.profiles[profile_index]
	Game.switch_to_page(Game.stage_page, true, false,
		func():
			# 重置到初始状态
			Game.stage_page.reset()
			# 恢复背景（直接设置，不走 SetBackground 的过渡和清人物）
			var background_split = profile.background.split("-")
			var background_name = background_split[0]
			var variation_name = background_split[1]
			var target_background: BackgroundData = Stage.background_data_pool.filter(
				func(bg: BackgroundData): return bg.title == background_name
			).front()
			Game.stage_page.texture_rect_background.texture = target_background.variations[variation_name]
			Stage.current_background = profile.background
			Game.phone_page.label_location.text = target_background.location
			# 恢复角色
			for character_data: CharacterData in profile.character_datas:
				var character = Stage.Character(character_data.character_name)
				character.set_character_data(character_data)
				if character_data.position:
					character.character_image = character.story_model.duplicate()
					Game.stage_page.character_image_pool.add_child(character.character_image)
					character.character_image.show()
			# 所有角色就位后，一次性计算最终位置
			var pool = Game.stage_page.character_image_pool
			var character_count = pool.get_child_count()
			if character_count > 0:
				var width = pool.size.x
				var portion_width = width / character_count
				var offset_x = portion_width / 2
				for image: Control in pool.get_children():
					var position_x = image.get_index() * portion_width + offset_x
					image.position = Vector2(position_x, 0)
			# 恢复聊天和日志
			Game.phone_page.chat_data_pool = profile.chat_datas.duplicate(true)
			Game.log_page._suppressed = true
			Game.log_page.restore(profile.log_datas.duplicate(true))
			# 恢复对话（不传 extra_game_states，避免 mutations 重复执行改变已恢复的角色状态）
			Game.stage_page.dialogue_line = await Game.stage_page.dialogue.get_next_dialogue_line(profile.dialogue_id)
			Game.log_page._suppressed = false
	)
