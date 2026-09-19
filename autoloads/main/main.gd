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
signal voice_collection_changed(voice_filename: String)
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

## 收藏一条语音并落盘。
## 章节号/章节名取演出表的值（Stage 在 ShowChapterInfo 时记下的），
## 拿不到才退回调用方给的章节名——那是对话文件名，不是表里的标题。
func collect_voice(character_name: String, text: String, voice_filename: String,
		fallback_chapter_name: String = "") -> void:
	var collection := VoiceCollection.new()
	collection.character_name = character_name
	collection.text = text
	collection.voice_filename = voice_filename
	collection.chapter_designation = Stage.current_chapter_designation
	collection.chapter_name = Stage.current_chapter_title \
		if Stage.current_chapter_title != "" else fallback_chapter_name
	collection_data.voice_collections.append(collection)
	save_collection_data()
	voice_collection_changed.emit(voice_filename)

func unlock_cg(cg_name: String) -> void:
	if cg_name.is_empty():
		return
	if cg_name in collection_data.unlocked_cgs:
		return
	collection_data.unlocked_cgs.append(cg_name)
	save_collection_data()

func has_unlocked_cg(cg_name: String) -> bool:
	return cg_name in collection_data.unlocked_cgs

var _setting_save_pending: bool = false
var _setting_save_thread: Thread

func save_collection_data() -> void:
	var err := ResourceSaver.save(collection_data, collection_path)
	if err != OK:
		push_error("save_collection_data failed (%d): %s" % [err, collection_path])

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
