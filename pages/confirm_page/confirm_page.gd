class_name ConfirmPage
extends CanvasLayer

@export var label_title: Label
@export var label_message: Label
@export var button_confirm: TextureButton
@export var button_cancel: TextureButton

var on_confirm: Callable = func(): pass
var on_cancel: Callable = func(): Game.go_back()

func _ready() -> void:
	button_confirm.pressed.connect(func(): on_confirm.call())
	button_cancel.pressed.connect(func(): on_cancel.call())

func show_confirm(title: String, message: String, _on_confirm: Callable, _on_cancel: Callable = func(): Game.go_back()) -> void:
	label_title.text = title
	label_message.text = message
	on_confirm = _on_confirm
	on_cancel = _on_cancel
