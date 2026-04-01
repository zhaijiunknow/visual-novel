extends Node

@export var character_pool: Control
@export var background_data_pool: Array[BackgroundData]
@export var gallery_data_pool: Array[GalleryData]
var current_background: Texture2D

signal character_selection_index_changed
var character_selection_index: int:
	set(value):
		character_selection_index = value
		emit_signal("character_selection_index_changed")

var character_dict: Dictionary[String, Character]
var character_array: Array[Character]:
	get:
		var characters: Array[Character]
		for key in character_dict.keys():
			characters.append(character_dict[key])
		return characters

func _ready() -> void:
	for character: Character in character_pool.get_children():
		character_dict[character.name] = character

func start() -> void:
	Game.hide_all_pages()
	Game.stage_page.show()
	Game.stage_page.start()

#region Dialogue Commands
func Character(character_name: String) -> Character:
	return character_dict[character_name]

func SetBackground(background_name: String, variation_name: String,
	out_time: float = 0.5, in_time: float = 0.5) -> void:
	await create_tween().tween_property(
		Game.stage_page.texture_rect_blackscreen,
		"modulate:a",
		1,
		out_time
	).finished
	var target_background: Texture2D = background_data_pool.filter(
		func (background: BackgroundData):
			return background.title == background_name
	).front().variations[variation_name]
	current_background = target_background
	Game.stage_page.texture_rect_background.texture = target_background
	await create_tween().tween_property(
		Game.stage_page.texture_rect_blackscreen,
		"modulate:a",
		0,
		in_time
	).finished

func Travel() -> void:
	Game.travel_page.visible = true
	await Game.travel_page.visibility_changed

func ShowDate(month: int, day: int, week_day: String) -> void:
	Game.stage_page.label_month.text = str(month).pad_zeros(2)
	Game.stage_page.label_day.text = str(day).pad_zeros(2)
	Game.stage_page.label_week_day.text = week_day
	var date_player = Game.stage_page.date_player
	date_player.play("ShowDate")
	await date_player.animation_finished

func ShowPhone() -> void:
	Game.phone_page.show()

func HidePhone() -> void:
	Game.phone_page.hide()

#endregion
