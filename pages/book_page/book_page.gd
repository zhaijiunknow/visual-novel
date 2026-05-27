class_name BookPage
extends CanvasLayer

const NotebookData = preload("res://data/_models/notebook_data.gd")
const MAX_ENTRIES_PER_PAGE := 8

@export var dialogue_label: DialogueLabel
@export var vbox_page: VBoxContainer
@export var button_previous: TextureButton
@export var button_next: TextureButton
@export var paragraph_container: ParagraphContainer
@export var buttons: Control
@export var reply_color: Color
@export var audio_player: AudioStreamPlayer

var notebook_data = NotebookData.new()
var page_index: int = 0
var _waiting_for_click := false
var _render_revision := 0

func _ready() -> void:
	print("[BookPage] _ready visible=", visible)
	button_previous.pressed.connect(
		func ():
			print("[BookPage] previous pressed current=", page_index)
			if page_index > 0:
				await show_page(page_index - 1)
	)
	button_next.pressed.connect(
		func ():
			print("[BookPage] next pressed current=", page_index, " total_pages=", notebook_data.pages.size())
			if page_index < notebook_data.pages.size() - 1:
				await show_page(page_index + 1)
	)
	visibility_changed.connect(
		func ():
			print("[BookPage] visibility_changed visible=", visible, " page_index=", page_index, " pages=", notebook_data.pages.size())
			if visible:
				call_deferred("show_last_page")
	)
	_ensure_initialized()
	_update_navigation()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not _waiting_for_click:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_waiting_for_click = false

func _make_page(page_number: int) -> Dictionary:
	return {
		"page_index": page_number,
		"entries": []
	}

func _ensure_initialized() -> void:
	if notebook_data == null:
		print("[BookPage] notebook_data was null, creating new NotebookData")
		notebook_data = NotebookData.new()
	if notebook_data.pages == null:
		print("[BookPage] notebook_data.pages was null, initializing empty array")
		notebook_data.pages = []
	if notebook_data.pages.is_empty():
		print("[BookPage] notebook_data.pages empty, creating first blank page")
		notebook_data.pages.append(_make_page(0))
		notebook_data.current_page_index = 0
	if notebook_data.entry_ids_written == null:
		print("[BookPage] notebook_data.entry_ids_written was null, initializing empty array")
		notebook_data.entry_ids_written = []

func _clear_page() -> void:
	for child in vbox_page.get_children():
		vbox_page.remove_child(child)
		child.queue_free()

func _update_navigation() -> void:
	button_previous.visible = page_index > 0
	button_next.visible = page_index < notebook_data.pages.size() - 1
	buttons.visible = true

func show_page(value: int) -> void:
	_ensure_initialized()
	page_index = clampi(value, 0, max(notebook_data.pages.size() - 1, 0))
	_waiting_for_click = false
	_render_revision += 1
	print("[BookPage] show_page target=", value, " clamped=", page_index, " revision=", _render_revision, " total_pages=", notebook_data.pages.size())
	await _render_page(page_index, false, _render_revision)

func _render_page(target_page_index: int, animate: bool, revision: int) -> void:
	_ensure_initialized()
	_clear_page()
	_waiting_for_click = false
	_update_navigation()
	print("[BookPage] _render_page target=", target_page_index, " animate=", animate, " revision=", revision, " total_pages=", notebook_data.pages.size())
	if notebook_data.pages.is_empty():
		print("[BookPage] _render_page aborted: no pages")
		return
	var page: Dictionary = notebook_data.pages[target_page_index]
	var entries: Array = page.get("entries", [])
	print("[BookPage] rendering page index=", page.get("page_index", target_page_index), " entries=", entries.size())
	if entries.is_empty():
		print("[BookPage] page is empty; staying open with blank notebook")
		return
	for entry in entries:
		if revision != _render_revision:
			print("[BookPage] render revision mismatch, aborting")
			return
		await _append_entry(entry, animate and entry.get("side", "") == "left")
		if revision != _render_revision:
			print("[BookPage] render revision mismatch after append, aborting")
			return
		if animate and entry.get("side", "") == "right":
			print("[BookPage] waiting for click to continue right-side entry")
			_waiting_for_click = true
			while _waiting_for_click and revision == _render_revision:
				await get_tree().process_frame
			if revision != _render_revision:
				print("[BookPage] render revision mismatch after click wait, aborting")
				return

func _append_entry(entry: Dictionary, animate: bool) -> void:
	var label = dialogue_label.duplicate()
	var container = paragraph_container.duplicate()
	vbox_page.add_child(container)
	var is_left = entry.get("side", "") == "left"
	if is_left:
		container.box_left.add_child(label)
	else:
		label.remove_theme_color_override("default_color")
		label.add_theme_color_override("default_color", reply_color)
		container.box_right.add_child(label)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = entry.get("text", "")
	label.visible_ratio = 0 if animate else 1
	if animate:
		audio_player.play()
		await create_tween().tween_property(label, "visible_ratio", 1, audio_player.stream.get_length()).finished
		await get_tree().create_timer(0.8).timeout

func _play_new_entry(entry: Dictionary) -> void:
	if entry.get("side", "") == "left":
		await _append_entry(entry, true)
		return
	print("[BookPage] waiting for click to reveal right-side continuation")
	_waiting_for_click = true
	while _waiting_for_click:
		await get_tree().process_frame
	await _append_entry(entry, true)

func append_entry(entry_id: String, speaker: String, text: String, side: String = "", tags: Array = [], animate: bool = true) -> void:
	_ensure_initialized()
	if entry_id != "" and entry_id in notebook_data.entry_ids_written:
		return
	var target_side = side if side != "" else ("left" if speaker == "L" else "right")
	var current_page: Dictionary = notebook_data.pages[notebook_data.current_page_index]
	var entries: Array = current_page.get("entries", [])
	var created_new_page := false
	if entries.size() >= MAX_ENTRIES_PER_PAGE:
		var next_page := _make_page(notebook_data.pages.size())
		notebook_data.pages.append(next_page)
		notebook_data.current_page_index = next_page.get("page_index", notebook_data.current_page_index + 1)
		current_page = next_page
		entries = current_page.get("entries", [])
		created_new_page = true
	var entry := {
		"entry_id": entry_id,
		"speaker": speaker,
		"text": text,
		"side": target_side,
		"tags": tags.duplicate(),
		"page_index": current_page.get("page_index", 0),
		"chapter_name": Game.stage_page.chapter_name if Game.stage_page.dialogue else "",
		"source_dialogue_id": str(Game.stage_page.dialogue_line.id) if Game.stage_page.dialogue_line else "",
	}
	entries.append(entry)
	current_page["entries"] = entries
	if entry_id != "":
		notebook_data.entry_ids_written.append(entry_id)
	notebook_data.current_page_index = current_page.get("page_index", notebook_data.current_page_index)
	if visible:
		if created_new_page or page_index != notebook_data.current_page_index:
			await show_page(notebook_data.current_page_index)
		await _play_new_entry(entry)
		_update_navigation()
		return
	_update_navigation()

func show_last_page() -> void:
	_ensure_initialized()
	await show_page(notebook_data.current_page_index)

func duplicate_notebook_data():
	_ensure_initialized()
	return notebook_data.duplicate(true)

func reset_notebook() -> void:
	notebook_data = NotebookData.new()
	_ensure_initialized()
	page_index = notebook_data.current_page_index
	_waiting_for_click = false
	_render_revision += 1
	if visible:
		await show_last_page()
	else:
		_clear_page()
		_update_navigation()

func restore_notebook_data(data) -> void:
	notebook_data = data.duplicate(true) if data else NotebookData.new()
	_ensure_initialized()
	if visible:
		await show_last_page()
