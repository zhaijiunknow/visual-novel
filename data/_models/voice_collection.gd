class_name VoiceCollection
extends Resource

@export var chapter_number: int
@export var chapter_name: String
@export var character_name: String
@export var text: String
@export var voice_filename: String

var chapter_number_text: String:
	get: return "CHAPTER %s" % str(chapter_number).pad_zeros(2)
