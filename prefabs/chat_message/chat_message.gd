@tool
class_name ChatMessage
extends HBoxContainer

@export var sender_type: Enums.SenderType:
	set(value):
		sender_type = value
		update.call_deferred()

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

#func _ready() -> void:
	##if Engine.is_editor_hint(): return
	#resized.connect(update)

func setup(type: Enums.SenderType, text: String, avatar: Texture2D = null) -> void:
	sender_type = type
	message_text.text = text
	if avatar:
		avatar_left.texture = avatar
		avatar_right.texture = avatar
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func update() -> void:
	var is_self = sender_type == Enums.SenderType.SELF
	#size_flags_horizontal = SIZE_EXPAND_FILL
	frame_left.modulate.a = 1 if not is_self else 0
	frame_right.modulate.a = 1 if is_self else 0
	message_text.self_modulate = Color.WHITE if is_self else Color.BLACK
	bubble.self_modulate = self_bubble_color if is_self else Color.WHITE

	#if is_self:
		#message_text.alignment = BoxContainer.ALIGNMENT_END
	#else:
		#message_text.alignment = BoxContainer.ALIGNMENT_BEGIN

	if  size.x >= parent.size.x:
		bubble_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		message_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		bubble_margin.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		message_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	message_text.size = Vector2()
