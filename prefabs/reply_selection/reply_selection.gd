@tool
class_name ReplySelection
extends PanelContainer

@export var reply_text: RichTextLabel

@export var hover_shade: Control
@export var select_shade: Control
@export var hovered: bool:
	set(value):
		hovered = value
		hover_shade.visible = hovered
@export var selected: bool:
	set(value):
		selected = value
		select_shade.visible = selected

var next_id: String

func _ready() -> void:
	mouse_entered.connect(
		func (): hovered = true
	)
	mouse_exited.connect(
		func (): hovered = false
	)
	gui_input.connect(
		func (event: InputEvent):
			if event is InputEventMouseButton:
				if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					Game.phone_page.clear_reply_selections()
					var message: ChatMessage = Prefabs.chat_message.instantiate()
					Game.phone_page.chat_message_pool.add_child(message)
					message.sender_type = Enums.SenderType.SELF
					message.message_text.text = reply_text.text
					Game.phone_page.add_message("周腾", reply_text.text)
					Game.stage_page.dialogue_line = \
						await Game.stage_page.dialogue \
							.get_next_dialogue_line(next_id, [Game.stage_page, Stage])
	)
