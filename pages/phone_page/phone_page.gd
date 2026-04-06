class_name PhonePage
extends CanvasLayer

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

@export var chat_data_pool: Array[ChatData]

const SLIDE_DURATION: float = 0.4

# 是否由剧情触发（ShowPhone）
var story_mode: bool = false
var _phone_rest_offset_top: float
var _phone_slide_distance: float
var _tween: Tween

func _ready() -> void:
	_phone_rest_offset_top = phone.offset_top
	_phone_slide_distance = -_phone_rest_offset_top  # 手机高度，即下移距离
	chat_page.visible = false

	back_button.pressed.connect(
		func(): chat_page.visible = false
	)
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
			Game.bonus_page.show()
			Game.bonus_page.layer = 2
			Main.bonus_tab_index = 1
	)
	phone_icon_music.clicked.connect(
		func():
			Game.bonus_page.show()
			Game.bonus_page.layer = 2
			Main.bonus_tab_index = 2
	)
	phone_icon_book.clicked.connect(
		func():
			Game.book_page.show()
			Game.book_page.layer = 2
	)


func open(is_story: bool = false) -> void:
	story_mode = is_story
	messenger_back_button.visible = not story_mode
	home_page.visible = not story_mode
	messenger_page.visible = false
	chat_page.visible = story_mode

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
		var chat: Chat = Prefabs.chat.instantiate()
		chat_pool.add_child(chat)
		chat.set_chat_data(chat_data)


func clear_reply_selections() -> void:
	for child in reply_selection_pool.get_children():
		reply_selection_pool.remove_child(child)
		child.queue_free()
