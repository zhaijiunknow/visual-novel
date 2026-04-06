class_name SaveData
extends Resource

@export var profiles: Array[ProfileData]
@export var auto_profile: ProfileData
@export var read_data_list: Array[ReadData]


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
		ResourceSaver.save(self, "user://save_data.tres")

func is_line_read(chapter_name: String, line_id: int) -> bool:
	var rd = get_read_data(chapter_name)
	if rd == null:
		return false
	return line_id <= rd.last_read_id
