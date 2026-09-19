class_name LogPage
extends CanvasLayer

const MAX_LOG_ENTRIES := 100

@export var log_line: LogLine
@export var divider: TextureRect
@export var vbox_log_lines: VBoxContainer
@export var scroll_container: ScrollContainer

var log_data_pool: Array[LogData] = []
var _suppressed: bool = false

# Drag scroll
var _dragging: bool = false
var _drag_start_y: float = 0
var _scroll_start: float = 0

func _ready() -> void:
	visibility_changed.connect(func(): set_process_input(visible))
	visibility_changed.connect(func():
		if visible:
			_pin_scroll_to_latest()
	)
	# 内容高度是延迟布局算出来的，而且可能好几帧后还在长（首次显示要重算尺寸、
	# 换行重排、字体后到）。只贴一次会停在半途，所以跟着滚动条的 max_value 一路贴到底。
	var v_scroll := scroll_container.get_v_scroll_bar()
	if v_scroll:
		v_scroll.changed.connect(_on_v_scroll_changed)
	DialogueManager.got_dialogue.connect(
		func (line: DialogueLine):
			if _suppressed: return
			if Game.book_page.visible: return
			if "手机" in line.tags: return
			var voice = ""
			if line.has_tag("语音"):
				voice = line.get_tag_value("语音")
			var display_name := line.get_tag_value("昵称") if line.has_tag("昵称") else line.character
			add_line(line.character, line.text, voice, Game.stage_page.chapter_name, display_name)
	)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_drag_start_y = event.global_position.y
				_scroll_start = scroll_container.scroll_vertical
			else:
				_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		var delta = _drag_start_y - event.global_position.y
		scroll_container.scroll_vertical = _scroll_start + delta

func add_line(character_name: String, text: String, voice_filename: String = "",
		chapter_name: String = "", display_name: String = "") -> void:
	var data = LogData.new()
	data.character_name = character_name
	data.display_name = display_name
	data.text = text
	data.voice_filename = voice_filename
	data.chapter_name = chapter_name
	log_data_pool.append(data)
	if log_data_pool.size() > MAX_LOG_ENTRIES:
		log_data_pool.pop_front()
	_insert_ui(data)

func _insert_ui(data: LogData) -> void:
	var line: LogLine = log_line.duplicate()
	vbox_log_lines.add_child(line)
	line.setup(data)
	vbox_log_lines.add_child(divider.duplicate())
	while vbox_log_lines.get_child_count() > MAX_LOG_ENTRIES * 2:
		var old_child = vbox_log_lines.get_child(0)
		vbox_log_lines.remove_child(old_child)
		old_child.queue_free()
	# 这里不用手动贴底：内容变高会让滚动条 max_value 变化，_on_v_scroll_changed 会接管。
	# 隐藏时插入也不怕——显示出来时 visibility_changed 贴一次，之后照旧跟着走。

## 贴到最新一句（最底）。只在位置不对时才写，免得自己这次写入触发的 changed 又绕回来
func _pin_scroll_to_latest() -> void:
	var v_scroll := scroll_container.get_v_scroll_bar()
	if not v_scroll:
		return
	var target := int(v_scroll.max_value)
	if scroll_container.scroll_vertical != target:
		scroll_container.scroll_vertical = target

## 滚动条变了（内容长高/变矮）就重新贴底；页面隐藏时不动
func _on_v_scroll_changed() -> void:
	if visible:
		_pin_scroll_to_latest()

func clear_all() -> void:
	log_data_pool.clear()
	Tools.clear_children(vbox_log_lines)

func restore(datas: Array[LogData]) -> void:
	clear_all()
	for data in datas:
		log_data_pool.append(data)
		_insert_ui(data)
