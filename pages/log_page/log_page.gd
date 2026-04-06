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
	DialogueManager.got_dialogue.connect(
		func (line: DialogueLine):
			if _suppressed: return
			if Game.book_page.visible: return
			var voice = ""
			if line.has_tag("语音"):
				voice = line.get_tag_value("语音")
			add_line(line.character, line.text, voice, Game.stage_page.chapter_name)
	)

func _input(event: InputEvent) -> void:
	if not visible: return
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

func add_line(character_name: String, text: String, voice_filename: String = "", chapter_name: String = "") -> void:
	var data = LogData.new()
	data.character_name = character_name
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

func clear_all() -> void:
	log_data_pool.clear()
	Tools.clear_children(vbox_log_lines)

func restore(datas: Array[LogData]) -> void:
	clear_all()
	for data in datas:
		log_data_pool.append(data)
		_insert_ui(data)
