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

func reset() -> void:
	current_background = ""
	current_date = ""
	clear_characters()

func start() -> void:
	Game.stage_page.start()

#region Dialogue Commands
func Character(character_name: String) -> Character:
	return character_dict[character_name]

func SetBackground(background_name: String, variation_name: String,
		out_time: float = 0.5, in_time: float = 0.5) -> void:
	var is_skip: bool = Game.stage_page.skip
	var skip_trans: bool = is_skip and Main.setting_data.skip_ignore_transitions

	if is_skip and not skip_trans:
		Game.stage_page._set_mode(Game.stage_page.AdvanceMode.MANUAL)
		Game.stage_page.skip_cancelled.emit()

	if skip_trans:
		Game.stage_page.texture_rect_blackscreen.modulate.a = 1
	else:
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
	# 趁黑屏清空场景人物、隐藏对话框
	clear_characters()
	Game.stage_page.dialogue_screen.modulate.a = 0

	if skip_trans:
		Game.stage_page.texture_rect_blackscreen.modulate.a = 0
	else:
		await create_tween().tween_property(
			Game.stage_page.texture_rect_blackscreen,
			"modulate:a",
			0,
			in_time
		).finished

func clear_characters() -> void:
	Tools.clear_children(Game.stage_page.character_image_pool)
	for character in character_array:
		character.character_image = null
		character.current_position = ""

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
	var date_control = Game.stage_page.date
	date_control.modulate.a = 0
	await create_tween().tween_property(date_control, "modulate:a", 1, 0.8).finished
	await get_tree().create_timer(2.0).timeout
	await create_tween().tween_property(date_control, "modulate:a", 0, 0.3).finished

func ShowPhone() -> void:
	await Game.phone_page.open(true)

func HidePhone() -> void:
	await Game.phone_page.close()

#endregion
