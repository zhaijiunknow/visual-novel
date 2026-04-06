class_name BonusPage
extends CanvasLayer

@export var music_page: MusicPage
@export var voice_page: VoicePage
@export var start_tab_item: TabItem
@export var tab_gallery: TabItem
@export var tab_music: TabItem
@export var tab_voice: TabItem

func _ready() -> void:
	start_tab_item.select()
