@tool
class_name ChatMessage
extends HBoxContainer

@export_tool_button("Reset") var reset_button = reset

@export var sender_type: Enums.SenderType:
	set(value):
		sender_type = value
		var is_self = sender_type == Enums.SenderType.SELF
		size_flags_horizontal = SIZE_SHRINK_END if is_self else SIZE_SHRINK_BEGIN
		frame_left.modulate.a = 1 if not is_self else 0
		frame_right.modulate.a = 1 if is_self else 0
		message_text.self_modulate = Color.WHITE if is_self else Color.BLACK
		bubble.self_modulate = self_bubble_color if is_self else Color.WHITE
		alignment = BoxContainer.ALIGNMENT_END if is_self else \
			BoxContainer.ALIGNMENT_BEGIN

@export var self_bubble_color: Color
@export var frame_left: Control
@export var frame_right: Control
@export var avatar_left: TextureRect
@export var avatar_right: TextureRect
@export var bubble: PanelContainer
@export var message_text: RichTextLabel

var parent: Control:
	get: return get_parent()

func _ready() -> void:
	reset()

func setup(type: Enums.SenderType, text: String, avatar: Texture2D = null) -> void:
	sender_type = type
	message_text.text = text
	if avatar:
		avatar_left.texture = avatar
		avatar_right.texture = avatar
	# 等布局稳定后检查是否需要换行
	await get_tree().process_frame
	_check_overflow()

func _check_overflow() -> void:
	if not is_inside_tree() or parent == null: return
	if size.x >= parent.size.x:
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		message_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func reset() -> void:
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	message_text.autowrap_mode = TextServer.AUTOWRAP_OFF
