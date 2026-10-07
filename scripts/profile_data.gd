class_name ProfileData
extends Resource

@export var preview: Texture2D
@export var character_datas: Array[CharacterData]
@export var chapter_name: String
## 章节在演出表里的「章节」与「标题」；读档不会走 ShowChapterInfo，靠这两个字段恢复给 Stage
@export var chapter_designation: String = ""
@export var chapter_title: String = ""
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
## 剧情日期（舞台 HUD + 手机）。读档不会重跑 SetDate，靠这三个字段恢复给 Stage。
## date_month = 0 表示这份存档存于加入日期字段之前 —— 恢复成空标签，别编造日期
@export var date_month: int = 0
@export var date_day: int = 0
@export var date_week_day: String = ""
@export var quick_save_progress_count: int = 0
@export var last_saved_at_unix_ms: int = 0
