class_name ConfirmPage
extends CanvasLayer

@export var label_message: Label
@export var button_confirm: TextureButton
@export var button_cancel: TextureButton

var on_confirm: Callable = Callable()
var on_cancel: Callable = Callable()

func _ready() -> void:
	if on_confirm.is_null():
		on_confirm = func(): pass
	if on_cancel.is_null():
		on_cancel = func(): Game.go_back()
	button_confirm.pressed.connect(
		func():
			if not on_confirm.is_null():
				on_confirm.call()
	)
	button_cancel.pressed.connect(
		func():
			if not on_cancel.is_null():
				on_cancel.call()
	)

func show_confirm(title: String, message: String, _on_confirm: Callable, _on_cancel: Callable = Callable()) -> void:
	label_message.text = message
	on_confirm = _on_confirm
	on_cancel = _on_cancel if not _on_cancel.is_null() else func(): Game.go_back()
