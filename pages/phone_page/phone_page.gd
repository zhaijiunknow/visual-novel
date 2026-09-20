class_name PhonePage
extends CanvasLayer

signal reply_selected(next_id: String)

@export var home_page: Control
@export var messenger_page: Control
@export var chat_page: Control
@export var phoneOut: Control

@export var background: Control
@export var phone: Control
@export var phone_icon_message: PhoneIcon
@export var phone_icon_photo: PhoneIcon
@export var phone_icon_music: PhoneIcon
@export var phone_icon_book: PhoneIcon

@export var chat_message_pool: Control
@export var reply_selection_pool: Control
@export var chat_pool: Control

@export var back_button: TextureButton
@export var messenger_back_button: TextureButton
@export var label_chat_name: Label
@export var label_phone_date: Label
@export var label_time: Label
@export var label_location: Label

@export var typing_tip: PanelContainer

@export var self_avatar: Texture2D

@export var chat_data_pool: Array[ChatData]
var pending_reply_options: Array[Dictionary] = []

const SLIDE_DURATION: float = 0.5
const PAGE_TRANSITION_DURATION: float = 0.25

# 是否由剧情触发（ShowPhone）
var story_mode: bool = false
## 跟着手机一起滑入/滑出的层（本体 + 外壳）：各自记下静止时的 offset 与滑出距离
var _slide_parts: Array[Dictionary] = []
var _tween: Tween
var _page_tween: Tween
var _transitioning: bool = false

func _ready() -> void:
	_setup_slide_parts()
	chat_page.visible = false

	back_button.pressed.connect(_transition_to_messenger)
	messenger_back_button.pressed.connect(
		func():
			if not story_mode:
				messenger_page.visible = false
	)
	background.gui_input.connect(
		func(event: InputEvent):
			if story_mode: return
			if event is InputEventMouseButton:
				if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					close()
	)
	phone_icon_message.clicked.connect(
		func():
			messenger_page.visible = true
			update_chat_list()
	)
	phone_icon_photo.clicked.connect(
		func():
			Game.bonus_page.tab_gallery.select()
			Game.switch_to_page(Game.bonus_page, true, true)
	)
	phone_icon_music.clicked.connect(
		func():
			Game.bonus_page.tab_music.select()
			Game.switch_to_page(Game.bonus_page, true, true)
	)
	phone_icon_book.clicked.connect(
		func():
			Game.switch_to_page(Game.book_page, true, true)
	)


# ─── 手机外观的滑入/滑出（本体 + 外壳一起动） ───

## 记录各层静止时的 offset。静止时 offset_bottom 贴着屏幕底(0)，
## 所以 -offset_top 就是这一层的高度，也就是要滑出屏幕的距离——两层高度不同，不能共用一个位移量。
func _setup_slide_parts() -> void:
	for node: Control in [phone, phoneOut]:
		var rest_top: float = node.offset_top
		_slide_parts.append({
			"node": node,
			"rest_top": rest_top,
			"rest_bottom": node.offset_bottom,
			"distance": -rest_top,
		})

## t = 1 完全滑出屏幕，t = 0 停在静止位置。立即生效，不走动画
func _set_slide_offsets(t: float) -> void:
	for part in _slide_parts:
		var node: Control = part["node"]
		var down: float = part["distance"] * t
		node.offset_top = part["rest_top"] + down
		node.offset_bottom = part["rest_bottom"] + down

## 从当前位置补间到 t 对应的位置
func _tween_slide_offsets(t: float, duration: float,
		ease: Tween.EaseType, trans: Tween.TransitionType) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_ease(ease).set_trans(trans).set_parallel(true)
	for part in _slide_parts:
		var node: Control = part["node"]
		var down: float = part["distance"] * t
		_tween.tween_property(node, "offset_top", part["rest_top"] + down, duration)
		_tween.tween_property(node, "offset_bottom", part["rest_bottom"] + down, duration)
	await _tween.finished


func open(is_story: bool = false, initial_chat_character: String = "") -> void:
	story_mode = is_story
	messenger_back_button.visible = not story_mode
	home_page.visible = not story_mode
	messenger_page.visible = false
	chat_page.visible = story_mode
	chat_page.modulate.a = 1.0
	chat_page.scale = Vector2.ONE
	messenger_page.modulate.a = 1.0

	# 剧情模式进入时清理聊天视图，避免多次 ShowPhone 之间消息堆积
	if story_mode:
		Tools.clear_children(chat_message_pool)
		Tools.clear_children(reply_selection_pool)
		active_chat_character = ""
		label_chat_name.text = ""
		_prime_story_chat_title(initial_chat_character)

	show()

	# 从屏幕下方滑入：本体和外壳一起，先瞬移到屏幕外再补间回原位
	_set_slide_offsets(1.0)
	await _tween_slide_offsets(0.0, SLIDE_DURATION, Tween.EASE_OUT, Tween.TRANS_CUBIC)


func close() -> void:
	await _tween_slide_offsets(1.0, SLIDE_DURATION, Tween.EASE_IN, Tween.TRANS_CUBIC)
	hide()


func update_chat_list() -> void:
	Tools.clear_children(chat_pool)
	for chat_data in chat_data_pool:
		chat_data.avatar = get_phone_avatar(chat_data.character_name)
		var chat: Chat = Prefabs.chat.instantiate()
		chat_pool.add_child(chat)
		chat.set_chat_data(chat_data)
		chat.gui_input.connect(
			func(event: InputEvent):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					open_chat(chat_data)
		)


# ─── 剧情模式消息管理 ───

func _prime_story_chat_title(character_name: String) -> void:
	if character_name.is_empty() or character_name == "周腾":
		return
	active_chat_character = character_name
	label_chat_name.text = get_phone_nickname(character_name)


func _scroll_chat_to_bottom() -> void:
	await get_tree().process_frame
	var scroll: ScrollContainer = chat_message_pool.get_parent()
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(scroll, "scroll_vertical", bar.max_value, 0.3)


func _add_chat_message(character_name: String, text: String, silent: bool = false) -> void:
	var chat_message: ChatMessage = Prefabs.chat_message.instantiate()
	chat_message_pool.add_child(chat_message)
	var type = Enums.SenderType.SELF \
		if character_name == "周腾" else Enums.SenderType.OTHER
	var avatar = get_phone_avatar(character_name)
	chat_message.setup(type, text, avatar)
	if silent:
		chat_message.modulate.a = 1.0
	else:
		chat_message.modulate.a = 0.0
		chat_message.create_tween().tween_property(chat_message, "modulate:a", 1.0, 0.3)
		AudioManager.audio_player_sound.stream = preload("res://assets/system_sounds/奇迹书音效/手机发消息音效.wav")
		AudioManager.audio_player_sound.play()


func show_dialogue_message(character_name: String, text: String) -> void:
	_prime_story_chat_title(character_name)
	_add_chat_message(character_name, text)
	add_message(character_name, text)
	_scroll_chat_to_bottom()

func get_bridge_phone_state() -> Dictionary:
	return {
		"visible": visible,
		"story_mode": story_mode,
		"active_chat_character": active_chat_character,
		"label_chat_name": label_chat_name.text,
		"date": label_phone_date.text,
		"time": label_time.text,
		"location": label_location.text,
		"pending_replies": pending_reply_options.duplicate(true),
		"chats": _serialize_chat_data_pool(),
	}

func choose_reply_from_bridge(index: int = -1, next_id: String = "") -> bool:
	var resolved_next_id := _resolve_pending_reply_next_id(index, next_id)
	if resolved_next_id == "":
		return false
	var selected_text := _get_pending_reply_text(resolved_next_id)
	clear_reply_selections()
	await show_dialogue_message("周腾", selected_text)
	reply_selected.emit(resolved_next_id)
	return true

func show_reply_options(responses) -> void:
	clear_reply_selections()
	for i in responses.size():
		var response = responses[i]
		pending_reply_options.append({
			"index": i,
			"text": response.text,
			"next_id": response.next_id,
		})
		var reply: ReplySelection = Prefabs.reply_selection.instantiate()
		reply_selection_pool.add_child(reply)
		reply.setup(response.text, response.next_id)
		reply.reply_clicked.connect(_on_reply_clicked)
	typing_tip.modulate.a = 1.0


func _on_reply_clicked(text: String, next_id: String) -> void:
	# 数据已在信号参数中（值拷贝），不存在 freed node 风险
	clear_reply_selections()
	await show_dialogue_message("周腾", text)
	reply_selected.emit(next_id)


# ─── 页面过渡 ───

func open_chat(chat_data: ChatData) -> void:
	if _transitioning: return
	active_chat_character = chat_data.character_name
	chat_page.visible = true
	chat_page.modulate.a = 0
	reload_active_chat()
	await _scroll_chat_to_bottom()
	_transition_to_chat()


func reload_active_chat() -> void:
	Tools.clear_children(chat_message_pool)
	if active_chat_character.is_empty():
		return
	var chat_data = get_chat_data(active_chat_character)
	label_chat_name.text = get_phone_nickname(chat_data.character_name)
	for i in chat_data.messages.size():
		var sender = chat_data.senders[i] if i < chat_data.senders.size() else ""
		_add_chat_message(sender, chat_data.messages[i], true)


func _transition_to_chat() -> void:
	if _transitioning: return
	_transitioning = true
	if _page_tween: _page_tween.kill()
	# Chat 从略微缩小+透明淡入
	chat_page.visible = true
	chat_page.modulate.a = 0
	chat_page.pivot_offset = chat_page.size / 2
	chat_page.scale = Vector2(0.95, 0.95)
	_page_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC).set_parallel(true)
	_page_tween.tween_property(chat_page, "modulate:a", 1.0, PAGE_TRANSITION_DURATION)
	_page_tween.tween_property(chat_page, "scale", Vector2.ONE, PAGE_TRANSITION_DURATION)
	_page_tween.tween_property(messenger_page, "modulate:a", 0.0, PAGE_TRANSITION_DURATION * 0.6)
	await _page_tween.finished
	messenger_page.visible = false
	messenger_page.modulate.a = 1.0
	_transitioning = false


func _transition_to_messenger() -> void:
	if _transitioning: return
	_transitioning = true
	update_chat_list()
	if _page_tween: _page_tween.kill()
	messenger_page.visible = true
	messenger_page.modulate.a = 0
	_page_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC).set_parallel(true)
	_page_tween.tween_property(messenger_page, "modulate:a", 1.0, PAGE_TRANSITION_DURATION)
	_page_tween.tween_property(chat_page, "modulate:a", 0.0, PAGE_TRANSITION_DURATION * 0.6)
	_page_tween.tween_property(chat_page, "scale", Vector2(0.95, 0.95), PAGE_TRANSITION_DURATION)
	await _page_tween.finished
	chat_page.visible = false
	chat_page.scale = Vector2.ONE
	_transitioning = false


# ─── 数据管理 ───

func get_phone_avatar(character_name: String) -> Texture2D:
	if character_name == "周腾":
		return self_avatar
	if Stage.character_dict.has(character_name):
		return Stage.character_dict[character_name].phone_avatar
	return null

func get_phone_nickname(character_name: String) -> String:
	if Stage.character_dict.has(character_name):
		var nickname = Stage.character_dict[character_name].phone_nickname
		if nickname != "":
			return nickname
	return character_name

func get_chat_data(character_name: String) -> ChatData:
	for chat_data in chat_data_pool:
		if chat_data.character_name == character_name:
			return chat_data
	var chat_data = ChatData.new()
	chat_data.character_name = character_name
	chat_data.avatar = get_phone_avatar(character_name)
	chat_data_pool.append(chat_data)
	return chat_data


var active_chat_character: String = ""

func add_message(character_name: String, text: String) -> void:
	if character_name != "周腾":
		active_chat_character = character_name
	var chat_data = get_chat_data(active_chat_character)
	chat_data.messages.append(text)
	chat_data.senders.append(character_name)

func _serialize_chat_data_pool() -> Array[Dictionary]:
	var chats: Array[Dictionary] = []
	for chat_data in chat_data_pool:
		chats.append({
			"character_name": chat_data.character_name,
			"messages": chat_data.messages.duplicate(),
			"senders": chat_data.senders.duplicate(),
		})
	return chats

func _resolve_pending_reply_next_id(index: int, next_id: String) -> String:
	if next_id != "":
		for option in pending_reply_options:
			if str(option.get("next_id", "")) == next_id:
				return next_id
	if index >= 0 and index < pending_reply_options.size():
		return str(pending_reply_options[index].get("next_id", ""))
	return ""

func _get_pending_reply_text(next_id: String) -> String:
	for option in pending_reply_options:
		if str(option.get("next_id", "")) == next_id:
			return str(option.get("text", ""))
	return ""

func clear_reply_selections() -> void:
	pending_reply_options.clear()
	Tools.clear_children(reply_selection_pool)
	typing_tip.modulate.a = 0.0


func clear_all() -> void:
	pending_reply_options.clear()
	chat_data_pool.clear()
	Tools.clear_children(chat_message_pool)
	Tools.clear_children(chat_pool)
	Tools.clear_children(reply_selection_pool)
