class_name VoicePage
extends Control

@export var voice_card_pool: Control
@export var texture_rect_portrait: TextureRect
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
	texture_rect_portrait.texture = Stage.Character(current_collection.character_name).texture_rect_avatar.texture
	update_favourite()
	# 状态就绪后才呈现给玩家
	voice_view.modulate.a = 0
	voice_view.visible = true
	create_tween().tween_property(voice_view, "modulate:a", 1.0, 0.2)
	play_current_voice()

func play_current_voice() -> void:
	await AudioManager.pause_music()
	AudioManager.play_voice(current_collection.voice_filename, true)

func _ready() -> void:
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
			if favourite:
				_last_removed_index = get_card_index(current_collection)
				await scroll_to_index(_last_removed_index)
				Main.collection_data.voice_collections.erase(current_collection)
				fade_out_card(current_collection)
			else:
				var insert_index = _last_removed_index
				Main.collection_data.voice_collections.append(current_collection)
				await scroll_to_index(insert_index)
				insert_card(current_collection, insert_index)
			Main.save_collection_data()
			update_favourite()
			Main.voice_collection_changed.emit(current_collection.voice_filename)
	)
	Main.voice_collection_changed.connect(
		func(vf: String):
			if current_collection and vf == current_collection.voice_filename:
				update_favourite()
			update()
	)


var _last_removed_index := -1

func add_card(collection: VoiceCollection) -> void:
	var voice_card: VoiceCard = Prefabs.voice_card.instantiate()
	voice_card.voice_collection = collection
	voice_card_pool.add_child(voice_card)
	voice_card.modulate.a = 0
	create_tween().tween_property(voice_card, "modulate:a", 1.0, 0.2)

func insert_card(collection: VoiceCollection, index: int) -> void:
	var voice_card: VoiceCard = Prefabs.voice_card.instantiate()
	voice_card.voice_collection = collection
	voice_card_pool.add_child(voice_card)
	voice_card_pool.move_child(voice_card, mini(index, voice_card_pool.get_child_count() - 1))
	voice_card.modulate.a = 0
	create_tween().tween_property(voice_card, "modulate:a", 1.0, 0.2)

func get_card_index(collection: VoiceCollection) -> int:
	for card: VoiceCard in voice_card_pool.get_children():
		if card.voice_collection == collection:
			return card.get_index()
	return -1


func fade_out_card(collection: VoiceCollection) -> void:
	for card: VoiceCard in voice_card_pool.get_children():
		if card.voice_collection == collection:
			var tween = create_tween()
			tween.tween_property(card, "modulate:a", 0.0, 0.2)
			tween.tween_callback(card.queue_free)
			break


func update() -> void:
	for child in voice_card_pool.get_children():
		voice_card_pool.remove_child(child)
		child.queue_free()
	for collection in Main.collection_data.voice_collections:
		add_card(collection)

func scroll_to_index(index: int) -> void:
	var scroll: ScrollContainer = voice_card_pool.get_parent()
	if index < 0 or voice_card_pool.get_child_count() == 0:
		return
	# 用现有卡片算出目标行的 y 位置
	var ref_index = mini(index, voice_card_pool.get_child_count() - 1)
	var ref_card: Control = voice_card_pool.get_child(ref_index)
	var target_y = int(ref_card.position.y)
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
