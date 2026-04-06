class_name LogPage
extends CanvasLayer

const MAX_LOG_ENTRIES := 100

@export var log_line: LogLine
@export var divider: TextureRect
@export var vbox_log_lines: VBoxContainer

var log_data_pool: Array[LogData] = []

func _ready() -> void:
	DialogueManager.got_dialogue.connect(
		func (line: DialogueLine):
			if Game.book_page.visible: return
			add_line(line.character, line.text)
	)

func add_line(character_name: String, text: String) -> void:
	var data = LogData.new()
	data.character_name = character_name
	data.text = text
	log_data_pool.append(data)
	if log_data_pool.size() > MAX_LOG_ENTRIES:
		log_data_pool.pop_front()
	_insert_ui(character_name, text)

func _insert_ui(character_name: String, text: String) -> void:
	var line: LogLine = log_line.duplicate()
	line.character_name = character_name
	line.dialogue_text = text
	vbox_log_lines.add_child(line)
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
		_insert_ui(data.character_name, data.text)
