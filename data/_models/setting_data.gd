class_name SettingData
extends Resource

# 系统
@export var fullscreen: bool = true
@export var skip_unread_text: bool = false
@export var skip_after_choice: bool = false
@export var skip_ignore_transitions: bool = false
@export var need_confirmation: bool = true
@export var text_speed: float = 0.5
@export var auto_speed: float = 0.5
@export var skip_unread: bool = false

# 窗口化（非全屏）时上次的窗口尺寸/位置，退出游戏时记录、下次启动直接用。
# 尺寸为 0 表示还没记录过
@export var windowed_size: Vector2i = Vector2i.ZERO
@export var windowed_position: Vector2i = Vector2i.ZERO

# 音频
@export var music_volume: float = 0.4
@export var sound_volume: float = 0.4
@export var voice_volume: float = 0.5
@export var character_volumes: Dictionary = {}
@export var mute_all: bool = false
