class_name VoiceCollection
extends Resource

## 旧字段：早先按 "CHAPTER %02d" 生成的章节号，现在只作 chapter_designation 为空时的兜底
@export var chapter_number: int
## 演出表「章节」列的原值（如 Prologue），收藏时由 Main.collect_voice 写入
@export var chapter_designation: String = ""
@export var chapter_name: String
@export var character_name: String
@export var text: String
@export var voice_filename: String

var chapter_number_text: String:
	get:
		if chapter_designation != "":
			return chapter_designation
		return "CHAPTER %s" % str(chapter_number).pad_zeros(2)
