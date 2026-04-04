class_name ProfileCard
extends TextureRect

@export var texture_rect_preview: TextureRect
@export var drag_filter: DragFilter
@export var label_index: Label
@export var label_chapter: Label
@export var label_chapter_title: Label
@export var texture_normal: Texture2D
@export var texture_hover: Texture2D
@export var texture_click: Texture2D

var hovered: bool:
	set(value):
		hovered = value
		update()

var selected: bool:
	get:
		return Game.profile_page.profile_index == get_index()

func _ready() -> void:
	mouse_entered.connect(
		func ():
			hovered = true
	)
	mouse_exited.connect(
		func ():
			hovered = false
	)
	drag_filter.execute.connect(
		func ():
			Game.profile_page.profile_index = get_index()
			if Main.profile_mode == Main.ProfileMode.SAVE:
				Game.profile_page.save_game()
			if Main.profile_mode == Main.ProfileMode.LOAD:
				Game.profile_page.load_game()
	)
	
	Game.profile_page.profile_index_changed.connect(
		func ():
			update()
	)
	
	update()
	
func update():
	if selected:
		texture = texture_click
		texture_rect_preview.modulate = Color(1, 1, 1)
	elif hovered:
		texture = texture_hover
		texture_rect_preview.modulate = Color(1, 1, 1)
	else:
		texture = texture_normal
		texture_rect_preview.modulate = Color(1, 1, 1)
