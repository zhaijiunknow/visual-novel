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

# 音频
@export var music_volume: float = 1.0
@export var sound_volume: float = 1.0
@export var voice_volume: float = 1.0
@export var character_volumes: Dictionary = {}
@export var mute_all: bool = false
