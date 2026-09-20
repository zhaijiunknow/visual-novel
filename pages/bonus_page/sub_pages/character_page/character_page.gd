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
		var count := Stage.background_count()
		if count == 0:
			return
		background_index = posmod(background_index, count)
		var data := Stage.background_at(background_index)
		if data == null:
			return
		background_option.option_name = data.title
		var variation_key = data.variations.keys()[0]
		variation_option.option_name = variation_key
		background.texture = data.variations[variation_key]

## 背景按需 load（Stage 不再开局全量持有，见 stage.gd 的 background_paths）
var background_data: BackgroundData:
	get: return Stage.background_at(background_index)

var variation_index: int:
	set(value):
		variation_index = value
		var data := background_data
		if data == null or data.variations.keys().is_empty():
			return
		variation_index = posmod(variation_index, data.variations.keys().size())
		var variation_key = data.variations.keys()[variation_index]
		variation_option.option_name = variation_key
		background.texture = data.variations[variation_key]
		

func toggle_optional(optional: Sprite2D) -> void:
	optional.visible = not optional.visible

func _ready() -> void:
	Stage.character_selection_name = character_pool.get_child(0).name
	Stage.character_selection_name_changed.connect(
		func():
			update_characters()
			# 切换角色也要把它摆回站位。apply_bonus_slot 会顺带撤销玩家拖拽，
			# 否则拖过（或以前摆偏过）的角色会带着旧位置直接显示出来。
			# 延迟一帧：首次选择发生在 _ready 里，那时布局还没跑完，
			# 直接调会把 apply_bonus_slot 里一次性记录的 home 位置记错
			reset_character_positions.call_deferred()
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

## 站位标记在剧情页里，而剧情页现在是「用到才建」的：从主菜单直接进鉴赏时，它到这一刻才被创建，
## 里面的 HBoxContainer 还没排过版 —— 此时标记的 global_position 是场景里的旧偏移，
## 非 0 但是错的，apply_bonus_slot 的「坐标为 0 就跳过」守卫拦不住，角色会被摆到错误位置。
## 所以要等坐标连续两帧不变（= 布局跑完了）再摆。
func _wait_for_stage_slots() -> void:
	var first := character_pool.get_child(0) as Character
	if first == null:
		return
	var last := Vector2.INF
	for _attempt in 8:
		# 用会建页的 getter —— 站位数据本来就要读剧情页，先把它建出来再等它布局
		var stage := Game.stage_page
		var now: Vector2 = stage.get_position_by_name(first.bonus_slot) if stage != null else Vector2.ZERO
		if now != Vector2.ZERO and now == last:
			return
		last = now
		await get_tree().process_frame

func reset_character_positions() -> void:
	await _wait_for_stage_slots()
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
