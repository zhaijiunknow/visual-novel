class_name ProfileCard
extends TextureRect

enum SlotKind { MANUAL, QUICK, NEW_MANUAL }

@export var texture_rect_preview: TextureRect
@export var drag_filter: DragFilter
@export var label_index: Label
@export var label_chapter: Label
@export var label_chapter_title: Label
@export var texture_normal: Texture2D
@export var texture_hover: Texture2D
@export var texture_click: Texture2D
@export var button_delete: TextureButton

var slot_kind: SlotKind = SlotKind.MANUAL
var slot_index: int = -1

var hovered: bool:
	set(value):
		hovered = value
		update()

var selected: bool:
	get:
		return Game.profile_page.selected_card == self

func _ready() -> void:
	mouse_entered.connect(
		func ():
			hovered = true
	)
	mouse_exited.connect(
		func ():
			hovered = false
	)
	drag_filter.execute.connect(_on_execute)
	button_delete.pressed.connect(_on_delete_pressed)

	Game.profile_page.profile_index_changed.connect(
		func():
			update()
	)

	update()

func _on_execute() -> void:
	Game.profile_page.selected_card = self
	match slot_kind:
		SlotKind.QUICK:
			if Main.profile_mode == Main.ProfileMode.LOAD:
				Game.profile_page.load_quick_game()
		SlotKind.MANUAL:
			if Main.profile_mode == Main.ProfileMode.SAVE:
				Game.confirm_page.show_confirm(
					"覆盖存档",
					"确定要覆盖该存档吗？",
					func():
						Game.go_back()
						Game.profile_page.save_game()
				)
				Game.switch_to_page(Game.confirm_page, true, true)
			elif Main.profile_mode == Main.ProfileMode.LOAD:
				Game.profile_page.load_game()
		SlotKind.NEW_MANUAL:
			if Main.profile_mode == Main.ProfileMode.SAVE:
				Game.profile_page.save_game()

func _on_delete_pressed() -> void:
	if slot_kind == SlotKind.NEW_MANUAL:
		return
	var title := "删除存档"
	var message := "确定要删除该存档吗？\n此操作无法撤销。"
	var action := func():
		Main.save_data.profiles.remove_at(slot_index)
		Main.save_save_data()
		Game.go_back()
		Game.profile_page.update()
	if slot_kind == SlotKind.QUICK:
		title = "重置快速存档"
		message = "确定要重置快速存档吗？\n此操作无法撤销。"
		action = func():
			Main.save_data.auto_profile = null
			Main.save_save_data()
			Game.go_back()
			Game.profile_page.update()
			if Game.main_menu:
				Game.main_menu._update_start_button()
	Game.confirm_page.show_confirm(title, message, action)
	Game.switch_to_page(Game.confirm_page, true, true)

func update():
	button_delete.visible = slot_kind == SlotKind.MANUAL or (slot_kind == SlotKind.QUICK and Game.profile_page.has_quick_save())
	if selected:
		texture = texture_click
		texture_rect_preview.modulate = Color(1, 1, 1)
	elif hovered:
		texture = texture_hover
		texture_rect_preview.modulate = Color(1, 1, 1)
	else:
		texture = texture_normal
		texture_rect_preview.modulate = Color(1, 1, 1)
