class_name BookPage
extends CanvasLayer

signal story_interaction_closed
signal reply_selected(next_id: String)

const NotebookData = preload("res://data/_models/notebook_data.gd")
const NotebookPageData = preload("res://data/_models/notebook_page_data.gd")
const NotebookEntryData = preload("res://data/_models/notebook_entry_data.gd")
const MAX_ENTRIES_PER_PAGE := 8

@export var dialogue_label: DialogueLabel
@export var vbox_page: VBoxContainer
@export var button_previous: TextureButton
@export var button_next: TextureButton
@export var paragraph_container: ParagraphContainer
@export var buttons: Control
@export var back_button: Control
@export var reply_color: Color
@export var audio_player: AudioStreamPlayer

var notebook_data = NotebookData.new()
var page_index: int = 0
var _waiting_for_click := false
var _render_revision := 0
var _is_playing_entry := false
var _awaiting_story_close := false
var _showing_reply_options := false

func _ready() -> void:
	button_previous.pressed.connect(
		func ():
			if page_index > 0:
				await show_page(page_index - 1)
	)
	button_next.pressed.connect(
		func ():
			if page_index < notebook_data.pages.size() - 1:
				await show_page(page_index + 1)
	)
	visibility_changed.connect(
		func ():
			if visible:
				call_deferred("show_last_page")
				call_deferred("_setup_choice_button_hover")
			elif _awaiting_story_close:
				_awaiting_story_close = false
				story_interaction_closed.emit()
	)
	_ensure_initialized()
	_update_navigation()
	clear_reply_options()
	call_deferred("_setup_choice_button_hover")

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not _waiting_for_click:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_waiting_for_click = false

func _make_page(page_number: int) -> NotebookPageData:
	var page := NotebookPageData.new()
	page.page_index = page_number
	page.entries = []
	return page

func _ensure_initialized() -> void:
	if notebook_data == null:
		notebook_data = NotebookData.new()
	if notebook_data.pages == null:
		notebook_data.pages = []
	if notebook_data.pages.is_empty():
		notebook_data.pages.append(_make_page(0))
		notebook_data.current_page_index = 0
	if notebook_data.entry_ids_written == null:
		notebook_data.entry_ids_written = []

func _clear_page() -> void:
	for child in vbox_page.get_children():
		vbox_page.remove_child(child)
		child.queue_free()

func _update_navigation() -> void:
	var allow_navigation := not _is_playing_entry and not _showing_reply_options
	button_previous.visible = allow_navigation and page_index > 0
	button_next.visible = allow_navigation and page_index < notebook_data.pages.size() - 1
	back_button.visible = allow_navigation

func _setup_choice_button_hover() -> void:
	_connect_choice_hover(
		get_node_or_null("Buttons/ChoiceButton/ChoiceOne/Choice1") as TextureButton,
		-0.034906585,
		-0.10471976
	)
	_connect_choice_hover(
		get_node_or_null("Buttons/ChoiceButton/ChoiceTwo/Choice2") as TextureButton,
		0.017453292,
		-0.05235988
	)
	_connect_choice_hover(
		get_node_or_null("Buttons/ChoiceButton/ChoiceThree/Choice3") as TextureButton,
		-0.0052359877,
		-0.06981317
	)

func _connect_choice_hover(choice_button: TextureButton, base_rotation: float, hover_rotation: float) -> void:
	if choice_button == null:
		return
	if choice_button.has_meta("book_hover_connected"):
		return
	choice_button.set_meta("book_hover_connected", true)
	choice_button.rotation = base_rotation
	choice_button.mouse_entered.connect(func(): _tween_choice_rotation(choice_button, hover_rotation))
	choice_button.mouse_exited.connect(func(): _tween_choice_rotation(choice_button, base_rotation))

func _tween_choice_rotation(choice_button: TextureButton, target_rotation: float) -> void:
	if choice_button == null:
		return
	var existing: Tween = choice_button.get_meta("book_hover_tween") if choice_button.has_meta("book_hover_tween") else null
	if existing:
		existing.kill()
	var tween := create_tween()
	choice_button.set_meta("book_hover_tween", tween)
	tween.tween_property(choice_button, "rotation", target_rotation, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _fit_choice_label(label: RichTextLabel, max_font_size: int = 38, min_font_size: int = 24) -> void:
	if label == null:
		return
	label.fit_content = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.bbcode_enabled = false
	label.scroll_active = false
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("normal_font_size", max_font_size)
	await get_tree().process_frame
	var size := max_font_size
	while size > min_font_size and label.get_content_height() > label.size.y:
		size -= 2
		label.add_theme_font_size_override("normal_font_size", size)
		await get_tree().process_frame

func show_reply_options(responses) -> void:
	clear_reply_options()
	var choice_button = get_node_or_null("Buttons/ChoiceButton") as Control
	if choice_button == null:
		return
	var choice_nodes = [
		{
			"root": get_node_or_null("Buttons/ChoiceButton/ChoiceOne") as Control,
			"button": get_node_or_null("Buttons/ChoiceButton/ChoiceOne/Choice1") as TextureButton,
			"label": get_node_or_null("Buttons/ChoiceButton/ChoiceOne/Choice1/Label") as RichTextLabel,
			"reveal_tilt": deg_to_rad(-1.2),
		},
		{
			"root": get_node_or_null("Buttons/ChoiceButton/ChoiceTwo") as Control,
			"button": get_node_or_null("Buttons/ChoiceButton/ChoiceTwo/Choice2") as TextureButton,
			"label": get_node_or_null("Buttons/ChoiceButton/ChoiceTwo/Choice2/Label") as RichTextLabel,
			"reveal_tilt": deg_to_rad(1.0),
		},
		{
			"root": get_node_or_null("Buttons/ChoiceButton/ChoiceThree") as Control,
			"button": get_node_or_null("Buttons/ChoiceButton/ChoiceThree/Choice3") as TextureButton,
			"label": get_node_or_null("Buttons/ChoiceButton/ChoiceThree/Choice3/Label") as RichTextLabel,
			"reveal_tilt": deg_to_rad(-0.8),
		},
	]
	for i in choice_nodes.size():
		var root: Control = choice_nodes[i].root
		var button: TextureButton = choice_nodes[i].button
		var label: RichTextLabel = choice_nodes[i].label
		var reveal_tilt: float = choice_nodes[i].reveal_tilt
		if root == null or button == null or label == null:
			continue
		if i >= responses.size():
			root.visible = false
			button.disabled = true
			continue
		var response = responses[i]
		root.visible = true
		root.modulate.a = 0.0
		var base_position := root.position
		root.set_meta("book_choice_base_position", base_position)
		var base_rotation := button.rotation
		button.set_meta("book_choice_base_rotation", base_rotation)
		root.position = base_position + Vector2(-28, 0)
		button.rotation = base_rotation + reveal_tilt
		button.disabled = false
		label.text = response.text
		await _fit_choice_label(label)
		if button.has_meta("book_reply_callable"):
			var old_callable: Callable = button.get_meta("book_reply_callable")
			if button.pressed.is_connected(old_callable):
				button.pressed.disconnect(old_callable)
		var callback := func(): _on_reply_clicked(response.next_id)
		button.set_meta("book_reply_callable", callback)
		button.pressed.connect(callback)
		var tween := create_tween()
		tween.tween_interval(i * 0.05)
		tween.parallel().tween_property(root, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(root, "position", base_position, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(button, "rotation", base_rotation, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	choice_button.visible = responses.size() > 0
	_showing_reply_options = responses.size() > 0
	_update_navigation()

func _on_reply_clicked(next_id: String) -> void:
	clear_reply_options()
	reply_selected.emit(next_id)

func clear_reply_options() -> void:
	var choice_button = get_node_or_null("Buttons/ChoiceButton") as Control
	if choice_button:
		choice_button.visible = false
	var paths = [
		"Buttons/ChoiceButton/ChoiceOne",
		"Buttons/ChoiceButton/ChoiceTwo",
		"Buttons/ChoiceButton/ChoiceThree",
	]
	for path in paths:
		var root = get_node_or_null(path) as Control
		if root == null:
			continue
		root.visible = false
		root.modulate.a = 1.0
		if root.has_meta("book_choice_base_position"):
			root.position = root.get_meta("book_choice_base_position")
		for child in root.get_children():
			if child is TextureButton:
				var button := child as TextureButton
				if button.has_meta("book_choice_base_rotation"):
					button.rotation = button.get_meta("book_choice_base_rotation")
				button.disabled = true
				if button.has_meta("book_reply_callable"):
					var old_callable: Callable = button.get_meta("book_reply_callable")
					if button.pressed.is_connected(old_callable):
						button.pressed.disconnect(old_callable)
					button.remove_meta("book_reply_callable")
	_showing_reply_options = false
	_update_navigation()

func show_page(value: int) -> void:
	_ensure_initialized()
	page_index = clampi(value, 0, max(notebook_data.pages.size() - 1, 0))
	_waiting_for_click = false
	_render_revision += 1
	await _render_page(page_index, false, _render_revision)

func _render_page(target_page_index: int, animate: bool, revision: int) -> void:
	_ensure_initialized()
	_clear_page()
	_waiting_for_click = false
	clear_reply_options()
	_update_navigation()
	if notebook_data.pages.is_empty():
		return
	var page: NotebookPageData = notebook_data.pages[target_page_index]
	var entries: Array[NotebookEntryData] = page.entries
	if entries.is_empty():
		return
	for entry in entries:
		if revision != _render_revision:
			return
		await _append_entry(entry, animate and entry.side == "left")
		if revision != _render_revision:
			return
		if animate and entry.side == "right":
			_waiting_for_click = true
			while _waiting_for_click and revision == _render_revision:
				await get_tree().process_frame
			if revision != _render_revision:
				return

func _append_entry(entry: NotebookEntryData, animate: bool) -> void:
	var label = dialogue_label.duplicate()
	var container = paragraph_container.duplicate()
	vbox_page.add_child(container)
	var is_left = entry.side == "left"
	if is_left:
		container.box_left.add_child(label)
	else:
		label.remove_theme_color_override("default_color")
		label.add_theme_color_override("default_color", reply_color)
		container.box_right.add_child(label)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = entry.text
	label.visible_ratio = 0 if animate else 1
	if animate:
		audio_player.play()
		await create_tween().tween_property(label, "visible_ratio", 1, audio_player.stream.get_length()).finished
		await get_tree().create_timer(0.8).timeout

func _play_new_entry(entry: NotebookEntryData) -> void:
	_is_playing_entry = true
	_update_navigation()
	if entry.side == "left":
		await _append_entry(entry, true)
		_is_playing_entry = false
		_update_navigation()
		return
	_waiting_for_click = true
	while _waiting_for_click:
		await get_tree().process_frame
	await _append_entry(entry, true)
	_is_playing_entry = false
	_update_navigation()

func append_entry(entry_id: String, speaker: String, text: String, side: String = "", tags: Array = [], animate: bool = true) -> void:
	_ensure_initialized()
	if entry_id != "" and entry_id in notebook_data.entry_ids_written:
		return
	var target_side = side if side != "" else ("left" if speaker == "L" else "right")
	var current_page: NotebookPageData = notebook_data.pages[notebook_data.current_page_index]
	var entries: Array[NotebookEntryData] = current_page.entries
	var created_new_page := false
	if entries.size() >= MAX_ENTRIES_PER_PAGE:
		var next_page := _make_page(notebook_data.pages.size())
		notebook_data.pages.append(next_page)
		notebook_data.current_page_index = next_page.page_index
		current_page = next_page
		entries = current_page.entries
		created_new_page = true
	var entry := NotebookEntryData.new()
	entry.entry_id = entry_id
	entry.speaker = speaker
	entry.text = text
	entry.side = target_side
	entry.tags = tags.duplicate()
	entry.page_index = current_page.page_index
	entry.chapter_name = Game.stage_page.chapter_name if Game.stage_page.dialogue else ""
	entry.source_dialogue_id = str(Game.stage_page.dialogue_line.id) if Game.stage_page.dialogue_line else ""
	entries.append(entry)
	current_page.entries = entries
	if entry_id != "":
		notebook_data.entry_ids_written.append(entry_id)
	notebook_data.current_page_index = current_page.page_index
	if visible:
		if created_new_page or page_index != notebook_data.current_page_index:
			await show_page(notebook_data.current_page_index)
		await _play_new_entry(entry)
		_update_navigation()
		return
	_update_navigation()

func append_story_entry(entry_id: String, speaker: String, text: String, side: String = "", tags: Array = [], animate: bool = true) -> void:
	await append_entry(entry_id, speaker, text, side, tags, animate)

func wait_for_story_close() -> void:
	_awaiting_story_close = true
	if not visible:
		_awaiting_story_close = false
		return
	await story_interaction_closed

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
	_is_playing_entry = false
	_awaiting_story_close = false
	_render_revision += 1
	clear_reply_options()
	if visible:
		await show_last_page()
	else:
		_clear_page()
		_update_navigation()

func trim_notebook_from_dialogue_id(source_dialogue_id: String) -> void:
	if source_dialogue_id == "":
		return
		_ensure_initialized()
	var new_pages: Array[NotebookPageData] = []
	var found := false
	for page: NotebookPageData in notebook_data.pages:
		var new_page := NotebookPageData.new()
		new_page.page_index = page.page_index
		new_page.entries = []
		for entry: NotebookEntryData in page.entries:
			if entry.source_dialogue_id == source_dialogue_id:
				found = true
				break
			new_page.entries.append(entry.duplicate(true))
		if new_page.entries.size() > 0:
			new_pages.append(new_page)
		if found:
			break
	if found:
		notebook_data.pages = new_pages
		if notebook_data.pages.is_empty():
			notebook_data.pages.append(_make_page(0))
		notebook_data.current_page_index = notebook_data.pages.back().page_index if not notebook_data.pages.is_empty() else 0
		var ids: Array[String] = []
		for page: NotebookPageData in notebook_data.pages:
			for entry: NotebookEntryData in page.entries:
				if entry.entry_id != "":
					ids.append(entry.entry_id)
		notebook_data.entry_ids_written = ids
		_render_revision += 1
		clear_reply_options()
		if visible:
			await show_last_page()
		else:
			_clear_page()
			_update_navigation()

func restore_notebook_data(data) -> void:
	notebook_data = data.duplicate(true) if data else NotebookData.new()
	_ensure_initialized()
	_is_playing_entry = false
	_awaiting_story_close = false
	clear_reply_options()
	if visible:
		await show_last_page()
