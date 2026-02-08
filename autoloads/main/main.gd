extends Node

enum ProfileMode { LOAD, SAVE }

var save_data: SaveData = SaveData.new()
var save_path = "user://save_data.tres"
var collection_data: CollectionData = CollectionData.new()
var collection_path = "user://collection_data.tres"

var clicked: bool
var dragged: bool

var profile_mode: ProfileMode:
	set(value):
		profile_mode = value

signal bonus_tab_index_changed
var bonus_tab_index: int:
	set(value):
		bonus_tab_index = value
		emit_signal("bonus_tab_index_changed")

signal gallery_card_index_changed
var gallery_card_index: int:
	set(value):
		gallery_card_index = value
		emit_signal("gallery_card_index_changed")

func _ready() -> void:
	if FileAccess.file_exists(save_path):
		save_data = load(save_path)
	if FileAccess.file_exists(collection_path):
		collection_data = load(collection_path)

func clear_connections(target_signal: Signal) -> void:
	for connection in target_signal.get_connections():
		target_signal.disconnect(connection.callable)

func clear_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func add_voice_collection(voice_collection: VoiceCollection) -> void:
	save_data.voice_collections.append(voice_collection)

func save_collection_data() -> void:
	ResourceSaver.save(collection_data, collection_path)
