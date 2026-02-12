extends TextureButton

@export var with_transition: bool
@export var target_page: CanvasLayer

func _ready() -> void:
	pressed.connect(
		func ():
			await Game.fade(false)
			target_page.visible = false
			await Game.fade(true)
	)
