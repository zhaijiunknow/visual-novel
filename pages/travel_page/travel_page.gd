class_name TravelPage
extends CanvasLayer

@export var vbox_selections: VBoxContainer
@export var place_selection: Control
@export var texture_button_confirm: TextureButton
@export var label_place_title: Label
@export var rich_label_place_description: RichTextLabel

@onready var original_y: float = vbox_selections.global_position.y

var slide_tolerance: float = 300
var slide_duration: float = 0.2
var start_y: float

var selected_index: int:
	set(value):
		var last_index = selected_index
		
		var index = value
		var background_count = Stage.background_data_pool.size()
		if index < 0: index = background_count - 1
		index %= background_count
		
		selected_index = index
		
		var index_difference = last_index - value
		var target_y = original_y + (place_selection.size.y * index_difference)
		sliding = true
		await create_tween().tween_property(
			vbox_selections, "position:y",
			target_y,
			slide_duration
		).finished
		sliding = false
		update()

var button_pressed: bool
var sliding: bool

func _ready() -> void:
	set_process_input(false)
	visibility_changed.connect(func(): set_process_input(visible))
	vbox_selections.gui_input.connect(
		func (event: InputEvent):
			if event is InputEventMouseButton:
				if event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
					button_pressed = true
					start_y = event.global_position.y
	)
	texture_button_confirm.pressed.connect(
		func ():
			Stage.background_name = Stage.background_data_pool[selected_index].title
			visible = false
	)
	
	update()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if button_pressed:
			if event.is_released() and event.button_index == MOUSE_BUTTON_LEFT:
				button_pressed = false
				create_tween().tween_property(vbox_selections, "position:y", original_y, 0.3)
		
		if event.pressed and not sliding:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP :
				selected_index -= 1
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				selected_index += 1
	
	var y_difference: float
	if button_pressed:
		if event is InputEventMouseMotion:
			y_difference = event.global_position.y - start_y
			y_difference = clamp(y_difference, -slide_tolerance, slide_tolerance)
			vbox_selections.global_position.y = original_y + y_difference
	if y_difference >= slide_tolerance:
		selected_index -= 1
		button_pressed = false
	if y_difference <= -slide_tolerance:
		selected_index += 1
		button_pressed = false

func update() -> void:
	for selection: PlaceSelection in vbox_selections.get_children():
		var offset_index = selection.get_index() - 2
		var target_index = selected_index + offset_index
		target_index %= Stage.background_data_pool.size()
		selection.texture_rect_image.texture = \
			Stage.background_data_pool[target_index].texture
	vbox_selections.global_position.y = original_y
	
	var selected_background = Stage.background_data_pool[selected_index]
	label_place_title.text = selected_background.title
	rich_label_place_description.text = selected_background.description
