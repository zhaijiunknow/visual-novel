extends Node

enum ProfileMode { LOAD, SAVE }

var save_data: SaveData = SaveData.new()
var save_path = "user://save_data.tres"
var collection_data: CollectionData = CollectionData.new()
var collection_path = "user://collection_data.tres"
var setting_data: SettingData = SettingData.new()
var setting_path = "user://setting_data.tres"

var clicked: bool
var dragged: bool

var profile_mode: ProfileMode:
	set(value):
		profile_mode = value

signal gallery_card_index_changed
signal speed_settings_changed
var gallery_card_index: int:
	set(value):
		gallery_card_index = value
		emit_signal("gallery_card_index_changed")

@export_file_path("json") var expression_json: String
var expression_dict: Dictionary

func _ready() -> void:
	if FileAccess.file_exists(save_path):
		save_data = load(save_path)
	if FileAccess.file_exists(collection_path):
		collection_data = load(collection_path)
	if FileAccess.file_exists(setting_path):
		setting_data = load(setting_path)
	
	#expression_dict = JSON.parse_string()

func has_voice_collection(filename) -> bool:
	return collection_data.voice_collections.filter(
		func (collection: VoiceCollection):
			return collection.voice_filename == filename
	).size() > 0

var _setting_save_pending: bool = false
var _setting_save_thread: Thread

func save_collection_data() -> void:
	ResourceSaver.save(collection_data, collection_path)

func save_setting_data() -> void:
	if _setting_save_pending:
		return
	_setting_save_pending = true
	if _setting_save_thread and _setting_save_thread.is_started():
		_setting_save_thread.wait_to_finish()
	_setting_save_thread = Thread.new()
	_setting_save_thread.start(
		func():
			ResourceSaver.save(setting_data, setting_path)
			_setting_save_pending = false
	)

func save_save_data() -> void:
	ResourceSaver.save(save_data, save_path)

#func auto_save() -> void:
	#ResourceSaver.save(sa)
