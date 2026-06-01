class_name ProfileData
extends Resource

@export var preview: Texture2D
@export var character_datas: Array[CharacterData]
@export var chapter_name: String
@export var dialogue_id: String
@export var book_segment_start_id: String = ""
@export var background: String
@export var chat_datas: Array[ChatData]
@export var active_chat_character: String
@export var log_datas: Array[LogData]
@export var notebook_data: Resource
@export var book_open: bool = false
@export var music_path: String
@export var music_position: float
@export var music_source: int
@export var cg_name: String
@export var cg_variation: String
@export var quick_save_progress_count: int = 0
@export var last_saved_at_unix_ms: int = 0
