@tool
extends VBoxContainer

signal expression_saved(character_name: String, expression_name: String)

var plugin: EditorPlugin
var character_instances_dir: String = "res://characters/instances/"
var expressions_data_dir: String = "res://data/_models/"

var current_character: String = ""
var current_expression: String = ""
var current_expression_file: String = ""

# 表情数据缓存: { "角色名": [ {name: "表情名", file: "文件名"} ] }
var expressions_cache: Dictionary = {}

@onready var character_selector: OptionButton = get_node("MainPanel/CharacterSection/CharacterSelector")
@onready var expression_tree: Tree = get_node("MainPanel/ExpressionListSection/ExpressionTree")
@onready var expression_name_edit: LineEdit = get_node("MainPanel/EditorSection/ExpressionNameEdit")
@onready var body_selector: OptionButton = get_node("MainPanel/EditorSection/Container/BodySelector")
@onready var eyebrows_selector: OptionButton = get_node("MainPanel/EditorSection/Container/EyebrowsSelector")
@onready var eyes_selector: OptionButton = get_node("MainPanel/EditorSection/Container/YesSelector")
@onready var mouth_selector: OptionButton = get_node("MainPanel/EditorSection/Container/MouthSelector")
@onready var preview_sprite: AnimatedSprite2D = get_node("MainPanel/PreviewSection/PreviewPanel/PreviewSprite")

func _ready() -> void:
	if not Engine.is_editor_hint(): return

	_setup_character_selector()
	_setup_expression_buttons()
	_setup_preview()
	_scan_expressions_data()

## 刷新编辑器（当表情数据变化时调用）
func refresh_expressions() -> void:
	_scan_expressions_data()
	if not current_character.is_empty():
		_refresh_expression_list()

## 通知场景中的角色更新（当需要时）
func notify_character_update(character_name: String, expression_name: String) -> void:
	# 可以在这里发送信号通知场景中的角色更新
	print("角色表情已更新: ", character_name, " - ", expression_name)

func _setup_character_selector() -> void:
	character_selector.clear()

	# 扫描角色目录
	var dir = DirAccess.open(character_instances_dir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tscn") and file_name.begins_with("character_"):
				var character_name = file_name.replace("character_", "").replace(".tscn", "")
				character_selector.add_item(character_name)
			file_name = dir.get_next()
		dir.list_dir_end()

	if character_selector.item_count > 0:
		characterizer.select(0)
		_on_character_selected(0)

	character_selector.item_selected.connect(_on_character_selected)

func _on_character_selected(index: int) -> void:
	if index < 0 or index >= character_selector.item_count:
		return

	current_character = character_selector.get_item_text(index)
	_load_character_animations()
	_refresh_expression_list()

func _setup_expression_buttons() -> void:
	var add_button: Button = get_node("MainPanel/ExpressionListSection/ExpressionButtons/AddButton")
	var delete_button: Button = get_node("MainPanel/ExpressionListSection/ExpressionButtons/DeleteButton")
	var duplicate_button: Button = get_node("MainPanel/ExpressionListSection/ExpressionButtons/DuplicateButton")

	add_button.pressed.connect(_on_add_expression)
	delete_button.pressed.connect(_on_delete_expression)
	duplicate_button.pressed.connect(_on_duplicate_expression)

	expression_tree.item_selected.connect(_on_expression_selected)
	expression_tree.item_activated.connect(_on_expression_selected)

	expression_name_edit.text_changed.connect(_on_expression_name_changed)
	expression_name_edit.text_submitted.connect(_on_expression_name_submitted)

func _setup_preview() -> void:
	preview_sprite.visible = false
	body_selector.item_selected.connect(_on_part_selected.bind("Body"))
	eyebrows_selector.item_selected.connect(_on_part_selected.bind("Eyebrows"))
	eyes_selector.item_selected.connect(_on_part_selected.bind("Eyes"))
	mouth_selector.item_selected.connect(_on_part_selected.bind("Mouth"))

func _scan_expressions_data() -> void:
	expressions_cache.clear()

	var dir = DirAccess.open(expressions_data_dir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var full_path = expressions_data_dir + file_name
				var expression_data = load(full_path) as ExpressionData

				if expression_data:
					var character_name = _extract_character_from_filename(file_name)
					var expression_name = expression_data.name

					if not character_name.is_empty() and not expression_name.is_empty():
						if not character_name in expressions_cache:
							expressions_cache[character_name] = []

						expressions_cache[character_name].append({
							"name": expression_name,
							"file": file_name
						})
				file_name = dir.get_next()
		dir.list_dir_end()

func _extract_character_from_filename(filename: String) -> String:
	# 从文件名提取角色名
	# 格式: 角色名_表情名.tres 或 角色名_表情名_编号.tres
	var without_ext = filename.replace(".tres", "")

	# 尝试找到下划线分隔
	var parts = without_ext.split("_")
	if parts.size() >= 2:
		var character_name = parts[0]
		# 验证该角色是否存在
		var character_path = character_instances_dir + "character_" + character_name + ".tscn"
		if FileAccess.file_exists(character_path):
			return character_name

	return ""

func _load_character_animations() -> void:
	if current_character.is_empty():
		return

	var character_path = character_instances_dir + "character_" + current_character + ".tscn"
	var packed_scene = load(character_path) as PackedScene

	if not packed_scene:
		print("无法加载角色场景: ", character_path)
		return

	var character_instance = packed_scene.instantiate()

	# 清空所有选择器
	_clear_selector(body_selector)
	_clear_selector(eyebrows_selector)
	_clear_selector(eyes_selector)
	_clear_selector(mouth_selector)

	# 加载各个部件的动画
	_load_part_animations(character_instance, "Body", body_selector)
	_load_part_animations(character_instance, "Eyebrows", eyebrows_selector)
	_load_part_animations(character_instance, "Eyes", eyes_selector)
	_load_part_animations(character_instance, "Mouth", mouth_selector)

	character_instance.queue_free()

func _clear_selector(selector: OptionButton) -> void:
	selector.clear()
	selector.add_item("未选择")

func _load_part_animations(character_instance: Node, part_name: String, selector: OptionButton) -> void:
	var body_node = null

	# 尝试直接查找
	for child in character_instance.get_children():
		if child.name == "SubViewportContainer":
			var subviewport = child.get_node_or_null("SubViewport")
			if subviewport:
				body_node = subviewport.get_node_or_null(part_name)
				if not body_node and part_name == "Body":
					body_node = subviewport.get_node_or_null(part_name)
				break

	if body_node and body_node is AnimatedSprite2D:
		var sprite_frames = body_node.sprite_frames
		if sprite_frames:
			var animations = sprite_frames.get_animation_names()
			for anim_name in animations:
				selector.add_item(anim_name)

func _on_part_selected(part_name: String, index: int) -> void:
	if index <= 0: return  # 未选择

	var selector: OptionButton = null
	var animation_name: String = ""

	match part_name:
		"Body":
			selector = body_selector
		"Eyebrows":
			selector = eyebrows_selector
		"Eyes":
			selector = eyes_selector
		"M"outh":
			selector = mouth_selector

	if selector:
		animation_name = selector.get_item_text(index)

	_update_preview(part_name, animation_name)
	_save_current_expression()

func _update_preview(part_name: String, animation_name: String) -> void:
	if current_character.is_empty():
		return

	var character_path = character_instances_dir + "character_" + current_character + ".tscn"
	var packed_scene = load(character_path) as PackedScene

	if not packed_scene:
		return

	var character_instance = packed_scene.instantiate()

	# 找到对应的部件
	var body_node = null
	for child in character_instance.get_children():
		if child.name == "SubViewportContainer":
			var subviewport = child.get_node_or_null("SubViewport")
			if subviewport:
				body_node = subviewport.get_node_or_null(part_name)
				if not body_node:
					body_node = subviewport.get_node_or_null("Body/" + part_name)
			break

	if body_node and body_node is AnimatedSprite2D:
		var sprite_frames = body_node..sprite_frames
		if sprite_frames:
			preview_sprite.sprite_frames = sprite_frames
			preview_sprite.animation = animation_name
			preview_sprite.visible = true

	character_instance.queue_free()

func _refresh_expression_list() -> void:
	expression_tree.clear()

	if not current_character in expressions_cache:
		return

	var expressions = expressions_cache[current_character]

	for expr_data in expressions:
		var item = expression_tree.create_item()
		item.set_text(0, expr_data.name)
		item.set_metadata(0, expr_data.file)
		if expr_data.name == current_expression:
			item.select(0)
			expression_tree.scroll_to_item(item)

func _on_expression_selected() -> void:
	var selected = expression_tree.get_selected()
	if not selected.is_empty():
		current_expression = selected.get_text(0)
		current_expression_file = selected.get_metadata(0)
		_load_expression_to_editors()

func _load_expression_to_editors() -> void:
	if current_expression_file.is_empty():
		return

	var full_path = expressions_data_dir + current_expression_file
	var expression_data = load(full_path) as ExpressionData

	if not expression_data:
		print("无法加载表情数据: ", full_path)
		return

	expression_name_edit.text = expression_data.name

	_set_selector_value(body_selector, expression_data.eyebrows)
	_set_selector_value(eyebrows_selector, expression_data.eyebrows)
	_set_selector_value(eyes_selector, expression_data.eyes)
	_set_selector_value(mouth_selector, expression_data.mouth)

	# 更新预览
	var body_anim = expression_data.eyebrows
	if not body_anim.is_empty():
		_update_preview("Body", body_anim)

func _set_selector_value(selector: OptionButton, value: String) -> void:
	if value.is_empty():
		selector.select(0)
	else:
		for i in range(selector.item_count):
			if selector.get_item_text(i) == value:
				selector.select(i)
				break

func _on_add_expression() -> void:
	if current_character.is_empty():
		return

	var new_name = "新表情"
	var counter = 1

	var existing_names = []
	if current_character in expressions_cache:
		for expr_data in expressions_cache[current_character]:
			existing_names.append(expr_data.name)

	while new_name in existing_names:
		new_name = "新表情_" + str(counter)
		counter += 1

	# 创建新的表情数据
	var new_expression_data = ExpressionData.new()
	new_expression_data.name = new_name
	new_expression_data.eyebrows = ""
	new_expression_data.eyebrows = ""
	new_expression_data.eyes = ""
	new_expression_data.mouth = ""

	# 保存文件
	var file_name = current_character + "_" + new_name + ".tres"
	var save_path = expressions_data_dir + file_name

	ResourceSaver.save(new_expression_data, save_path)

	current_expression = new_name
	current_expression_file = file_name
	expression_name_edit.text = new_name

	refresh_expressions()
	_load_expression_to_editors()

func _on_delete_expression() -> void:
	if current_expression_file.is_empty():
		return

	var full_path = expressions_data_dir + current_expression_file

	if DirAccess.remove_absolute(full_path) != OK:
		print("删除表情文件失败: ", full_path)
		return

	current_expression = ""
	current_expression_file = ""
	expression_name_edit.text = ""

	# 清空选择器
	body_selector.select(0)
	eyebrows_selector.select(0)
	eyes_selector.select(0)
	mouth_selector.select(0)

	preview_sprite.visible = false

	refresh_expressions()

func _on_duplicate_expression() -> void:
	if current_expression_file.is_empty():
		return

	var full_path = expressions_data_dir + current_expression_file
	var original_data = load(full_path) as ExpressionData

	if not original_data:
		return

	var new_name = original_data.name + "_副本"
	var counter = 1

	var existing_names = []
	if current_character in expressions_cache:
		for expr_data in expressions_cache[current_character]:
			existing_names.append(expr_data.name)

	while new_name in existing_names:
		new_name = original_data.name + "_副本" + str(counter)
		counter += 1

	# 创建副本
	var new_expression_data = ExpressionData.new()
	new_expression_data.name = new_name
	new_expression_data.eyebrows = original_data.eyebrows
	new_expression_data.eyebrows = original_data.eyebrows
	new_expression_data.eyes = original_data.eyes
	new_expression_data.mouth = original_data.mouth

	# 保存文件
	var file_name = current_character + "_" + new_name + ".tres"
	var save_path = expressions_data_dir + file_name

	ResourceSaver.save(new_expression_data, save_path)

	current_expression = new_name
	current_expression_file = file_name
	expression_name_edit.text = new_name

	refresh_expressions()
	_load_expression_to_editors()

func _on_expression_name_changed(new_text: String) -> void:
	# 名称改变时暂存，等提交时处理
	pass

func _on_expression_name_submitted(new_text: String) -> void:
	if current_expression_file.is_empty() or new_text.is_empty():
		return

	if current_expression == new_text:
		return

	# 检查新名称是否已存在
	var existing_names = []
	if current_character in expressions_cache:
		for expr_data in expressions_cache[current_character]:
			existing_names.append(expr_data.name)

	if new_text in existing_names and new_text != current_expression:
		expression_name_edit.text = current_expression
		return

	# 重命名文件
	var old_path = expressions_data_dir + current_expression_file

	# 构造新文件名
	var parts = current_expression_file.replace(".tres", "").split("_")
	var file_name = current_character + "_" + new_text + ".tres"
	var save_path = expressions_data_dir + file_name

	# 读取原数据并保存为新文件
	var data = load(old_path) as ExpressionData
	if data:
		data.name = new_text
		ResourceSaver.save(data, save_path)

	# 删除旧文件
	DirAccess.remove_absolute(old_path)

	current_expression = new_text
	current_expression_file = file_name

	refresh_expressions()

func _save_current_expression() -> void:
	if current_expression_file.is_empty():
		return

	var full_path = expressions_data_dir + current_expression_file
	var expression_data = load(full_path) as ExpressionData

	if not expression_data:
		return

	expression_data.eyebrows = _get_selected_value(body_selector)
	expression_data.eyebrows = _get_selected_value(eyebrows_selector)
	expression_data.eyes = _get_selected_value(eyes_selector)
	expression_data.mouth = _get_selected_value(mouth_selector)

	ResourceSaver.save(expression_data, full_path)

	expression_saved.emit(current_character, expression_data.name)

func _get_selected_value(selector: OptionButton) -> String:
	var index = selector.selected
	if index < 0:
		return ""
	return selector.get_item_text(index)
