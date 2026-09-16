@tool
class_name ChapterTransition
extends CanvasLayer
## 章节过场：bg_change 背景 + 居中 chapter_info + 「章节 / 标题」两行文字
## 由 Stage.ShowChapterInfo() 调用 play()，播完 emit finished；点击可跳过
## 文本来自飞书演出表的「章节」列（`章节名|标题`），由 export_dialogue.py 写进 dialogue

signal finished

const SKIP_FADE_DURATION := 0.15

@export_group("时长")
@export_range(0.0, 3.0, 0.1) var fade_in_duration: float = 0.8
@export_range(0.0, 6.0, 0.1) var hold_duration: float = 2.4
@export_range(0.0, 3.0, 0.1) var fade_out_duration: float = 0.8
@export var skippable: bool = true

@export_group("编辑器预览")
## 只在编辑器里生效：拖这两个值能立刻看到卡片文字，方便调摆放，不用运行游戏
@export var preview_chapter: String = "章节1":
	set(value):
		preview_chapter = value
		_apply_preview()
@export var preview_title: String = "初雪":
	set(value):
		preview_title = value
		_apply_preview()

@export_group("节点")
@export var root: Control
@export var label_chapter: Label
@export var label_title: Label

var _finished := false

func _ready() -> void:
	if Engine.is_editor_hint():
		_apply_preview()
		return
	# 初始全透明并隐藏，等 Stage 调用 play()；有存档的玩家进游戏时不该闪一下
	root.modulate.a = 0.0
	hide()
	root.gui_input.connect(_on_root_gui_input)

func _apply_preview() -> void:
	# 预制体加载时导出属性可能还没赋值完，这里要能容忍空引用
	if not label_chapter or not label_title:
		return
	label_chapter.text = preview_chapter
	label_title.text = preview_title
	label_title.visible = not preview_title.is_empty()

func play(chapter_text: String, title_text: String) -> void:
	_finished = false
	label_chapter.text = chapter_text
	label_title.text = title_text
	# 飞书没填标题时（`章节` 列没有 | 分隔符）只显示章节名
	label_title.visible = not title_text.is_empty()

	root.modulate.a = 0.0
	show()

	var fade_in := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	fade_in.tween_property(root, "modulate:a", 1.0, fade_in_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await fade_in.finished
	if _finished:
		return

	await get_tree().create_timer(hold_duration).timeout
	if _finished:
		return

	var fade_out := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	fade_out.tween_property(root, "modulate:a", 0.0, fade_out_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await fade_out.finished
	if _finished:
		return
	_finish()

func _on_root_gui_input(event: InputEvent) -> void:
	if not skippable or _finished:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_skip()

func _skip() -> void:
	if _finished:
		return
	# 直接跳过：加速淡出，立刻进第一句对话
	var quick := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	quick.tween_property(root, "modulate:a", 0.0, SKIP_FADE_DURATION)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await quick.finished
	_finish()

func _finish() -> void:
	if _finished:
		return
	hide()
	_finished = true
	finished.emit()
