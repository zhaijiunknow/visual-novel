extends TextureButton

@export var with_transition: bool = true

func _ready() -> void:
	pressed.connect(
		func ():
			Game.go_back(with_transition)
	)
