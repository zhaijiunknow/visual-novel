extends TextureButton

@export var with_transition: bool
@export var target_page: CanvasLayer

func _ready() -> void:
	pressed.connect(
		func ():
			Game.switch_to_page(target_page, true, false)
	)
