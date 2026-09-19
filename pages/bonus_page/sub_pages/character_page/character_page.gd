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

var character_dict: Dictionary[String, Character]:
	get:
		var dict: Dictionary[String, Character] = {}
		for character: Character in character_pool.get_children():
			dict[character.name] = character
		
		return dict

var current_character: Character:
	get:
		return character_dict[Stage.character_selection_name]

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
	Stage.character_selection_name = character_pool.get_child(0).name
	Stage.character_selection_name_changed.connect(
		func():
			update_characters()
			slider_size.value = current_character.body_scale_factor
			for child in optional_pool.get_children():
				optional_pool.remove_child(child)
				child.queue_free()
			for optional: Sprite2D in current_character.optionals_pool.get_children():
				var character_option: CharacterOption = Prefabs.character_option.instantiate()
				character_option.label.text = optional.name
				optional_pool.add_child(character_option)
				Tools.clear_connections(optional.visibility_changed)
				optional.visibility_changed.connect(
					func():
						character_option.label_option_name.text = "开启" if optional.visible else "关闭"
				)
				optional.visibility_changed.emit()
				character_option.next_button.pressed.connect(toggle_optional.bind(optional))
				character_option.previous_button.pressed.connect(toggle_optional.bind(optional))
	)
	background_option.previous_button.pressed.connect(
		func(): background_index -= 1
	)
	background_option.next_button.pressed.connect(
		func(): background_index += 1
	)
	variation_option.previous_button.pressed.connect(
		func(): variation_index -= 1
	)
	variation_option.next_button.pressed.connect(
		func(): variation_index += 1
	)
	background_index = 0
	
	update_characters()
	for character: Character in character_pool.get_children():
		character.body_scale_factor = slider_size.value

	slider_size.value_changed.connect(update_scale)
	update_scale()

	# 每次进入鉴赏页都按剧情站位把角色摆好（顺带撤销玩家拖拽）
	visibility_changed.connect(_on_visibility_changed)
	if Game.bonus_page:
		# 整页被 hide_all_pages() 隐藏时子页面的 visible 标志不会翻转，
		# 所以要盯整页的可见性，否则退出鉴赏再进来不会重置
		Game.bonus_page.visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
	if not visible:
		return
	if Game.bonus_page and not Game.bonus_page.visible:
		return
	# 延后一帧：站位标记在剧情页自己的 SubViewport 里，布局跑完再读
	reset_character_positions.call_deferred()

func reset_character_positions() -> void:
	for character: Character in character_pool.get_children():
		character.apply_bonus_slot()

func update_scale(_new_value: float = 0.0) -> void:
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
		Tools.clear_connections(option.previous_button.pressed)
		Tools.clear_connections(option.next_button.pressed)
		option.previous_button.pressed.connect(
			func():
				current_character.update_bonus_part_index(part_name, -1)
				update_option_name(option)
		)
		option.next_button.pressed.connect(
			func():
				current_character.update_bonus_part_index(part_name, +1)
				update_option_name(option)
		)
		update_option_name(option)

func update_option_name(option: CharacterOption) -> void:
	var part_dict = current_character.bonus_part_index_dict[option.body_part]
	option.option_name = part_dict.options[part_dict.index]
