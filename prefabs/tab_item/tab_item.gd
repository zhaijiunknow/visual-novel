@tool
class_name TabItem
extends Control

@export var title_zh: String:
	set(value):
		title_zh = value
		label_title_zh.text = title_zh
@export var title_en: String:
	set(value):
		title_en = value
		label_title_en.text = title_en

@export var target_tab: Control
@export var selected_frame: TextureRect
@export var hover_hint: TextureRect

@export var label_title_zh: Label
@export var label_title_en: Label

var hovered: bool:
	set(value):
		hovered = value
		hover_hint.visible = hovered

func _ready() -> void:
	if Engine.is_editor_hint(): return
	#Main.bonus_tab_index_changed.connect(update)
	mouse_entered.connect(
		func (): hovered = true
	)
	mouse_exited.connect(
		func (): hovered = false
	)
	gui_input.connect(
		func (event: InputEvent):
			if event is InputEventMouseButton:
				if event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
					select()
	)
	
	hovered = false

func select() -> void:
	for tab_item: TabItem in get_parent().get_children():
		tab_item.target_tab.visible = tab_item == self
		tab_item.selected_frame.visible = tab_item == self
