class_name CharacterPage
extends Control

@export var label_character_name: Label
@export var background: TextureRect
@export var character_pool: Control
@export var body_part_options: Array[CharacterOption]
@export var background_option: CharacterOption
@export var variation_option: CharacterOption
@export var slider_size: SliderEx
@export var optional_pool: Control

var current_character: Character:
	get:
		return character_pool.get_child(Stage.character_selection_index)

var background_index: int:
	set(value):
		background_index = value
		var background_count = Stage.background_data_pool.size()
		background_index = posmod(background_index, background_count)
		background_option.option_name = background_data.title
		var variation_key = background_data.variations.keys()[0]
		variation_option.option_name = variation_key
		background.texture = background_data.variations[variation_key]
var background_data: BackgroundData:
	get: return Stage.background_data_pool[background_index]

var variation_index: int:
	set(value):
		variation_index = value
		variation_index = posmod(variation_index, background_data.variations.keys().size())
		var variation_key = background_data.variations.keys()[variation_index]
		variation_option.option_name = variation_key
		background.texture = background_data.variations[variation_key]
		

func toggle_optional(optional: Sprite2D) -> void:
	optional.visible = not optional.visible

func _ready() -> void:
	Stage.character_selection_index_changed.connect(
		func ():
			update_characters()
			slider_size.value = current_character.body_scale_factor
			for child in optional_pool.get_children():
				optional_pool.remove_child(child)
				child.queue_free()
			for optional: Sprite2D in current_character.optionals_pool.get_children():
				var character_option: CharacterOption = Prefabs.character_option.instantiate()
				character_option.label.text = optional.name
				optional_pool.add_child(character_option)
				Main.clear_connections(optional.visibility_changed)
				optional.visibility_changed.connect(
					func ():
						character_option.label_option_name.text = "开启" if optional.visible else "关闭"
				)
				optional.visibility_changed.emit()
				character_option.next_button.pressed.connect(toggle_optional.bind(optional))
				character_option.previous_button.pressed.connect(toggle_optional.bind(optional))
	)
	background_option.previous_button.pressed.connect(
		func (): background_index -= 1
	)
	background_option.next_button.pressed.connect(
		func (): background_index += 1
	)
	variation_option.previous_button.pressed.connect(
		func (): variation_index -= 1
	)
	variation_option.next_button.pressed.connect(
		func (): variation_index += 1
	)
	background_index = 0
	
	update_characters()
	
	slider_size.value_changed.connect(update_scale)
	
	Stage.character_selection_index = 0

func update_scale() -> void:
	current_character.body_scale_factor = slider_size.value

func update_characters() -> void:
	for child: Control in character_pool.get_children():
		child.visible = false
	current_character.visible = true
	label_character_name.text = current_character.name
	
	for option: CharacterOption in body_part_options:
		var body_part: AnimatedSprite2D = current_character \
			.body_part_dict[option.body_part]
		var part_name = option.body_part
		Main.clear_connections(option.previous_button.pressed)
		Main.clear_connections(option.next_button.pressed)
		option.previous_button.pressed.connect(
			func ():
				current_character.update_bonus_part_index(part_name, -1)
				update_option_name(option)
		)
		option.next_button.pressed.connect(
			func ():
				current_character.update_bonus_part_index(part_name, +1)
				update_option_name(option)
		)
		update_option_name(option)

func update_option_name(option: CharacterOption) -> void:
	var part_dict = current_character.bonus_part_index_dict[option.body_part]
	option.option_name = part_dict.options[part_dict.index]
