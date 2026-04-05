@tool
class_name SelectionButton
extends PanelContainer

@export var label_title: Label

@export var click_color: Color = Color(1.0, 1.0, 1.0)
@export var click_hover: Color = Color(1.0, 1.0, 1.0, 0.831)
@export var click_selected: Color = Color(0.722, 0.722, 0.722)

@export var title: String:
	set(value):
		title = value
		if label_title:
			label_title.text = title

@export var selected: bool:
	set(value):
		selected = value
		select_rect.visible = selected

@export var hovered: bool:
	set(value):
		hovered = value
		hover_rect.visible = hovered and not selected


func _ready() -> void:
	mouse_entered.connect(func(): hovered = true)
	mouse_exited.connect(func(): hovered = false)
