@tool
class_name ChatMessage
extends HBoxContainer

@export_tool_button("Reset") var reset_button = reset

@export var sender_type: Enums.SenderType:
	set(value):
		sender_type = value
		var is_self = sender_type == Enums.SenderType.SELF
		size_flags_horizontal = SIZE_SHRINK_END if is_self else SIZE_SHRINK_BEGIN
		avatar_left.modulate.a = 1 if not is_self else 0
		avatar_right.modulate.a = 1 if is_self else 0
		message_text.self_modulate = Color.WHITE if is_self else Color.BLACK
		bubble.self_modulate = self_bubble_color if is_self else Color.WHITE
		alignment = BoxContainer.ALIGNMENT_END if is_self else \
			BoxContainer.ALIGNMENT_BEGIN

@export var self_bubble_color: Color
@export var avatar_left: TextureRect
@export var avatar_right: TextureRect
@export var bubble: PanelContainer
@export var message_text: RichTextLabel

var parent: Control:
	get: return get_parent()

func _ready() -> void:
	reset()
	resized.connect(
		func ():
			if size.x >= parent.size.x:
				size_flags_horizontal = Control.SIZE_EXPAND_FILL
				bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				message_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	)

func reset() -> void:
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	message_text.autowrap_mode = TextServer.AUTOWRAP_OFF
