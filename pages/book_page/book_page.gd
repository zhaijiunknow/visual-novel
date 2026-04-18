class_name BookPage
extends CanvasLayer

@export var dialogue_label: DialogueLabel
@export var pages: Array[DialogueResource]
@export var vbox_page: VBoxContainer
@export var button_previous: TextureButton
@export var button_next: TextureButton
@export var paragraph_container: ParagraphContainer
@export var buttons: Control
@export var reply_color: Color
@export var audio_player: AudioStreamPlayer

var page_index: int:
	set(value):
		page_index = value
		
		line = null
		
		for child in vbox_page.get_children():
			vbox_page.remove_child(child)
			child.queue_free()
		
		button_previous.visible = page_index > 0
		button_next.visible = page_index < pages.size() - 1
		
		await write()
var line: DialogueLine

func write() -> void:
	if not visible: return
	buttons.visible = true
	line = await pages[page_index].get_next_dialogue_line(line.next_id if line else "start")
	if line:
		buttons.visible = false
		var label = dialogue_label.duplicate()
		var container = paragraph_container.duplicate()
		vbox_page.add_child(container)
		if line.character == "L":
			container.box_left.add_child(label)
		else:
			label.remove_theme_color_override("default_color")
			label.add_theme_color_override("default_color", reply_color)
			container.box_right.add_child(label)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.dialogue_line = line
		label.visible_ratio = 0
		audio_player.play()
		await create_tween().tween_property(label, "visible_ratio", 1, audio_player.stream.get_length()).finished
		await get_tree().create_timer(0.8).timeout
		write()

func _ready() -> void:
	button_previous.pressed.connect(
		func (): page_index -= 1
	)
	button_next.pressed.connect(
		func (): page_index += 1
	)
	visibility_changed.connect(
		func ():
			if visible: page_index = 0
	)
