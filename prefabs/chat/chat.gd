class_name Chat
extends PanelContainer

@export var profile_image: TextureRect
@export var label_name: Label
@export var label_preview: Label
@export var label_unread_count: Label
@export var unread_badge: PanelContainer

func set_chat_data(chat_data: ChatData) -> void:
	profile_image.texture = chat_data.avatar
	label_name.text = chat_data.character_name
	if chat_data.messages.size() > 0:
		label_preview.text = chat_data.messages.back()
	unread_badge.visible = false
