class_name ChatMessage
extends HBoxContainer

var sender_type: Enums.SenderType:
	set(value):
		sender_type = value
		if is_node_ready():
			_apply_style()
var is_self: bool:
	get: return sender_type == Enums.SenderType.SELF

@export var self_bubble_color: Color
@export var frame_left: Control
@export var frame_right: Control
@export var avatar_left: TextureRect
@export var avatar_right: TextureRect
@export var bubble: PanelContainer
@export var message_text: RichTextLabel
@export var bubble_margin: Control

func setup(type: Enums.SenderType, text: String, avatar: Texture2D = null) -> void:
	sender_type = type
	message_text.text = text
	if avatar:
		avatar_left.texture = avatar
		avatar_right.texture = avatar
	_apply_style()
	_apply_layout.call_deferred()

func _apply_style() -> void:
	
	avatar_left.visible = not is_self
	avatar_right.visible = is_self
	message_text.self_modulate = Color.WHITE if is_self else Color.BLACK
	bubble.self_modulate = self_bubble_color if is_self else Color.WHITE
	alignment = BoxContainer.ALIGNMENT_END if is_self else BoxContainer.ALIGNMENT_BEGIN

func _apply_layout() -> void:
	# 先不换行，让文字自然撑开
	size_flags_horizontal = Control.SIZE_SHRINK_END if is_self else Control.SIZE_SHRINK_BEGIN
	message_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	message_text.size = Vector2()

	# deferred 再检查是否需要换行
	_check_wrap.call_deferred()

func _check_wrap() -> void:
	var pool_width = get_parent().size.x if get_parent() else 0
	if pool_width > 0 and size.x >= pool_width:
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		message_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
