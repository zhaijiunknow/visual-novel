@tool
class_name Character
extends Control

@export var sv_container: SubViewportContainer
@export var subviewport: SubViewport
@export var texture_rect_avatar: TextureRect
@export var texture_rect_model: TextureRect
@export var story_model: Control

@export var body_parts: Array[AnimatedSprite2D]
@export var optionals_pool: Node2D

var body_part_dict: Dictionary[String, AnimatedSprite2D]
var character_image: Control

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
	
	texture_rect_avatar.visible = false
	
	texture_rect_model.size = sv_container.size
	texture_rect_model.position = sv_container.position
	
	for body_part in body_parts:
		var part_name = body_part.name
		body_part_dict[part_name] = body_part
		
		bonus_part_index_dict[part_name] = {}
		bonus_part_index_dict[part_name]["index"] = 0
		bonus_part_index_dict[part_name]["options"] = \
			Array(body_part_dict[part_name].sprite_frames.get_animation_names())
	
	sv_container.gui_input.connect(
		func (event: InputEvent):
			if event is InputEventMouseButton:
				if event.pressed:
					Main.dragged = true
					drag_offset = event.global_position - sv_container.global_position
	)

var drag_offset: Vector2

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_released():
			Main.dragged = false
	
	if Main.dragged:
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
	Main.clear_connections(bonus_part_index_dict_updated)
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

#region Dialogue Commands

func FadeIn(position_name: String, duration: float = 0) -> void:
	character_image = story_model.duplicate()
	character_image.show()
	character_image.modulate.a = 0
	Game.stage_page.character_image_pool.add_child(character_image)
	character_image.global_position = Game.stage_page.get_position_by_name(position_name)
	await create_tween().tween_property(character_image, "modulate:a", 1, duration).finished

func FadeOut(duration: float = 0) -> void:
	await create_tween().tween_property(character_image, "modulate:a", 0, duration).finished
	character_image.queue_free()

func MoveTo(position_name: String, duration: float = 0.5) -> void:
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

func ClearOptionals() -> void:
	for additional: Sprite2D in optionals_pool.get_children():
		additional.visible = false

func SetOptionals(optionals_string: String) -> void:
	var optionals_array = optionals_string.split(",")
	for additional in optionals_array:
		var addtional_sprite: Sprite2D = optionals_pool.get_node(additional)
		addtional_sprite.visible = true

#endregion
