@tool
class_name Character
extends Control

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

# 头像「中间过渡态」：离屏渲染固定动作差分，只跟随服装+表情
## 头像固定的动作差分后缀；留空则自动用角色初始身体动画的动作部分
@export var avatar_fixed_action: String = ""
var _avatar_viewport: SubViewport
var _avatar_body: AnimatedSprite2D
var _avatar_part_dict: Dictionary[String, AnimatedSprite2D] = {}
var _avatar_optionals: Node2D
var _avatar_action: String = ""
var _avatar_crop_pad: int = 24

func _request_viewport_update() -> void:
	if not _viewport_always_update:
		subviewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _setup_avatar_render() -> void:
	# 头像裁剪源：换成一个离屏「中间过渡态」SubViewport，
	# 固定动作差分后缀，只跟随服装+表情，动作差分切换不影响头像
	if not dialogue_box or not dialogue_box.preview_texture:
		return
	if not body_part_dict.has("Body"):
		return
	var old_preview := dialogue_box.preview_texture as AtlasTexture
	if not old_preview:
		return
	var region := old_preview.region
	if region.size.x <= 0.0 or region.size.y <= 0.0:
		region = Rect2(Vector2.ZERO, Vector2(subviewport.size))
	var pad := float(_avatar_crop_pad)

	_avatar_viewport = SubViewport.new()
	_avatar_viewport.size = Vector2i(
		int(region.size.x) + _avatar_crop_pad * 2,
		int(region.size.y) + _avatar_crop_pad * 2
	)
	_avatar_viewport.transparent_bg = true
	_avatar_viewport.disable_3d = true
	_avatar_viewport.handle_input_locally = false
	_avatar_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_avatar_viewport)

	# 复制整棵 Body 子树（Body + 表情层 + 附加层），sprite_frames 资源共享
	_avatar_body = body_part_dict["Body"].duplicate(0) as AnimatedSprite2D
	# 平移使头像裁剪区内容落到 [pad, pad+region.size]，子节点自动跟随
	_avatar_body.position = body_part_dict["Body"].position - (region.position - Vector2(pad, pad))
	_avatar_viewport.add_child(_avatar_body)

	_avatar_part_dict.clear()
	for part: Node in _avatar_body.get_children():
		if part is AnimatedSprite2D:
			_avatar_part_dict[part.name] = part as AnimatedSprite2D
		elif part.name == "Optionals":
			_avatar_optionals = part as Node2D

	# 固定动作后缀：优先用 avatar_fixed_action，否则用当前身体动画的动作部分，之后不再变
	var body_anim: String = body_part_dict["Body"].animation
	if avatar_fixed_action != "":
		_avatar_action = avatar_fixed_action
	elif "-" in body_anim:
		_avatar_action = body_anim.split("-")[1]

	# 新 AtlasTexture 裁剪头像视口，替换 preview_texture（走 setter 更新头像显示）
	var new_preview := AtlasTexture.new()
	new_preview.atlas = _avatar_viewport.get_texture()
	new_preview.region = Rect2(pad, pad, region.size.x, region.size.y)
	dialogue_box.preview_texture = new_preview

	_sync_avatar()

func _sync_avatar() -> void:
	if not _avatar_viewport or not _avatar_body:
		return
	# 服装 + 固定动作
	var body_anim: String = body_part_dict["Body"].animation
	var costume := body_anim.split("-")[0] if "-" in body_anim else body_anim
	var target := body_anim
	if costume and _avatar_action:
		target = "%s-%s" % [costume, _avatar_action]
	var anim_names: PackedStringArray = _avatar_body.sprite_frames.get_animation_names()
	if not anim_names.has(target):
		target = _find_costume_animation(_avatar_body.sprite_frames, costume)
		if target == "":
			target = body_anim
	if _avatar_body.animation != target:
		_avatar_body.animation = target
	# 表情层
	for part_name in _avatar_part_dict:
		var main_part: AnimatedSprite2D = body_part_dict.get(part_name)
		if main_part:
			_avatar_part_dict[part_name].animation = main_part.animation
	# 附加层
	if _avatar_optionals and optionals_pool:
		var avatar_children: Array = _avatar_optionals.get_children()
		var main_children: Array = optionals_pool.get_children()
		for i in mini(avatar_children.size(), main_children.size()):
			avatar_children[i].visible = main_children[i].visible
	_request_avatar_viewport_update()

func _find_costume_animation(sprite_frames: SpriteFrames, costume: String) -> String:
	# 该服装前缀下的第一条动画（余洛琛这类服装特异动作名时，按服装冻结在第一张）
	var prefix := costume + "-"
	for anim in sprite_frames.get_animation_names():
		if anim.begins_with(prefix):
			return anim
	return ""

func _request_avatar_viewport_update() -> void:
	if _avatar_viewport:
		_avatar_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

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

## 立绘鉴赏里这个角色站的剧情站位槽（LeftMost/Left/Center/Right/RightMost），单人出场默认 Center
@export var bonus_slot: String = "Center"

## 鉴赏页里容器的初始局部位置，用来撤销玩家的拖拽
var _bonus_home_container_position: Vector2
var _bonus_home_recorded: bool = false

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
	_setup_avatar_render()

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
	_sync_avatar()

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

static func redistribute_stage_characters(instant: bool = false, new_image: Control = null) -> void:
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
		var adjusted_pos := _get_adjusted_stage_position(image, target_pos)
		if instant or image == new_image:
			image.global_position = adjusted_pos
		else:
			Game.stage_page.create_tween().tween_property(image, "global_position", adjusted_pos, 0.3)

static func _get_adjusted_stage_position(image: Control, target_pos: Vector2) -> Vector2:
	# 补偿 story_model 内部 TextureRect_Model 的偏移，让视觉中心对准槽位
	var tex_rect: TextureRect = image.get_node_or_null("TextureRect_Model") as TextureRect
	var center_off_x: float = (tex_rect.offset_left + tex_rect.offset_right) / 2.0 if tex_rect else 0.0
	return target_pos - Vector2(center_off_x, 0)

## 根据当前角色数量，把 character_image_pool 里的所有子节点分配到对应槽位
func _redistribute_characters(new_image: Control = null) -> void:
	redistribute_stage_characters(false, new_image)

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
	_sync_avatar()

func SetBody(body_name: String) -> void:
	body_part_dict["Body"].animation = body_name
	_request_viewport_update()
	_sync_avatar()

func SetExpression(expression_name: String) -> void:
	current_expression = expression_name
	var expression_data: Dictionary = Expressions.data[name][expression_name]
	for part_name in expression_data.keys():
		var part_value: String = expression_data[part_name]
		body_part_dict[part_name].animation = part_value
		_request_viewport_update()
	_sync_avatar()

func ClearOptionals() -> void:
	for additional: Sprite2D in optionals_pool.get_children():
		additional.visible = false
		_request_viewport_update()
	_sync_avatar()

func SetOptionals(optionals_string: String) -> void:
	var optionals_array = optionals_string.split(",")
	for additional in optionals_array:
		var addtional_sprite: Sprite2D = optionals_pool.get_node(additional)
		addtional_sprite.visible = true
		_request_viewport_update()
	_sync_avatar()

#endregion

#region 立绘鉴赏

## 按剧情站位槽摆放：先撤销玩家的拖拽，再让容器矩形的中心对准槽位、
## 上边缘对齐剧情里模型的上边缘（与 _get_adjusted_stage_position 同一套对位，构图和剧情一致）
func apply_bonus_slot() -> void:
	if not _bonus_home_recorded:
		_bonus_home_container_position = sv_container.position
		_bonus_home_recorded = true
	sv_container.position = _bonus_home_container_position
	if not (bonus_slot in POSITION_SLOTS):
		push_warning("Character: 未知鉴赏站位 %s（%s）" % [bonus_slot, name])
		return
	var slot_pos: Vector2 = Game.stage_page.get_position_by_name(bonus_slot)
	if slot_pos == Vector2.ZERO:
		# 站位标记还没布局出坐标（都是 0），摆下去会把立绘推到屏幕外，宁可不动
		push_warning("Character: 站位 %s 坐标为 0，跳过摆放（%s）" % [bonus_slot, name])
		return
	var model := story_model.get_node_or_null("TextureRect_Model") as TextureRect
	# 剧情里 StoryModel 会被摆到 model_pos，模型矩形的上边则在其 offset_top 处
	var model_pos := _get_adjusted_stage_position(story_model, slot_pos)
	var container_top: float = model_pos.y + (model.offset_top if model else sv_container.position.y)
	global_position = Vector2(
		slot_pos.x - sv_container.position.x - sv_container.size.x / 2.0,
		container_top - sv_container.position.y
	)

#endregion
