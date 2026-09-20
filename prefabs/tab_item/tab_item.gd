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
## 惰性页面：target_tab 留空时按这个名字向所属页面要（`ensure_sub_page()`）。
## 鉴赏页的四个子页就是这么按需创建的；设置页的 tab 有静态 target_tab，不受影响
@export var lazy_page_name: StringName
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

## 目标页：没有静态指定的，就按名字向父链上带 ensure_sub_page() 的页面要
func _resolve_target() -> Control:
	if target_tab == null and lazy_page_name != &"":
		var owner_page := _find_lazy_page_owner()
		if owner_page != null:
			target_tab = owner_page.ensure_sub_page(lazy_page_name)
	return target_tab


func _find_lazy_page_owner() -> Node:
	var node: Node = get_parent()
	while node != null:
		if node.has_method("ensure_sub_page"):
			return node
		node = node.get_parent()
	return null


func select() -> void:
	# 只藏「已经建出来」的兄弟页。这里必须读 target_tab 字段，不能调 _resolve_target()：
	# 那会把四个惰性子页一次全建出来——BonusPage._ready() 就会调 start_tab_item.select()，
	# 等于鉴赏页一进去就加载全部子页的图，惰性化白做
	for tab_item: TabItem in get_parent().get_children():
		if tab_item == self:
			continue
		if tab_item.target_tab != null:
			tab_item.target_tab.visible = false
		tab_item.selected_frame.visible = false
	# 自己这一页才是用到才建
	var target := _resolve_target()
	if target != null:
		target.visible = true
	selected_frame.visible = true
