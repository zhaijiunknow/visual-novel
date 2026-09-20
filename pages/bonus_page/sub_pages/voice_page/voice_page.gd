@tool
class_name VoicePage
extends Control

@export var portrait_dict: Dictionary[Enums.CharacterName, TextureRect]

@export var selected_character: Enums.CharacterName:
	set(value):
		selected_character = value
		for texture in portrait_dict:
			portrait_dict[texture].visible = false
		# portrait_dict 未配置该角色时取到 null，直接不显示，不报错
		var portrait: TextureRect = portrait_dict.get(selected_character)
		if portrait:
			portrait.visible = true
		

@export var voice_card_pool: Control
@export var label_character_name: Label
@export var label_chapter_number: Label
@export var label_chapter_name: Label
@export var label_text: Label
@export var voice_view: Control
@export var button_replay: TextureButton
@export var button_favourite: TextureButton
@export var texture_rect_favourite: TextureRect

var favourite: bool:
	get: return Main.has_voice_collection(current_collection.voice_filename)

var current_collection: VoiceCollection

func select_collection(collection: VoiceCollection) -> void:
	current_collection = collection
	if not current_collection:
		voice_view.visible = false
		return
	# 先更新所有状态
	label_character_name.text = current_collection.character_name
	label_chapter_number.text = current_collection.chapter_number_text
	label_chapter_name.text = current_collection.chapter_name
	label_text.text = current_collection.text
	print(current_collection.character_name)
	selected_character = get_character_enum_from_string(current_collection.character_name)
	update_favourite()
	# 状态就绪后才呈现给玩家
	voice_view.modulate.a = 0
	voice_view.visible = true
	create_tween().tween_property(voice_view, "modulate:a", 1.0, 0.2)
	play_current_voice()
	
func get_character_enum_from_string(name: String) -> Enums.CharacterName:
	var idx = Enums.CharacterName.keys().find(name)
	if idx != -1:
		return Enums.CharacterName.values()[idx]
	return Enums.CharacterName.余洛琛  # 确保枚举中有 NONE 默认值
	
func play_current_voice() -> void:
	print("[UI] 语音鉴赏·回放 %s → %s" % [current_collection.voice_filename, Game.describe_state()])
	# 这里以前要先 await 一段 1 秒的音乐淡出，等它跑完语音才出声 —— 点一下明显像「没反应」。
	# 现在直接播，让 play_voice 内部的 duck 去让路（0.3 秒降到 50%，语音播完自动恢复原音量），
	# 和对话里「重播」按钮的处理一致。
	# 离开收藏页时剧情 BGM 由 game.update_audio() 的 save/restore_story_music 负责。
	AudioManager.play_voice(current_collection.voice_filename, true)

func _ready() -> void:
	if Engine.is_editor_hint(): return
	visibility_changed.connect(
		func ():
			if visible:
				current_collection = null
				voice_view.visible = false
				update()
	)

	button_replay.pressed.connect(play_current_voice)
	button_favourite.pressed.connect(
		func ():
			print("[UI] 语音鉴赏·%s %s → %s" % [
				"取消收藏" if favourite else "收藏",
				current_collection.voice_filename, Game.describe_state()])
			if favourite:
				# 取消收藏：先scroll到卡片位置，再淡出
				_last_removed_index = get_card_index(current_collection)
				var card = get_card(current_collection)
				await scroll_to_card(card)
				Main.collection_data.voice_collections.erase(current_collection)
				await fade_out_card(card)
			else:
				# 恢复收藏：先插入（不可见），等布局算好，scroll到位，再淡入
				var insert_index = _last_removed_index
				Main.collection_data.voice_collections.append(current_collection)
				var card = insert_card(current_collection, insert_index)
				await get_tree().process_frame
				await scroll_to_card(card)
				await fade_in_card(card)
			Main.save_collection_data()
			update_favourite()
			Main.voice_collection_changed.emit(current_collection.voice_filename)
	)
	Main.voice_collection_changed.connect(
		func(vf: String):
			if current_collection and vf == current_collection.voice_filename:
				update_favourite()
	)


var _last_removed_index := -1

func add_card(collection: VoiceCollection) -> void:
	var voice_card: VoiceCard = Prefabs.voice_card.instantiate()
	voice_card.voice_collection = collection
	voice_card_pool.add_child(voice_card)
	voice_card.modulate.a = 0
	create_tween().tween_property(voice_card, "modulate:a", 1.0, 0.2)

func insert_card(collection: VoiceCollection, index: int) -> VoiceCard:
	var voice_card: VoiceCard = Prefabs.voice_card.instantiate()
	voice_card.voice_collection = collection
	voice_card_pool.add_child(voice_card)
	voice_card_pool.move_child(voice_card, mini(index, voice_card_pool.get_child_count() - 1))
	voice_card.modulate.a = 0
	return voice_card

func get_card_index(collection: VoiceCollection) -> int:
	for card: VoiceCard in voice_card_pool.get_children():
		if card.voice_collection == collection:
			return card.get_index()
	return -1

func get_card(collection: VoiceCollection) -> VoiceCard:
	for card: VoiceCard in voice_card_pool.get_children():
		if card.voice_collection == collection:
			return card
	return null

func fade_in_card(card: VoiceCard) -> void:
	var tween = create_tween()
	tween.tween_property(card, "modulate:a", 1.0, 1.0)
	await tween.finished

func fade_out_card(card: VoiceCard) -> void:
	var tween = create_tween()
	tween.tween_property(card, "modulate:a", 0.0, 1.0)
	tween.tween_callback(card.queue_free)


func update() -> void:
	for child in voice_card_pool.get_children():
		voice_card_pool.remove_child(child)
		child.queue_free()
	for collection in Main.collection_data.voice_collections:
		add_card(collection)

# Scroll让card的顶部对齐ScrollContainer的顶部
# 如果card在底部（对齐顶部会超出范围），则scroll到最底部
func scroll_to_card(card: Control) -> void:
	if not card: return
	var scroll: ScrollContainer = voice_card_pool.get_parent()
	var target_y = int(card.position.y)
	var max_scroll = int(voice_card_pool.size.y - scroll.size.y)
	target_y = clampi(target_y, 0, maxi(max_scroll, 0))
	if scroll.scroll_vertical == target_y:
		return
	var tween = create_tween()
	tween.tween_property(scroll, "scroll_vertical", target_y, 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	await tween.finished

func update_favourite() -> void:
	texture_rect_favourite.texture = \
		Prefabs.texture_cancel_favourite if favourite else Prefabs.texture_set_favourite
