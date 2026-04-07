class_name PhonePage
extends CanvasLayer

signal reply_selected(next_id: String)

@export var home_page: Control
@export var messenger_page: Control
@export var chat_page: Control

@export var background: Control
@export var phone: TextureRect
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

@export var self_avatar: Texture2D

@export var chat_data_pool: Array[ChatData]

const SLIDE_DURATION: float = 0.4
const PAGE_TRANSITION_DURATION: float = 0.25

# 是否由剧情触发（ShowPhone）
var story_mode: bool = false
var _phone_rest_offset_top: float
var _phone_slide_distance: float
var _tween: Tween
var _page_tween: Tween
var _transitioning: bool = false

func _ready() -> void:
	_phone_rest_offset_top = phone.offset_top
	_phone_slide_distance = -_phone_rest_offset_top  # 手机高度，即下移距离
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


func open(is_story: bool = false) -> void:
	story_mode = is_story
	messenger_back_button.visible = not story_mode
	home_page.visible = not story_mode
	messenger_page.visible = false
	chat_page.visible = story_mode

	# 剧情模式进入时清理聊天视图，避免多次 ShowPhone 之间消息堆积
	if story_mode:
		Tools.clear_children(chat_message_pool)
		Tools.clear_children(reply_selection_pool)
		active_chat_character = ""

	show()

	# 从屏幕下方滑入：整体下移 _phone_slide_distance 后 tween 回原位
	phone.offset_top = _phone_rest_offset_top + _phone_slide_distance
	phone.offset_bottom = _phone_slide_distance
	if _tween: _tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC).set_parallel(true)
	_tween.tween_property(phone, "offset_top", _phone_rest_offset_top, SLIDE_DURATION)
	_tween.tween_property(phone, "offset_bottom", 0.0, SLIDE_DURATION)
	await _tween.finished


func close() -> void:
	if _tween: _tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC).set_parallel(true)
	_tween.tween_property(phone, "offset_top", _phone_rest_offset_top + _phone_slide_distance, SLIDE_DURATION)
	_tween.tween_property(phone, "offset_bottom", _phone_slide_distance, SLIDE_DURATION)
	await _tween.finished
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

func show_dialogue_message(character_name: String, text: String) -> void:
	var chat_message: ChatMessage = Prefabs.chat_message.instantiate()
	chat_message_pool.add_child(chat_message)
	var type = Enums.SenderType.SELF \
		if character_name == "周腾" else Enums.SenderType.OTHER
	var avatar = get_phone_avatar(character_name)
	chat_message.setup(type, text, avatar)
	add_message(character_name, text)


func show_reply_options(responses) -> void:
	clear_reply_selections()
	for response in responses:
		var reply: ReplySelection = Prefabs.reply_selection.instantiate()
		reply_selection_pool.add_child(reply)
		reply.setup(response.text, response.next_id)
		reply.reply_clicked.connect(_on_reply_clicked)


func _on_reply_clicked(text: String, next_id: String) -> void:
	# 数据已在信号参数中（值拷贝），不存在 freed node 风险
	clear_reply_selections()
	await show_dialogue_message("周腾", text)
	reply_selected.emit(next_id)


# ─── 页面过渡 ───

func open_chat(chat_data: ChatData) -> void:
	if _transitioning: return
	label_chat_name.text = chat_data.character_name
	Tools.clear_children(chat_message_pool)
	# 在不可见状态下加载消息，保持布局计算
	chat_page.visible = true
	chat_page.modulate.a = 0
	for i in chat_data.messages.size():
		var chat_message: ChatMessage = Prefabs.chat_message.instantiate()
		chat_message_pool.add_child(chat_message)
		var sender = chat_data.senders[i] if i < chat_data.senders.size() else ""
		var type = Enums.SenderType.SELF if sender == "周腾" else Enums.SenderType.OTHER
		var avatar = get_phone_avatar(sender)
		await chat_message.setup(type, chat_data.messages[i], avatar)
	# 加载完成，执行过渡
	_transition_to_chat()


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


func clear_reply_selections() -> void:
	Tools.clear_children(reply_selection_pool)


func clear_all() -> void:
	chat_data_pool.clear()
	Tools.clear_children(chat_message_pool)
	Tools.clear_children(chat_pool)
	Tools.clear_children(reply_selection_pool)
