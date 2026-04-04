class_name SettingPage
extends CanvasLayer

@export var start_tab_item: TabItem

func _ready() -> void:
	start_tab_item.select()
