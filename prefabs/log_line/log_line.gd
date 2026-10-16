class_name LogLine
extends MarginContainer

## 点了这一行（不是点重听/收藏按钮）→ 请求剧情跳回这一句
signal jump_requested(data: LogData)

@export var vbox_character_info: VBoxContainer
@export var label_character_name: Label
@export var rich_label_dialogue_text: RichTextLabel
@export var button_replay: TextureRect
@export var button_favourite: TextureRect
@export var drag_filter: DragFilter
## 悬停高亮的那块卡片：铺满两条横线之间的一整格（根节点不再带内边距，内边距在 Content 上）
@export var highlight: ColorRect
## 上下出血：卡片比行本身高出这么多像素（盖住横线与行之间那 4px 缝，让卡片显得更宽）。
## 容器的排版会把子节点压回行内，所以是排完版再手动撑出去（Controls 默认不裁剪子节点）
@export var highlight_bleed_y: float = 8.0
## 左右出血：羽化会把两端各吃掉 feather_x 那么宽，这里往外撑出来补回去，
## 让"实心部分"仍然够到横线的两端（实心 ≈ 行宽 + 2×出血 − 2×羽化）。
## 撑出去的部分落在回想页滚动区左右预留的余量里（ScrollContainer 是 clip_contents=true，
## 超出滚动区会被硬裁，所以 log_page 的滚动区比内容宽、两侧留了空白给这段羽化）
@export var highlight_bleed_x: float = 56.0

## 不可跳转的条目（加 line_id 之前存的老档）压暗一点，顺便当作"点不动"的提示
const MODULATE_NOT_JUMPABLE := 0.55
const MODULATE_HOVER := Color(1.18, 1.18, 1.18)
## 人名在淡白底板上会糊，悬停时提亮一档
const NAME_HOVER_BOOST := Color(1.45, 1.45, 1.45)
## 卡片淡入淡出的时长
const HIGHLIGHT_FADE := 0.12

const COLOR_NORMAL := Color(0.382, 0.382, 0.382)
const COLOR_HOVER_BLEND := Color(0.171, 0.171, 0.171)
const COLOR_PRESS := Color(0.813, 0.813, 0.813)
const COLOR_PLAYING := Color.WHITE
const COLOR_FAVOURITE_ON := Color.WHITE
const COLOR_FAVOURITE_OFF := COLOR_NORMAL

var log_data: LogData
var _playing := false
var _voice_cb: Callable = Callable()
var _hover_tween: Tween

var character_name: String:
	set(value):
		character_name = value
		label_character_name.text = character_name
		vbox_character_info.modulate.a = 1 if character_name else 0

var dialogue_text: String:
	set(value):
		dialogue_text = value
		rich_label_dialogue_text.text = dialogue_text

var has_voice: bool:
	get: return log_data != null and log_data.voice_filename != ""

var is_favourite: bool:
	get:
		if not has_voice: return false
		for collection in Main.collection_data.voice_collections:
			if collection.voice_filename == log_data.voice_filename:
				return true
		return false

## 这一条能不能跳（老存档里没有 line_id 的条目点不动）
var is_jumpable: bool:
	get: return log_data != null and not log_data.line_id.is_empty()

func setup(data: LogData) -> void:
	log_data = data
	character_name = data.display_name if data.display_name else data.character_name
	dialogue_text = data.text
	var show = has_voice
	button_replay.visible = show
	button_favourite.visible = show
	_update_favourite_color()
	modulate.a = 1.0 if is_jumpable else MODULATE_NOT_JUMPABLE

func _ready() -> void:
	button_replay.mouse_filter = Control.MOUSE_FILTER_STOP
	button_favourite.mouse_filter = Control.MOUSE_FILTER_STOP
	button_replay.modulate = COLOR_NORMAL
	button_favourite.modulate = COLOR_FAVOURITE_OFF
	# 卡片材质每行一份：shader 的 rect_size 是拿节点尺寸逐行写进去的，
	# 场景里的 sub_resource 在所有实例之间共享，不 duplicate 就会互相覆盖
	if highlight != null:
		if highlight.material is ShaderMaterial:
			highlight.material = (highlight.material as ShaderMaterial).duplicate()
		highlight.resized.connect(_sync_highlight_size)
		# 容器每次排完版都要重贴出血（它会把子节点压回行内），自己的尺寸变了也要跟着走
		sort_children.connect(_apply_highlight_bleed)
		resized.connect(_apply_highlight_bleed)
		_apply_highlight_bleed()
	Main.voice_collection_changed.connect(_on_voice_collection_changed)
	# 用 DragFilter 而不是直接听 gui_input：回想页本身支持按住拖动滚动，
	# 直接听点击的话"拖动列表"会被当成"点了某一句"（它靠 8px 门限区分两者）
	if drag_filter != null:
		drag_filter.execute.connect(
			func():
				if is_jumpable:
					jump_requested.emit(log_data)
		)
	mouse_entered.connect(func(): _set_hovered(true))
	mouse_exited.connect(func(): _set_hovered(false))
	# 两个图标是 STOP，鼠标压上去时 enter 不会传给整行（只有 PASS 祖先才往上传播），
	# 不补这两句的话「光标移到图标上卡片就灭」，看着就像只有图标能点
	for icon: TextureRect in [button_replay, button_favourite]:
		icon.mouse_entered.connect(func(): _set_hovered(true))
		icon.mouse_exited.connect(func(): _set_hovered(false))
	button_replay.mouse_entered.connect(func(): if not _playing: button_replay.modulate = COLOR_NORMAL + COLOR_HOVER_BLEND)
	button_replay.mouse_exited.connect(func(): if not _playing: button_replay.modulate = COLOR_NORMAL)
	button_replay.gui_input.connect(
		func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					button_replay.modulate = COLOR_PRESS
				else:
					if has_voice:
						AudioManager.play_voice(log_data.voice_filename)
						_playing = true
						button_replay.modulate = COLOR_PLAYING
						if not _voice_cb.is_null() and AudioManager.voice_finished.is_connected(_voice_cb):
							AudioManager.voice_finished.disconnect(_voice_cb)
						_voice_cb = func():
							_playing = false
							button_replay.modulate = COLOR_NORMAL
						AudioManager.voice_finished.connect(_voice_cb)
					else:
						button_replay.modulate = COLOR_NORMAL
	)

	button_favourite.mouse_entered.connect(func(): _update_favourite_color(true))
	button_favourite.mouse_exited.connect(func(): _update_favourite_color())
	button_favourite.gui_input.connect(
		func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					button_favourite.modulate = COLOR_PRESS
				else:
					if has_voice:
						_toggle_favourite()
					_update_favourite_color(true)
	)

## 整卡悬停态：卡片（两条横线之间那一整格）淡入 + 文字提亮。
## 以前只有一句 `modulate = 1.18`——亮 18% 在深色背景上几乎看不出来，
## 玩家因此以为只有那栏紫色人名可以点
func _set_hovered(on: bool) -> void:
	# 老档里没有 line_id 的条目跳不动，不参与悬停（保持压暗的样子）
	if not is_jumpable:
		return
	modulate = MODULATE_HOVER if on else Color.WHITE
	if label_character_name != null:
		label_character_name.self_modulate = NAME_HOVER_BOOST if on else Color.WHITE
	if highlight == null:
		return
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	if on:
		# 静止时卡片整块隐藏：一百行都挂一层带扫光的 shader 太亏
		highlight.visible = true
	_hover_tween = create_tween()
	_hover_tween.tween_property(highlight, "modulate:a", 1.0 if on else 0.0, HIGHLIGHT_FADE)
	if not on:
		_hover_tween.tween_callback(func(): highlight.visible = false)


## UV 是 0~1，边缘亮线的宽度要按像素算，只能把节点尺寸喂给 shader
func _sync_highlight_size() -> void:
	var mat := highlight.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("rect_size", highlight.size)


## 把卡片四边撑出 highlight_bleed_* 像素。必须在容器排完版之后做：
## MarginContainer 会把子节点的 rect 压回行内，撑出去的部分才是"卡片比行更大"
func _apply_highlight_bleed() -> void:
	if highlight == null:
		return
	highlight.position = Vector2(-highlight_bleed_x, -highlight_bleed_y)
	highlight.size = Vector2(
		size.x + highlight_bleed_x * 2.0,
		size.y + highlight_bleed_y * 2.0
	)


func _toggle_favourite() -> void:
	if is_favourite:
		for collection in Main.collection_data.voice_collections:
			if collection.voice_filename == log_data.voice_filename:
				Main.collection_data.voice_collections.erase(collection)
				break
		Main.save_collection_data()
		Main.voice_collection_changed.emit(log_data.voice_filename)
	else:
		# 章节号/章节名取演出表的值，collect_voice 内部已存档并广播
		Main.collect_voice(
			log_data.character_name, log_data.text, log_data.voice_filename, log_data.chapter_name
		)


func _on_voice_collection_changed(vf: String) -> void:
	if log_data and vf == log_data.voice_filename:
		_update_favourite_color()

func _update_favourite_color(hover: bool = false) -> void:
	if not has_voice: return
	var base = COLOR_FAVOURITE_ON if is_favourite else COLOR_FAVOURITE_OFF
	button_favourite.modulate = (base + COLOR_HOVER_BLEND) if hover else base
