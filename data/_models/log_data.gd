class_name LogData
extends Resource

@export var character_name: String
@export var display_name: String
@export var text: String
@export var voice_filename: String
@export var chapter_name: String
## 这一句在 dialogue 资源里的行 id（DialogueLine.id），历史记录靠它跳回那句。
## 加这个字段之前存的档没有它，反序列化出来是空串 —— 那种条目点不动，不报错
@export var line_id: String = ""
