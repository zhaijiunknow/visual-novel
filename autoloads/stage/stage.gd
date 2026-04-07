extends Node

@export var character_pool: Control
@export var background_data_pool: Array[BackgroundData]
@export var gallery_data_pool: Array[GalleryData]

var current_background: String
var current_date: String

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
	var target_background: BackgroundData = background_data_pool.filter(
		func (background: BackgroundData):
			return background.title == background_name
	).front()
	var target_texture: Texture2D = target_background.variations[variation_name]
	current_background = "%s-%s" % [background_name, variation_name]
	Game.phone_page.label_location.text = target_background.location
	Game.stage_page.texture_rect_background.texture = target_texture
	await create_tween().tween_property(
		Game.stage_page.texture_rect_blackscreen,
		"modulate:a",
		0,
		in_time
	).finished

func Travel() -> void:
	Game.travel_page.visible = true
	await Game.travel_page.visibility_changed

func SetDate(month: int, day: int, week_day: String) -> void:
	var date_key := "%02d-%02d-%s" % [month, day, week_day]
	if current_date == date_key:
		return
	current_date = date_key
	var month_str = str(month).pad_zeros(2)
	var day_str = str(day).pad_zeros(2)
	Game.phone_page.label_phone_date.text = "%s/%s" % [month_str, day_str]
	Game.phone_page.label_time.text = week_day
	Game.stage_page.label_month.text = month_str
	Game.stage_page.label_day.text = day_str
	Game.stage_page.label_week_day.text = week_day
	var date_player = Game.stage_page.date_player
	date_player.play("ShowDate")
	await date_player.animation_finished

func ShowPhone() -> void:
	await Game.phone_page.open(true)

func HidePhone() -> void:
	await Game.phone_page.close()

#endregion
