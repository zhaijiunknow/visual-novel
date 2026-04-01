class_name ProfileCard
extends TextureRect

@export var texture_rect_preview: TextureRect
@export var drag_filter: DragFilter
@export var label_index: Label
@export var label_chapter: Label
@export var label_chapter_title: Label

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
		var c: float = 9.5
		modulate = Color(c, c, c)
		var p_c: float = 0.16
		texture_rect_preview.modulate = Color(p_c, p_c, p_c)
	else:
		if hovered:
			modulate = Color(1.35, 1.35, 1.35)
		else:
			modulate = Color(1, 1, 1)
		texture_rect_preview.modulate = Color(1, 1, 1)
