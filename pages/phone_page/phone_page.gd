class_name PhonePage
extends CanvasLayer

@export var home_page: Control
@export var messenger_page: Control
@export var chat_page: Control

@export var background: Control
@export var phone_icon_message: PhoneIcon
@export var phone_icon_photo: PhoneIcon
@export var phone_icon_music: PhoneIcon
@export var phone_icon_book: PhoneIcon

@export var chat_message_pool: Control
@export var reply_selection_pool: Control
@export var chat_pool: Control

@export var back_button: TextureButton

func _ready() -> void:
	chat_page.visible = false
	back_button.pressed.connect(
		func (): chat_page.visible = false
	)
	background.gui_input.connect(
		func (event: InputEvent):
			if event is InputEventMouseButton:
				if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					hide()
	)
	phone_icon_message.clicked.connect(
		func ():
			chat_page.visible = true
	)
	
	phone_icon_photo.clicked.connect(
		func ():
			Game.bonus_page.show()
			Game.bonus_page.layer = 2
			Main.bonus_tab_index = 1
	)
	
	phone_icon_music.clicked.connect(
		func ():
			Game.bonus_page.show()
			Game.bonus_page.layer = 2
			Main.bonus_tab_index = 2
	)
	
	phone_icon_book.clicked.connect(
		func ():
			Game.book_page.show()
			Game.book_page.layer = 2
	)

func clear_reply_selections() -> void:
	for child in reply_selection_pool.get_children():
		reply_selection_pool.remove_child(child)
		child.queue_free()
