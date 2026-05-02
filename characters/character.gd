@tool
class_name Character
extends Control

@export var speaking_mouth: String
@export var sv_container: SubViewportContainer
@export var subviewport: SubViewport
@export var story_model: Control

@export var phone_avatar: Texture2D
@export var phone_nickname: String = ""

@export var body_parts: Array[AnimatedSprite2D]
@export var optionals_pool: Node2D

@export var dialogue_box: DialogueBox

var current_expression: String
var body_part_dict: Dictionary[String, AnimatedSprite2D]
var character_image: Control
var current_position: String
var _viewport_always_update: bool = false

func _request_viewport_update() -> void:
	if not _viewport_always_update:
		subviewport.render_target_update_mode = SubViewport.UPDATE_ONCE

@export var movable: bool

var body_scale_factor: float = 0.5:
	set(value):
		body_scale_factor = value
		var scale_range = 1 - min_scale_factor
		var s = body_scale_factor * scale_range
		var scale_factor = min_scale_factor + s
		sv_container.scale = Vector2(scale_factor, scale_factor)

var min_scale_factor: float:
	get:
		return abs(sv_container.position.y) / sv_container.size.y

# This is for Character Bonus only
signal bonus_part_index_dict_updated
var bonus_part_index_dict: Dictionary[String, Dictionary]

func _ready() -> void:
	if Engine.is_editor_hint(): return
	
	set_process_input(movable)
	subviewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	
	for body_part in body_parts:
		var part_name = body_part.name
		body_part_dict[part_name] = body_part
		
		var options = Array(body_part_dict[part_name].sprite_frames.get_animation_names())
		var current_index = options.find(body_part.animation)
		bonus_part_index_dict[part_name] = {}
		bonus_part_index_dict[part_name]["index"] = current_index if current_index >= 0 else 0
		bonus_part_index_dict[part_name]["options"] = options
	
	sv_container.gui_input.connect(
		func(event: InputEvent):
			if not movable: return
			if event is InputEventMouseButton:
				if event.pressed:
					dragged = true
					drag_offset = event.global_position - sv_container.global_position
	)
	
	ClearOptionals()

var dragged: bool
var drag_offset: Vector2

func _input(event: InputEvent) -> void:
	if not movable: return
	if event is InputEventMouseButton:
		if event.is_released():
			dragged = false
	
	if dragged:
		if event is InputEventMouseMotion:
			sv_container.global_position = event.global_position - drag_offset
			

func update_bonus_part_index(part_name: String, increment: int) -> void:
	bonus_part_index_dict[part_name].index += increment
	var index: int = bonus_part_index_dict[part_name].index
	var options: Array = bonus_part_index_dict[part_name].options
	if index < 0: bonus_part_index_dict[part_name].index = options.size() - 1
	if index >= options.size(): bonus_part_index_dict[part_name].index = 0
	var body_part: AnimatedSprite2D = body_part_dict[part_name]
	index = bonus_part_index_dict[part_name].index
	body_part.animation = bonus_part_index_dict[part_name].options[index]
	Tools.clear_connections(bonus_part_index_dict_updated)
	bonus_part_index_dict_updated.emit()

#@export_tool_button("Print SetParts") var print_set_parts = func():
	#var part_texts = []
	#for part in body_parts:
		#part_texts.append("%s:%s" % [part.name, part.animation])
	#print("""Character("%s").SetParts("%s")""" % [name, ",".join(part_texts)])

@export_tool_button("复制到剪贴板") var to_clipboard = func():
	var part_texts: Array[String] = []
	var part_tr = {
		"Eyebrows": "眉毛",
		"Eyes": "眼睛",
		"Mouth": "嘴巴",
	}
	print()
	print(name)
	for part in body_parts:
		if part.name == "Body": continue
		part_texts.append(part.animation)
		print("%s:%s" % [part_tr[part.name], part.animation])
	DisplayServer.clipboard_set("	".join(part_texts))

func get_character_data() -> CharacterData:
	var character_data = CharacterData.new()
	character_data.character_name = name
	character_data.body = body_part_dict["Body"].animation
	character_data.eyebrows = body_part_dict["Eyebrows"].animation
	character_data.eyes = body_part_dict["Eyes"].animation
	character_data.mouth = body_part_dict["Mouth"].animation
	var optionals: Array[String] = []
	for optional: Node2D in optionals_pool.get_children():
		if optional.visible:
			optionals.append(optional.name)
	character_data.optionals = optionals
	character_data.position = current_position
	return character_data

func set_character_data(character_data: CharacterData) -> void:
	body_part_dict["Body"].animation = character_data.body
	body_part_dict["Eyebrows"].animation = character_data.eyebrows
	body_part_dict["Eyes"].animation = character_data.eyes
	body_part_dict["Mouth"].animation = character_data.mouth
	current_position = character_data.position
	ClearOptionals()
	for optional: String in character_data.optionals:
		SetOptionals(optional)
	_request_viewport_update()

#region Dialogue Commands

#─── 角色站位分配 ───

const POSITION_SLOTS := ["LeftMost", "Left", "Center", "Right", "RightMost"]

## 返回角色数量对应的槽位索引
static func _slot_indices_for_count(count: int) -> Array:
	match count:
		1: return [2]           # Center
		2: return [1, 3]         # Left, Right
		3: return [1, 2, 3]      # Left, Center, Right
		4: return [0, 1, 3, 4]   # LeftMost, Left, Right, RightMost
		_: return [0, 1, 2, 3, 4] # 5 或更多：全部 5 槽

## 根据当前角色数量，把 character_image_pool 里的所有子节点分配到对应槽位
func _redistribute_characters(new_image: Control = null) -> void:
	var pool = Game.stage_page.character_image_pool
	var children = pool.get_children()
	var count = children.size()
	if count == 0:
		return
	var indices = _slot_indices_for_count(count)
	for i in count:
		var image: Control = children[i]
		var slot_name = POSITION_SLOTS[indices[i]]
		var target_pos: Vector2 = Game.stage_page.get_position_by_name(slot_name)
		# 补偿 story_model 内部 TextureRect_Model 的偏移，让视觉中心对准槽位
		var tex_rect: TextureRect = image.get_node_or_null("TextureRect_Model") as TextureRect
		var center_off_x: float = (tex_rect.offset_left + tex_rect.offset_right) / 2.0 if tex_rect else 0.0
		var adjusted_pos := target_pos - Vector2(center_off_x, 0)
		if image == new_image:
			image.global_position = adjusted_pos
		else:
			create_tween().tween_property(image, "global_position", adjusted_pos, 0.3)

func FadeIn(position_name: String, duration: float = 0.5) -> void:
	current_position = position_name
	character_image = story_model.duplicate()
	Game.stage_page.character_image_pool.add_child(character_image)
	_redistribute_characters(character_image)
	character_image.show()
	character_image.modulate.a = 0
	await create_tween().tween_property(character_image, "modulate:a", 1, duration).finished

func FadeOut(duration: float = 0.5) -> void:
	if not character_image: return
	current_position = ""
	await create_tween().tween_property(character_image, "modulate:a", 0, duration).finished
	character_image.queue_free()
	await get_tree().process_frame
	_redistribute_characters()

func MoveTo(position_name: String, duration: float = 0.5) -> void:
	current_position = position_name
	var target_position: Vector2 = Game.stage_page.get_position_by_name(position_name)
	await create_tween().tween_property(character_image, "global_position", target_position, duration).finished

# Example: SetParts("Body:校服,Eye:悲伤")
func SetParts(parts_string: String) -> void:
	var parts_array = parts_string.split(",")
	for part in parts_array:
		var part_item = part.split(":")
		var part_name = part_item[0]
		var item_name = part_item[1]
		body_part_dict[part_name].animation = item_name
		_request_viewport_update()

func SetBody(body_name: String) -> void:
	body_part_dict["Body"].animation = body_name
	_request_viewport_update()

func SetExpression(expression_name: String) -> void:
	current_expression = expression_name
	var expression_data: Dictionary = Expressions.data[name][expression_name]
	for part_name in expression_data.keys():
		var part_value: String = expression_data[part_name]
		body_part_dict[part_name].animation = part_value
		_request_viewport_update()

func ClearOptionals() -> void:
	for additional: Sprite2D in optionals_pool.get_children():
		additional.visible = false
		_request_viewport_update()

func SetOptionals(optionals_string: String) -> void:
	var optionals_array = optionals_string.split(",")
	for additional in optionals_array:
		var addtional_sprite: Sprite2D = optionals_pool.get_node(additional)
		addtional_sprite.visible = true
		_request_viewport_update()

#endregion
