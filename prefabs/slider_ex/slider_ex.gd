@tool
class_name SliderEx
extends PanelContainer

signal value_changed(new_value: float)

@export var initial_value: float = 0.5:
	set(v):
		initial_value = v
		if Engine.is_editor_hint():
			value = initial_value

@export var step: float = 0.0
@export var caret_hover_texture: Texture2D
@export var caret_pressed_texture: Texture2D

@export var fill: Control
@export var end_point: Control
@export var caret: Control
@export var click_rect: Control

var dragged: bool = false
var _value: float = 0.0
var _caret_default_texture: Texture2D
var _caret_hovered: bool = false
var _caret_pressed: bool = false

var value: float:
	get:
		return _value
	set(v):
		_set_value(v, true)

func set_value_silent(v: float) -> void:
	_set_value(v, false)


func _set_value(v: float, notify: bool) -> void:
	v = clamp(v, 0.0, 1.0)
	if step > 0.0:
		v = snapped(v, step)
		v = clamp(v, 0.0, 1.0)
	if abs(_value - v) < 0.0001:
		return
	_value = v
	_update_visuals()
	if notify:
		value_changed.emit(_value)


# Caret 用 anchor 挂在 EndPoint 上（EndPoint 位于 Fill 右端中点），
# 位置由布局自动跟随，父级滚动/转场时不需要手动同步
func _update_visuals() -> void:
	fill.size.x = size.x * _value


func _ready() -> void:
	set_process_input(false)
	var caret_rect := _get_caret_texture_rect()
	if caret_rect:
		_caret_default_texture = caret_rect.texture
	click_rect.gui_input.connect(_on_click_rect_input)
	click_rect.mouse_exited.connect(_on_click_rect_mouse_exited)
	set_value_silent(initial_value)
	_update_caret_texture()
	resized.connect(_update_visuals)


func _on_click_rect_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_update_caret_hover_state(event.global_position)
		if event.button_index == MOUSE_BUTTON_LEFT:
			_caret_pressed = event.pressed
			_update_caret_texture()
			if event.pressed:
				dragged = true
				set_process_input(true)
				value = event.position.x / size.x
	elif event is InputEventMouseMotion:
		_update_caret_hover_state(event.global_position)
		if dragged:
			value = event.position.x / size.x


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_caret_hover_state(event.global_position)
		var local_x: float = event.global_position.x - global_position.x
		value = local_x / size.x
	elif event is InputEventMouseButton:
		if event.is_released() and event.button_index == MOUSE_BUTTON_LEFT:
			dragged = false
			_caret_pressed = false
			_update_caret_hover_state(event.global_position)
			_update_caret_texture()
			set_process_input(false)


func _on_click_rect_mouse_exited() -> void:
	_caret_hovered = false
	_update_caret_texture()


func _get_caret_texture_rect() -> TextureRect:
	return caret as TextureRect


func _update_caret_hover_state(mouse_global_position: Vector2) -> void:
	var caret_rect := _get_caret_texture_rect()
	if not caret_rect:
		return
	var hovered := Rect2(caret_rect.global_position, caret_rect.size).has_point(mouse_global_position)
	if _caret_hovered == hovered:
		return
	_caret_hovered = hovered
	_update_caret_texture()


func _update_caret_texture() -> void:
	var caret_rect := _get_caret_texture_rect()
	if not caret_rect:
		return
	if _caret_pressed and caret_pressed_texture:
		caret_rect.texture = caret_pressed_texture
	elif _caret_hovered and caret_hover_texture:
		caret_rect.texture = caret_hover_texture
	else:
		caret_rect.texture = _caret_default_texture
