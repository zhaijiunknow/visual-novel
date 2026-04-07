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

var current_collection: VoiceCollection:
	set(value):
		current_collection = value
		if not current_collection:
			voice_view.visible = false
			return
		voice_view.modulate.a = 0
		voice_view.visible = true
		create_tween().tween_property(voice_view, "modulate:a", 1.0, 0.2)
		label_character_name.text = current_collection.character_name
		label_chapter_number.text = current_collection.chapter_number_text
		label_chapter_name.text = current_collection.chapter_name
		label_text.text = current_collection.text
		texture_rect_portrait.texture = Stage.Character(current_collection.character_name).texture_rect_avatar.texture
		AudioManager.play_voice(current_collection.voice_filename, true)
		update_favourite()

func _ready() -> void:
	visibility_changed.connect(
		func ():
			if visible:
				current_collection = null
				update()
	)
	
	button_replay.pressed.connect(AudioManager.replay_voice)
	button_favourite.pressed.connect(
		func ():
			if favourite:
				Main.collection_data.voice_collections.erase(current_collection)
			else:
				Main.collection_data.voice_collections.append(current_collection)
			Main.save_collection_data()
			update_favourite()
	)
	
func update() -> void:
	for child in voice_card_pool.get_children():
		voice_card_pool.remove_child(child)
		child.queue_free()
	for collection in Main.collection_data.voice_collections:
		var voice_card: VoiceCard = Prefabs.voice_card.instantiate()
		voice_card.voice_collection = collection
		voice_card_pool.add_child(voice_card)

func update_favourite() -> void:
	texture_rect_favourite.texture = \
		Prefabs.texture_cancel_favourite if favourite else Prefabs.texture_set_favourite
