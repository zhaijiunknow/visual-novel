class_name Chat
extends PanelContainer

@export var profile_image: TextureRect
@export var label_name: Label
@export var label_preview: Label
@export var label_unread_count: Label
@export var unread_badge: PanelContainer

## 自己那份数据：列表页开着时来了新消息，靠它重刷预览（见 refresh_preview）
var chat_data: ChatData

func set_chat_data(data: ChatData) -> void:
	chat_data = data
	profile_image.texture = data.avatar
	# 列表卡片不换行，但昵称要完整：把换行当空格，
	# 让「高三（10）班-余洛琛-」和后面的备注显示在同一行，不压住消息预览。
	# 聊天窗口标题仍用完整昵称（Label_Name 自带 autowrap）。
	var nickname: String = Game.phone_page.get_phone_nickname(data.character_name)
	label_name.text = nickname.replace("\r", "").replace("\n", " ").strip_edges()
	unread_badge.visible = false
	refresh_preview()


## 只刷预览那一行。列表页开着的时候新消息会不断到达，
## 卡片得跟着显示最新一条 —— 卡片是一次性建好的，不会自己重读数据
func refresh_preview() -> void:
	label_preview.text = chat_data.messages.back() if chat_data and chat_data.messages.size() > 0 else ""
