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
	# 默认展开+换行（安全值）
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_check_shrink.call_deferred()

func _check_shrink() -> void:
	# 布局未就绪时保持展开（安全值）
	if message_text.size.x <= 0:
		return
	# 用字体直接算文本宽度，不依赖 size.x
	var font := message_text.get_theme_font("normal_font") as Font
	var font_size := message_text.get_theme_font_size("normal_font_size")
	var text_width := font.get_string_size(message_text.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	# 文本能一行放下 → 切换为收缩模式
	if text_width < message_text.size.x:
		size_flags_horizontal = Control.SIZE_SHRINK_END if is_self else Control.SIZE_SHRINK_BEGIN
		message_text.autowrap_mode = TextServer.AUTOWRAP_OFF
