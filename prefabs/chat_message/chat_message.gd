class_name ChatMessage
extends HBoxContainer

@export var sender_type: Enums.SenderType:
	set(value):
		sender_type = value
		update()

@export var self_bubble_color: Color
@export var frame_left: Control
@export var frame_right: Control
@export var avatar_left: TextureRect
@export var avatar_right: TextureRect
@export var bubble: PanelContainer
@export var message_text: RichTextLabel
@export var bubble_margin: Control

var parent: Control:
	get: return get_parent()

func _ready() -> void:
	resized.connect(update)

func setup(type: Enums.SenderType, text: String, avatar: Texture2D = null) -> void:
	sender_type = type
	message_text.text = text
	if avatar:
		avatar_left.texture = avatar
		avatar_right.texture = avatar
	update.call_deferred()

func update() -> void:
	var is_self = sender_type == Enums.SenderType.SELF

	# 头像：自己显示右边，对方显示左边
	avatar_left.visible = not is_self
	avatar_right.visible = is_self

	# 气泡颜色
	message_text.self_modulate = Color.WHITE if is_self else Color.BLACK
	bubble.self_modulate = self_bubble_color if is_self else Color.WHITE

	# 先用不换行测量文字自然宽度
	if size.x >= parent.size.x:
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		message_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		message_text.autowrap_mode = TextServer.AUTOWRAP_OFF

	var pool_width = get_parent().size.x if get_parent() else size.x
	if size.x >= pool_width:
		# 文字太长，需要换行填满
		bubble_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		message_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# 对齐：自己靠右，对方靠左
	if is_self:
		alignment = BoxContainer.ALIGNMENT_END
	else:
		alignment = BoxContainer.ALIGNMENT_BEGIN
