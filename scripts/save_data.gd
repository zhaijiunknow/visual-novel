class_name SaveData
extends Resource

@export var profiles: Array[ProfileData]
@export var auto_profile: ProfileData
@export var read_data_list: Array[ReadData]

var _save_pending: bool = false
var _save_thread: Thread

func get_read_data(chapter_name: String) -> ReadData:
	for rd in read_data_list:
		if rd.chapter_name == chapter_name:
			return rd
	return null

func mark_read(chapter_name: String, line_id: int) -> void:
	var rd = get_read_data(chapter_name)
	if rd == null:
		rd = ReadData.new()
		rd.chapter_name = chapter_name
		read_data_list.append(rd)
	if line_id > rd.last_read_id:
		rd.last_read_id = line_id
		_save_deferred()

func _save_deferred() -> void:
	if _save_pending:
		return
	_save_pending = true
	if _save_thread and _save_thread.is_started():
		_save_thread.wait_to_finish()
	_save_thread = Thread.new()
	_save_thread.start(
		func():
			ResourceSaver.save(self, "user://save_data.tres")
			_save_pending = false
	)

func is_line_read(chapter_name: String, line_id: int) -> bool:
	var rd = get_read_data(chapter_name)
	if rd == null:
		return false
	return line_id <= rd.last_read_id
